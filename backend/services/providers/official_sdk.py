"""官方开源 SDK 的最小适配层。

复用：
- dashscope/dashscope-sdk-python 的 Generation.call
- openai/openai-python 的 OpenAI().chat.completions.create

这里只做响应归一化，不把第三方 SDK 的对象泄漏到业务层。
"""

import logging
from http import HTTPStatus
from threading import Lock
from typing import Any, List
from urllib.parse import urlsplit, urlunsplit

from models.ai_message import ChatMessageDTO, ChatResponse
from services.ai_config import ProviderConfig

logger = logging.getLogger(__name__)
_dashscope_lock = Lock()


def call_official_sdk(
    provider_id: str,
    config: ProviderConfig,
    messages: List[ChatMessageDTO],
    temperature: float,
    max_tokens: int,
) -> ChatResponse:
    """调用官方 SDK，并返回现有 ChatResponse 契约。"""

    if provider_id == "qwen":
        return _call_qwen(config, messages, temperature, max_tokens)
    if provider_id == "deepseek":
        return _call_deepseek(config, messages, temperature, max_tokens)
    return ChatResponse(success=False, error=f"不支持官方 SDK provider: {provider_id}")


def _call_qwen(
    config: ProviderConfig,
    messages: List[ChatMessageDTO],
    temperature: float,
    max_tokens: int,
) -> ChatResponse:
    try:
        import dashscope
        from dashscope import Generation
    except ImportError:
        return ChatResponse(
            success=False,
            error="千问官方 SDK 未安装，请安装 dashscope 后重试",
        )

    try:
        with _dashscope_lock:
            previous_key = getattr(dashscope, "api_key", None)
            previous_url = getattr(dashscope, "base_http_api_url", None)
            dashscope.api_key = config.api_key
            api_root = _dashscope_api_root(config.base_url)
            if api_root:
                dashscope.base_http_api_url = api_root
            try:
                response = Generation.call(
                    model=config.model,
                    messages=[message.to_dict() for message in messages],
                    result_format="message",
                    temperature=temperature,
                    max_tokens=max_tokens,
                    stream=False,
                )
            finally:
                dashscope.api_key = previous_key
                dashscope.base_http_api_url = previous_url
    except Exception as exc:
        return _sdk_error(config, exc)

    if _value(response, "status_code") != HTTPStatus.OK:
        return _sdk_error(
            config,
            _value(response, "message") or _value(response, "code") or "千问返回非成功状态",
        )

    try:
        output = _value(response, "output")
        choices = _value(output, "choices")
        message = _value(choices[0], "message")
        content = _value(message, "content")
        if not isinstance(content, str):
            raise ValueError("响应缺少 output.choices[0].message.content")
    except (AttributeError, IndexError, TypeError, ValueError) as exc:
        return _sdk_error(config, exc)

    return ChatResponse(
        success=True,
        content=content,
        provider="qwen",
        model=config.model,
    )


def _call_deepseek(
    config: ProviderConfig,
    messages: List[ChatMessageDTO],
    temperature: float,
    max_tokens: int,
) -> ChatResponse:
    try:
        from openai import OpenAI
    except ImportError:
        return ChatResponse(
            success=False,
            error="DeepSeek 官方 SDK 未安装，请安装 openai 后重试",
        )

    try:
        client = OpenAI(
            api_key=config.api_key,
            base_url=_openai_base_url(config.base_url),
            timeout=config.timeout,
        )
        response = client.chat.completions.create(
            model=config.model,
            messages=[message.to_dict() for message in messages],
            temperature=temperature,
            max_tokens=max_tokens,
            stream=False,
        )
        content = response.choices[0].message.content
        if not isinstance(content, str):
            raise ValueError("响应缺少 choices[0].message.content")
    except Exception as exc:
        return _sdk_error(config, exc)

    return ChatResponse(
        success=True,
        content=content,
        provider="deepseek",
        model=config.model,
    )


def _value(value: Any, key: str) -> Any:
    if isinstance(value, dict):
        return value.get(key)
    return getattr(value, key, None)


def _dashscope_api_root(base_url: str) -> str:
    """把现有 DashScope generation endpoint 收敛成 SDK 所需的 /api/v1 根路径。"""

    parsed = urlsplit(base_url.strip())
    if not parsed.scheme or not parsed.netloc:
        return ""
    marker = "/api/v1"
    path = parsed.path
    root_path = path[: path.find(marker) + len(marker)] if marker in path else marker
    return urlunsplit((parsed.scheme, parsed.netloc, root_path, "", "")).rstrip("/")


def _openai_base_url(base_url: str) -> str:
    """把 OpenAI 兼容的完整 chat/completions URL 收敛成 SDK base_url。"""

    parsed = urlsplit(base_url.strip())
    path = parsed.path.rstrip("/")
    suffix = "/chat/completions"
    if path.endswith(suffix):
        path = path[: -len(suffix)]
    return urlunsplit((parsed.scheme, parsed.netloc, path, "", "")).rstrip("/")


def _sdk_error(config: ProviderConfig, error: Any) -> ChatResponse:
    message = str(error) or "未知 SDK 错误"
    if config.api_key:
        message = message.replace(config.api_key, "[redacted]")
    logger.error("[%s] 官方 SDK 调用失败: %s", config.name, message)
    return ChatResponse(success=False, error=f"{config.name} 官方 SDK 错误: {message}")
