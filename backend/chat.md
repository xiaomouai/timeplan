# Flask 后端重构方案

## 重构后目录结构

```
app/
├── api/
│   └── v1/
│       ├── __init__.py
│       └── ai/
│           ├── __init__.py          # 蓝图注册
│           ├── routes.py            # 路由层（瘦控制器）
│           ├── schemas.py           # 请求/响应校验
│           └── prompts.py           # 预设提示词配置
├── services/
│   ├── __init__.py
│   ├── ai_chat_service.py          # 聊天业务编排
│   ├── speech_service.py           # 语音识别服务
│   └── providers/
│       ├── __init__.py
│       ├── base.py                 # 抽象基类
│       ├── qwen_provider.py        # 千问实现
│       ├── deepseek_provider.py    # DeepSeek实现
│       └── provider_manager.py     # 提供商管理（注册/降级/健康检查）
├── models/
│   └── ai_message.py               # 消息数据模型
├── config/
│   ├── __init__.py
│   └── ai_config.py                # AI相关配置
├── utils/
│   ├── response.py                 # 统一响应（已有）
│   ├── retry.py                    # 重试装饰器
│   └── validators.py               # 通用校验工具
└── exceptions/
    ├── __init__.py
    └── ai_exceptions.py            # 自定义异常体系
```

---

## 1. 自定义异常体系 `exceptions/ai_exceptions.py`

```python
"""
AI模块自定义异常体系

设计原则：
- 每种异常对应明确的HTTP状态码
- 异常携带结构化上下文信息，便于日志和前端展示
- 支持异常链（__cause__）追踪根因
"""


class AIBaseException(Exception):
    """AI模块异常基类"""

    status_code: int = 500
    default_message: str = "AI服务异常"

    def __init__(self, message: str = None, detail: str = None):
        self.message = message or self.default_message
        self.detail = detail
        super().__init__(self.message)

    def to_dict(self) -> dict:
        result = {"error": self.message}
        if self.detail:
            result["detail"] = self.detail
        return result


class ProviderUnavailableError(AIBaseException):
    """AI提供商不可用（未配置/未启用）"""

    status_code = 503
    default_message = "AI提供商不可用"

    def __init__(self, provider: str, reason: str = None):
        self.provider = provider
        detail = f"提供商 '{provider}' 不可用"
        if reason:
            detail += f": {reason}"
        super().__init__(message=self.default_message, detail=detail)


class ProviderAPIError(AIBaseException):
    """AI提供商API调用失败"""

    status_code = 502
    default_message = "AI接口调用失败"

    def __init__(self, provider: str, status_code: int = None, api_message: str = None):
        self.provider = provider
        self.api_status_code = status_code
        detail = f"提供商 '{provider}'"
        if status_code:
            detail += f" 返回 HTTP {status_code}"
        if api_message:
            detail += f": {api_message}"
        super().__init__(message=self.default_message, detail=detail)


class AllProvidersFailedError(AIBaseException):
    """所有提供商均失败"""

    status_code = 503
    default_message = "所有AI服务均不可用"

    def __init__(self, errors: list[str]):
        self.errors = errors
        detail = "; ".join(errors)
        super().__init__(message=self.default_message, detail=detail)


class InvalidRequestError(AIBaseException):
    """请求参数校验失败"""

    status_code = 400
    default_message = "请求参数错误"


class SpeechRecognitionError(AIBaseException):
    """语音识别失败"""

    status_code = 500
    default_message = "语音识别失败"
```

---

## 2. AI配置 `config/ai_config.py`

```python
"""
AI模块配置

所有AI相关的配置项集中管理，支持环境变量覆盖。
包含：提供商连接参数、默认模型参数、速率限制等。
"""

import os
from dataclasses import dataclass, field


@dataclass(frozen=True)
class ProviderConfig:
    """单个AI提供商的配置（不可变）"""

    name: str
    api_key: str
    base_url: str
    model: str
    max_tokens: int = 4000
    temperature: float = 0.7
    timeout: int = 30
    priority: int = 1  # 数字越小优先级越高
    max_retries: int = 2
    retry_delay: float = 0.5

    @property
    def enabled(self) -> bool:
        return bool(self.api_key and self.base_url)


@dataclass(frozen=True)
class AIConfig:
    """AI模块全局配置"""

    # 默认请求参数
    default_temperature: float = 0.7
    default_max_tokens: int = 2000
    max_conversation_history: int = 10

    # 语音识别配置
    speech_api_url: str = ""
    speech_api_key: str = ""
    max_audio_size_mb: int = 10
    allowed_audio_formats: tuple = ("wav", "mp3", "m4a", "ogg", "flac")

    # 提供商配置
    providers: dict[str, ProviderConfig] = field(default_factory=dict)


def load_config() -> AIConfig:
    """从环境变量加载配置"""
    providers = {}

    # 千问配置
    qwen_key = os.getenv("QWEN_API_KEY", "")
    qwen_url = os.getenv("QWEN_BASE_URL", "")
    if qwen_key and qwen_url:
        providers["qwen"] = ProviderConfig(
            name="通义千问",
            api_key=qwen_key,
            base_url=qwen_url,
            model=os.getenv("QWEN_MODEL", "qwen-plus"),
            priority=1,
        )

    # DeepSeek配置
    ds_key = os.getenv("DEEPSEEK_API_KEY", "")
    ds_url = os.getenv("DEEPSEEK_BASE_URL", "")
    if ds_key and ds_url:
        providers["deepseek"] = ProviderConfig(
            name="DeepSeek",
            api_key=ds_key,
            base_url=ds_url,
            model=os.getenv("DEEPSEEK_MODEL", "deepseek-chat"),
            priority=2,
        )

    return AIConfig(
        speech_api_url=os.getenv("SPEECH_API_URL", ""),
        speech_api_key=os.getenv("SPEECH_API_KEY", ""),
        providers=providers,
    )


# 模块级单例
ai_config = load_config()
```

---

## 3. 消息数据模型 `models/ai_message.py`

```python
"""
AI消息数据模型

作为服务层内部的数据传输对象（DTO），
与前端传入的JSON和提供商API格式解耦。
"""

from dataclasses import dataclass, field
from enum import Enum
from typing import Optional


class MessageRole(str, Enum):
    SYSTEM = "system"
    USER = "user"
    ASSISTANT = "assistant"


@dataclass
class ChatMessageDTO:
    """单条聊天消息"""

    role: MessageRole
    content: str

    def to_dict(self) -> dict:
        return {"role": self.role.value, "content": self.content}

    @classmethod
    def from_dict(cls, data: dict) -> "ChatMessageDTO":
        return cls(
            role=MessageRole(data["role"]),
            content=data["content"],
        )

    @classmethod
    def system(cls, content: str) -> "ChatMessageDTO":
        return cls(role=MessageRole.SYSTEM, content=content)

    @classmethod
    def user(cls, content: str) -> "ChatMessageDTO":
        return cls(role=MessageRole.USER, content=content)


@dataclass
class ChatRequest:
    """聊天请求参数"""

    messages: list[ChatMessageDTO]
    temperature: float = 0.7
    max_tokens: int = 2000
    preferred_provider: Optional[str] = None


@dataclass
class ChatResponse:
    """聊天响应结果"""

    success: bool
    content: Optional[str] = None
    provider: Optional[str] = None
    model: Optional[str] = None
    error: Optional[str] = None

    def to_dict(self) -> dict:
        if self.success:
            return {
                "content": self.content,
                "provider": self.provider,
                "model": self.model,
            }
        return {"error": self.error}
```

---

## 4. 重试工具 `utils/retry.py`

```python
"""
通用重试装饰器

支持：
- 可配置最大重试次数
- 指数退避延迟
- 指定可重试的异常类型
- 日志记录每次重试
"""

import time
import logging
from functools import wraps
from typing import Type

logger = logging.getLogger(__name__)


def retry_on_failure(
    max_retries: int = 3,
    delay: float = 1.0,
    backoff_factor: float = 2.0,
    exceptions: tuple[Type[Exception], ...] = (Exception,),
):
    """
    请求失败重试装饰器

    Args:
        max_retries: 最大重试次数
        delay: 初始延迟（秒）
        backoff_factor: 退避因子
        exceptions: 需要重试的异常类型元组
    """

    def decorator(func):
        @wraps(func)
        def wrapper(*args, **kwargs):
            last_exception = None
            for attempt in range(1, max_retries + 1):
                try:
                    return func(*args, **kwargs)
                except exceptions as e:
                    last_exception = e
                    if attempt < max_retries:
                        wait_time = delay * (backoff_factor ** (attempt - 1))
                        logger.warning(
                            f"[Retry] {func.__name__} 第{attempt}次失败: {e}, "
                            f"{wait_time:.1f}s 后重试..."
                        )
                        time.sleep(wait_time)
                    else:
                        logger.error(
                            f"[Retry] {func.__name__} 已达最大重试次数 {max_retries}, "
                            f"最后错误: {e}"
                        )
            raise last_exception

        return wrapper

    return decorator
```

---

## 5. 提供商抽象基类 `services/providers/base.py`

```python
"""
AI提供商抽象基类

定义统一的调用接口，所有具体提供商必须实现。
遵循开放-封闭原则：新增提供商只需添加子类，无需修改现有代码。
"""

from abc import ABC, abstractmethod
import logging
from typing import Optional

from config.ai_config import ProviderConfig
from models.ai_message import ChatMessageDTO, ChatResponse

logger = logging.getLogger(__name__)


class BaseAIProvider(ABC):
    """AI提供商抽象基类"""

    def __init__(self, provider_id: str, config: ProviderConfig):
        self.provider_id = provider_id
        self.config = config

    @property
    def name(self) -> str:
        return self.config.name

    @property
    def enabled(self) -> bool:
        return self.config.enabled

    @abstractmethod
    def _build_headers(self) -> dict:
        """构建HTTP请求头"""
        ...

    @abstractmethod
    def _build_request_body(
        self,
        messages: list[ChatMessageDTO],
        temperature: float,
        max_tokens: int,
    ) -> dict:
        """构建请求体（各提供商格式不同）"""
        ...

    @abstractmethod
    def _parse_response(self, response_data: dict) -> str:
        """
        解析响应体，提取回复内容

        Args:
            response_data: API返回的JSON

        Returns:
            AI回复的文本内容

        Raises:
            ValueError: 响应格式不符合预期
        """
        ...

    def call(
        self,
        messages: list[ChatMessageDTO],
        temperature: float = 0.7,
        max_tokens: int = 2000,
    ) -> ChatResponse:
        """
        调用AI API（模板方法）

        流程：构建请求 → 发送HTTP → 解析响应
        子类只需实现 _build_headers / _build_request_body / _parse_response
        """
        import requests as http_requests

        headers = self._build_headers()
        body = self._build_request_body(messages, temperature, max_tokens)

        logger.info(
            f"[{self.provider_id}] 调用API, "
            f"model={self.config.model}, messages={len(messages)}条"
        )

        try:
            response = http_requests.post(
                self.config.base_url,
                headers=headers,
                json=body,
                timeout=self.config.timeout,
            )
        except http_requests.exceptions.Timeout:
            return ChatResponse(
                success=False,
                error=f"{self.name} 请求超时 ({self.config.timeout}s)",
            )
        except http_requests.exceptions.ConnectionError as e:
            return ChatResponse(
                success=False,
                error=f"{self.name} 连接失败: {str(e)}",
            )

        if response.status_code != 200:
            error_msg = self._extract_error_message(response)
            logger.error(f"[{self.provider_id}] HTTP {response.status_code}: {error_msg}")
            return ChatResponse(
                success=False,
                error=f"{self.name} API错误 (HTTP {response.status_code}): {error_msg}",
            )

        try:
            response_data = response.json()
            content = self._parse_response(response_data)
            logger.info(f"[{self.provider_id}] 调用成功, 回复长度={len(content)}")
            return ChatResponse(
                success=True,
                content=content,
                provider=self.provider_id,
                model=self.config.model,
            )
        except (ValueError, KeyError, IndexError) as e:
            logger.error(f"[{self.provider_id}] 响应解析失败: {e}")
            return ChatResponse(
                success=False,
                error=f"{self.name} 响应格式错误: {str(e)}",
            )

    def _extract_error_message(self, response) -> str:
        """从错误响应中提取错误信息"""
        try:
            data = response.json()
            # 兼容多种错误格式
            return (
                data.get("message")
                or data.get("error", {}).get("message")
                or data.get("error")
                or f"HTTP {response.status_code}"
            )
        except Exception:
            return f"HTTP {response.status_code}"

    def health_check(self) -> tuple[bool, Optional[float]]:
        """
        健康检查

        Returns:
            (is_healthy, response_time_seconds)
        """
        import time

        test_messages = [ChatMessageDTO.user("Hello, this is a test.")]
        start = time.time()
        result = self.call(test_messages, temperature=0.1, max_tokens=10)
        elapsed = time.time() - start
        return result.success, round(elapsed, 2) if result.success else None
```

---

## 6. 千问提供商 `services/providers/qwen_provider.py`

```python
"""
通义千问 AI 提供商实现

千问API使用 DashScope 格式，与标准 OpenAI 格式不同：
- 请求体包裹在 input.messages 和 parameters 中
- 响应在 output.choices[].message.content 中
"""

from models.ai_message import ChatMessageDTO
from .base import BaseAIProvider


class QwenProvider(BaseAIProvider):
    """通义千问API适配器"""

    def _build_headers(self) -> dict:
        return {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {self.config.api_key}",
            "X-DashScope-SSE": "disable",
        }

    def _build_request_body(
        self,
        messages: list[ChatMessageDTO],
        temperature: float,
        max_tokens: int,
    ) -> dict:
        return {
            "model": self.config.model,
            "input": {
                "messages": [msg.to_dict() for msg in messages],
            },
            "parameters": {
                "temperature": temperature,
                "max_tokens": max_tokens,
                "result_format": "message",
            },
        }

    def _parse_response(self, response_data: dict) -> str:
        """
        解析千问响应

        期望格式:
        {
          "output": {
            "choices": [
              {"message": {"role": "assistant", "content": "..."}}
            ]
          }
        }
        """
        output = response_data.get("output")
        if not output:
            raise ValueError("响应缺少 'output' 字段")

        choices = output.get("choices")
        if not choices or len(choices) == 0:
            raise ValueError("响应缺少 'choices' 字段")

        content = choices[0].get("message", {}).get("content")
        if content is None:
            raise ValueError("响应缺少 'content' 字段")

        return content
```

---

## 7. DeepSeek 提供商 `services/providers/deepseek_provider.py`

```python
"""
DeepSeek AI 提供商实现

DeepSeek 兼容 OpenAI API 格式：
- 标准 messages 数组
- 响应在 choices[].message.content 中
"""

from models.ai_message import ChatMessageDTO
from .base import BaseAIProvider


class DeepSeekProvider(BaseAIProvider):
    """DeepSeek API适配器"""

    def _build_headers(self) -> dict:
        return {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {self.config.api_key}",
            "User-Agent": "LionEng/1.0",
        }

    def _build_request_body(
        self,
        messages: list[ChatMessageDTO],
        temperature: float,
        max_tokens: int,
    ) -> dict:
        return {
            "model": self.config.model,
            "messages": [msg.to_dict() for msg in messages],
            "temperature": temperature,
            "max_tokens": max_tokens,
            "stream": False,
        }

    def _parse_response(self, response_data: dict) -> str:
        """
        解析 DeepSeek 响应

        期望格式:
        {
          "choices": [
            {"message": {"role": "assistant", "content": "..."}}
          ]
        }
        """
        choices = response_data.get("choices")
        if not choices or len(choices) == 0:
            raise ValueError("响应缺少 'choices' 字段")

        content = choices[0].get("message", {}).get("content")
        if content is None:
            raise ValueError("响应缺少 'content' 字段")

        return content
```

---

## 8. 提供商管理器 `services/providers/provider_manager.py`

```python
"""
AI提供商管理器

职责：
- 注册和管理多个AI提供商实例
- 实现优先级排序和自动降级（fallback）策略
- 提供健康检查能力
- 线程安全（Flask多线程环境）

扩展新提供商：
1. 实现 BaseAIProvider 子类
2. 在 _register_providers() 中注册
"""

import logging
from typing import Optional
from threading import Lock

from config.ai_config import AIConfig
from models.ai_message import ChatMessageDTO, ChatResponse
from exceptions.ai_exceptions import AllProvidersFailedError, ProviderUnavailableError
from utils.retry import retry_on_failure

from .base import BaseAIProvider
from .qwen_provider import QwenProvider
from .deepseek_provider import DeepSeekProvider

logger = logging.getLogger(__name__)


class ProviderManager:
    """AI提供商管理器（单例模式）"""

    _instance: Optional["ProviderManager"] = None
    _lock = Lock()

    def __new__(cls, *args, **kwargs):
        with cls._lock:
            if cls._instance is None:
                cls._instance = super().__new__(cls)
            return cls._instance

    def __init__(self, config: AIConfig):
        if hasattr(self, "_initialized"):
            return
        self._initialized = True
        self._config = config
        self._providers: dict[str, BaseAIProvider] = {}
        self._register_providers()

    def _register_providers(self):
        """注册所有已配置的提供商"""

        # 提供商类型映射表 — 新增提供商只需在此添加
        provider_classes: dict[str, type[BaseAIProvider]] = {
            "qwen": QwenProvider,
            "deepseek": DeepSeekProvider,
        }

        for provider_id, provider_config in self._config.providers.items():
            if not provider_config.enabled:
                logger.warning(f"[ProviderManager] {provider_id} 未启用，跳过注册")
                continue

            cls = provider_classes.get(provider_id)
            if cls is None:
                logger.warning(f"[ProviderManager] 未知的提供商类型: {provider_id}")
                continue

            self._providers[provider_id] = cls(provider_id, provider_config)
            logger.info(
                f"[ProviderManager] 已注册 {provider_id} "
                f"(model={provider_config.model}, priority={provider_config.priority})"
            )

    def _get_sorted_providers(
        self, preferred: Optional[str] = None
    ) -> list[BaseAIProvider]:
        """
        获取按优先级排序的提供商列表

        如果指定了 preferred，将其排在最前面
        """
        providers = list(self._providers.values())

        # 按配置的 priority 排序
        providers.sort(key=lambda p: p.config.priority)

        if preferred and preferred in self._providers:
            pref = self._providers[preferred]
            providers = [pref] + [p for p in providers if p.provider_id != preferred]

        return providers

    def chat(
        self,
        messages: list[ChatMessageDTO],
        temperature: float = 0.7,
        max_tokens: int = 2000,
        preferred_provider: Optional[str] = None,
    ) -> ChatResponse:
        """
        调用AI聊天，支持自动降级

        流程：
        1. 按优先级排列提供商
        2. 依次尝试，成功即返回
        3. 全部失败则抛出 AllProvidersFailedError
        """
        providers = self._get_sorted_providers(preferred_provider)

        if not providers:
            raise ProviderUnavailableError(
                provider=preferred_provider or "any",
                reason="没有可用的AI提供商",
            )

        errors: list[str] = []

        for provider in providers:
            try:
                # 使用提供商自身配置的重试参数
                result = self._call_with_retry(
                    provider, messages, temperature, max_tokens
                )

                if result.success:
                    return result

                error_msg = f"{provider.provider_id}: {result.error}"
                errors.append(error_msg)
                logger.warning(f"[ProviderManager] {error_msg}, 尝试下一个提供商...")

            except Exception as e:
                error_msg = f"{provider.provider_id}: {str(e)}"
                errors.append(error_msg)
                logger.error(f"[ProviderManager] {error_msg}")

        raise AllProvidersFailedError(errors)

    def _call_with_retry(
        self,
        provider: BaseAIProvider,
        messages: list[ChatMessageDTO],
        temperature: float,
        max_tokens: int,
    ) -> ChatResponse:
        """带重试的提供商调用"""

        @retry_on_failure(
            max_retries=provider.config.max_retries,
            delay=provider.config.retry_delay,
            backoff_factor=1.5,
            exceptions=(ConnectionError, TimeoutError),
        )
        def _do_call():
            return provider.call(messages, temperature, max_tokens)

        return _do_call()

    # ==================== 查询接口 ====================

    def get_provider(self, provider_id: str) -> Optional[BaseAIProvider]:
        return self._providers.get(provider_id)

    def list_providers(self) -> list[dict]:
        """获取所有提供商信息"""
        result = []
        for pid, provider in self._providers.items():
            result.append(
                {
                    "id": pid,
                    "name": provider.name,
                    "model": provider.config.model,
                    "enabled": provider.enabled,
                    "priority": provider.config.priority,
                }
            )
        result.sort(key=lambda x: x["priority"])
        return result

    def health_check(self, provider_id: str) -> dict:
        """
        对指定提供商执行健康检查

        Returns:
            {"provider": str, "status": str, "response_time": float}
        """
        provider = self._providers.get(provider_id)
        if provider is None:
            raise ProviderUnavailableError(provider_id, "提供商未注册")

        is_healthy, response_time = provider.health_check()
        return {
            "provider": provider_id,
            "status": "ok" if is_healthy else "error",
            "response_time": response_time,
        }
```

---

## 9. 聊天业务服务 `services/ai_chat_service.py`

```python
"""
AI聊天业务服务

职责：
- 接收路由层的原始参数
- 组装消息列表（系统提示 + 历史 + 当前消息）
- 调用 ProviderManager 获取AI回复
- 返回结构化结果

这一层是业务逻辑的核心，与HTTP层和提供商层解耦。
"""

import logging
from typing import Optional

from config.ai_config import ai_config
from models.ai_message import ChatMessageDTO, ChatResponse, MessageRole
from services.providers.provider_manager import ProviderManager

logger = logging.getLogger(__name__)

# 初始化提供商管理器（全局单例）
provider_manager = ProviderManager(ai_config)


def chat(
    message: str,
    system_prompt: Optional[str] = None,
    conversation_history: Optional[list[dict]] = None,
    temperature: float = None,
    max_tokens: int = None,
    preferred_provider: Optional[str] = None,
) -> ChatResponse:
    """
    AI聊天核心方法

    Args:
        message: 用户当前消息
        system_prompt: 系统提示词
        conversation_history: 历史消息列表 [{"role": "user", "content": "..."}]
        temperature: 温度参数（0~1）
        max_tokens: 最大回复token数
        preferred_provider: 优先使用的提供商

    Returns:
        ChatResponse 包含回复内容或错误信息
    """
    temperature = temperature if temperature is not None else ai_config.default_temperature
    max_tokens = max_tokens if max_tokens is not None else ai_config.default_max_tokens

    # 组装消息列表
    messages: list[ChatMessageDTO] = []

    # 1. 系统提示词
    if system_prompt:
        messages.append(ChatMessageDTO.system(system_prompt))

    # 2. 对话历史（截取最近N条）
    if conversation_history:
        max_history = ai_config.max_conversation_history
        recent = conversation_history[-max_history:]
        for item in recent:
            try:
                messages.append(ChatMessageDTO.from_dict(item))
            except (KeyError, ValueError) as e:
                logger.warning(f"跳过无效的历史消息: {item}, 错误: {e}")
                continue

    # 3. 当前用户消息
    messages.append(ChatMessageDTO.user(message))

    logger.info(
        f"[ChatService] 聊天请求: messages={len(messages)}, "
        f"provider={preferred_provider or 'auto'}, "
        f"temperature={temperature}, max_tokens={max_tokens}"
    )

    # 调用提供商管理器（含降级逻辑）
    return provider_manager.chat(
        messages=messages,
        temperature=temperature,
        max_tokens=max_tokens,
        preferred_provider=preferred_provider,
    )


def get_providers() -> list[dict]:
    """获取可用提供商列表"""
    return provider_manager.list_providers()


def check_provider_health(provider_id: str) -> dict:
    """健康检查"""
    return provider_manager.health_check(provider_id)
```

---

## 10. 语音识别服务 `services/speech_service.py`

```python
"""
语音识别服务

职责：
- 接收音频文件
- 调用语音识别API（如阿里云ASR / Whisper等）
- 返回识别文本

当前实现为占位，可对接任意STT服务。
"""

import os
import logging
from typing import Optional

import requests

from config.ai_config import ai_config
from exceptions.ai_exceptions import SpeechRecognitionError

logger = logging.getLogger(__name__)

# 支持的音频格式
ALLOWED_EXTENSIONS = ai_config.allowed_audio_formats
MAX_FILE_SIZE = ai_config.max_audio_size_mb * 1024 * 1024  # 转为字节


def validate_audio_file(file) -> None:
    """
    校验上传的音频文件

    Args:
        file: Flask request.files 中的文件对象

    Raises:
        SpeechRecognitionError: 文件不合法
    """
    if not file or not file.filename:
        raise SpeechRecognitionError(detail="未上传音频文件")

    # 检查扩展名
    ext = file.filename.rsplit(".", 1)[-1].lower() if "." in file.filename else ""
    if ext not in ALLOWED_EXTENSIONS:
        raise SpeechRecognitionError(
            detail=f"不支持的音频格式 '{ext}'，支持: {', '.join(ALLOWED_EXTENSIONS)}"
        )

    # 检查文件大小（读取后重置指针）
    file.seek(0, os.SEEK_END)
    size = file.tell()
    file.seek(0)
    if size > MAX_FILE_SIZE:
        raise SpeechRecognitionError(
            detail=f"音频文件过大 ({size // 1024 // 1024}MB)，最大 {ai_config.max_audio_size_mb}MB"
        )


def recognize(file) -> str:
    """
    语音识别主方法

    Args:
        file: Flask文件对象

    Returns:
        识别出的文本

    Raises:
        SpeechRecognitionError: 识别失败
    """
    validate_audio_file(file)

    if not ai_config.speech_api_url:
        raise SpeechRecognitionError(detail="语音识别服务未配置")

    try:
        logger.info(f"[SpeechService] 开始识别: {file.filename}")

        response = requests.post(
            ai_config.speech_api_url,
            headers={
                "Authorization": f"Bearer {ai_config.speech_api_key}",
            },
            files={"file": (file.filename, file.stream, file.content_type)},
            data={"language": "zh"},  # 可根据需求调整
            timeout=30,
        )

        if response.status_code != 200:
            raise SpeechRecognitionError(
                detail=f"语音识别API返回 HTTP {response.status_code}"
            )

        result = response.json()
        text = result.get("text", "").strip()

        if not text:
            raise SpeechRecognitionError(detail="未识别到任何内容")

        logger.info(f"[SpeechService] 识别成功: '{text[:50]}...'")
        return text

    except SpeechRecognitionError:
        raise
    except requests.exceptions.Timeout:
        raise SpeechRecognitionError(detail="语音识别请求超时")
    except Exception as e:
        logger.error(f"[SpeechService] 识别异常: {e}")
        raise SpeechRecognitionError(detail=str(e))
```

---

## 11. 请求校验 `api/v1/ai/schemas.py`

```python
"""
请求参数校验

使用纯函数校验，不引入额外校验框架。
校验通过返回清洗后的参数字典，校验失败抛出 InvalidRequestError。
"""

from exceptions.ai_exceptions import InvalidRequestError


def validate_chat_request(data: dict) -> dict:
    """
    校验聊天请求参数

    Returns:
        清洗后的参数字典
    """
    if not data:
        raise InvalidRequestError(detail="请求体不能为空")

    # 必需参数
    message = data.get("message", "")
    if isinstance(message, str):
        message = message.strip()
    if not message:
        raise InvalidRequestError(detail="消息内容不能为空")

    # 可选参数 + 类型校验
    provider = data.get("provider")
    if provider is not None and provider not in ("qwen", "deepseek"):
        raise InvalidRequestError(detail=f"不支持的提供商: {provider}")

    system_prompt = data.get("system_prompt")
    if system_prompt is not None and not isinstance(system_prompt, str):
        raise InvalidRequestError(detail="system_prompt 必须是字符串")

    conversation_history = data.get("conversation_history", [])
    if not isinstance(conversation_history, list):
        raise InvalidRequestError(detail="conversation_history 必须是数组")

    # 验证历史消息格式
    for i, msg in enumerate(conversation_history):
        if not isinstance(msg, dict):
            raise InvalidRequestError(detail=f"conversation_history[{i}] 必须是对象")
        if "role" not in msg or "content" not in msg:
            raise InvalidRequestError(
                detail=f"conversation_history[{i}] 缺少 role 或 content 字段"
            )
        if msg["role"] not in ("user", "assistant", "system"):
            raise InvalidRequestError(
                detail=f"conversation_history[{i}].role 值无效: {msg['role']}"
            )

    try:
        temperature = float(data.get("temperature", 0.7))
        if not 0 <= temperature <= 2:
            raise InvalidRequestError(detail="temperature 范围为 0~2")
    except (TypeError, ValueError):
        raise InvalidRequestError(detail="temperature 必须是数字")

    try:
        max_tokens = int(data.get("max_tokens", 2000))
        if max_tokens < 1 or max_tokens > 8000:
            raise InvalidRequestError(detail="max_tokens 范围为 1~8000")
    except (TypeError, ValueError):
        raise InvalidRequestError(detail="max_tokens 必须是整数")

    return {
        "message": message,
        "provider": provider,
        "system_prompt": system_prompt,
        "conversation_history": conversation_history,
        "temperature": temperature,
        "max_tokens": max_tokens,
    }
```

---

## 12. 提示词配置 `api/v1/ai/prompts.py`

```python
"""
AI学习助手预设提示词

集中管理各场景的系统提示词。
可从数据库/配置文件加载，此处使用常量简化。
"""

AI_PROMPTS: dict[str, str] = {
    "general": (
        "你是一位友好的英语老师Luna，擅长中英双语交流。"
        "你会用简单易懂的方式解答学生的问题，既可以用中文也可以用英文交流。"
        "你的回答要有耐心、鼓励性，适合各个年龄段的学习者。"
    ),
    "speaking": (
        "You are an English speaking tutor. Your goal is to help students "
        "practice English conversation. Speak naturally and encourage them to "
        "express themselves in English. Correct their mistakes gently and "
        "provide better alternatives."
    ),
    "grammar": (
        "你是一位英语语法专家。你的任务是用简单易懂的方式解释英语语法规则，"
        "帮助学生理解和掌握语法知识。对于学生的语法问题，要给出清晰的解释和实用的例子。"
    ),
    "writing": (
        "你是一位英语写作指导老师。你可以帮助学生写作文，提供写作思路，"
        "或者修改学生的作文。要注重写作结构、用词准确性和表达流畅性。"
    ),
    "translate": (
        "你是一位专业的中英翻译。你的任务是准确翻译中英文内容，"
        "并在必要时提供更地道的表达方式。翻译要准确、自然、符合语境。"
    ),
    "qa": (
        "你是一位博学的百科助手。你可以回答各种问题，帮助学生探索和学习新知识。"
        "回答要准确、全面、易于理解。"
    ),
    "planning": (
        "你是一位学习规划顾问。你可以帮助学生制定合理的学习计划，"
        "提供学习方法建议，帮助他们更高效地学习英语。"
    ),
    "vocabulary": (
        "你是一位词汇拓展专家。你可以帮助学生扩展词汇量，"
        "讲解同义词、反义词、词组搭配等。要提供丰富的例句和用法说明。"
    ),
}


def get_prompt(chat_type: str) -> str | None:
    """获取指定类型的提示词，不存在返回None"""
    return AI_PROMPTS.get(chat_type)


def get_all_prompts() -> dict[str, str]:
    """获取所有提示词"""
    return AI_PROMPTS.copy()
```

---

## 13. 路由层（瘦控制器）`api/v1/ai/routes.py`

```python
"""
AI模块路由

设计原则：
- 路由方法只做：参数提取 → 校验 → 调用Service → 格式化响应
- 不含任何业务逻辑
- 统一异常处理
"""

import logging

from flask import request, jsonify
from . import ai_bp  # 蓝图
from .schemas import validate_chat_request
from .prompts import get_all_prompts

from services import ai_chat_service, speech_service
from exceptions.ai_exceptions import (
    AIBaseException,
    InvalidRequestError,
)
from utils.response import success_response, error_response

logger = logging.getLogger(__name__)


# ==================== 异常处理器 ====================

@ai_bp.errorhandler(AIBaseException)
def handle_ai_exception(e: AIBaseException):
    """统一处理AI模块所有自定义异常"""
    logger.error(f"[AI Error] {e.__class__.__name__}: {e.message} | {e.detail}")
    return error_response(e.status_code, e.message, detail=e.detail)


# ==================== 聊天接口 ====================

@ai_bp.route("/chat", methods=["POST"])
def chat():
    """
    AI聊天接口

    请求体:
    {
        "message": "用户消息（必需）",
        "provider": "qwen/deepseek（可选）",
        "system_prompt": "系统提示词（可选）",
        "conversation_history": [{"role": "user", "content": "..."}],
        "temperature": 0.7,
        "max_tokens": 2000
    }

    响应:
    {
        "code": 200,
        "data": {
            "content": "AI回复内容",
            "provider": "qwen",
            "model": "qwen-plus"
        }
    }
    """
    # 1. 校验参数
    data = request.get_json(silent=True)
    params = validate_chat_request(data)  # 校验失败自动抛出 InvalidRequestError

    # 2. 调用服务
    response = ai_chat_service.chat(
        message=params["message"],
        system_prompt=params["system_prompt"],
        conversation_history=params["conversation_history"],
        temperature=params["temperature"],
        max_tokens=params["max_tokens"],
        preferred_provider=params["provider"],
    )

    # 3. 返回结果
    return success_response(response.to_dict())


# ==================== 语音识别接口 ====================

@ai_bp.route("/speech-to-text", methods=["POST"])
def speech_to_text():
    """
    语音转文字接口

    请求: multipart/form-data
    - file: 音频文件（wav/mp3/m4a/ogg/flac，最大10MB）

    响应:
    {
        "code": 200,
        "data": {
            "text": "识别出的文字内容"
        }
    }
    """
    file = request.files.get("file")
    if not file:
        raise InvalidRequestError(detail="未上传音频文件")

    text = speech_service.recognize(file)

    return success_response({"text": text})


# ==================== 提供商管理接口 ====================

@ai_bp.route("/providers", methods=["GET"])
def list_providers():
    """获取可用的AI提供商列表"""
    providers = ai_chat_service.get_providers()
    return success_response({"providers": providers})


@ai_bp.route("/providers/<provider_id>/health", methods=["GET"])
def check_health(provider_id: str):
    """
    测试AI提供商健康状态

    响应:
    {
        "code": 200,
        "data": {
            "provider": "qwen",
            "status": "ok",
            "response_time": 1.23
        }
    }
    """
    result = ai_chat_service.check_provider_health(provider_id)
    return success_response(result)


# ==================== 提示词接口 ====================

@ai_bp.route("/prompts", methods=["GET"])
def list_prompts():
    """获取AI学习助手预设提示词"""
    return success_response({"prompts": get_all_prompts()})
```

---

## 14. 蓝图注册 `api/v1/ai/__init__.py`

```python
"""
AI模块蓝图

URL前缀: /api/v1/ai
"""

from flask import Blueprint

ai_bp = Blueprint("ai", __name__, url_prefix="/ai")

# 导入路由（避免循环引用，放在蓝图创建之后）
from . import routes  # noqa: E402, F401
```

**在 `api/v1/__init__.py` 中注册：**

```python
from flask import Blueprint

api_v1 = Blueprint("api_v1", __name__, url_prefix="/api/v1")

# 注册子模块蓝图
from .ai import ai_bp
api_v1.register_blueprint(ai_bp)
```

---

## 15. 统一响应工具（增强版）`utils/response.py`

```python
"""
统一响应格式工具

所有API返回格式：
{
    "code": 200,
    "message": "success",
    "data": {...}
}
"""

from flask import jsonify


def success_response(data=None, message="success", code=200):
    response = {
        "code": code,
        "message": message,
        "data": data,
    }
    return jsonify(response), code


def error_response(code: int, message: str, detail: str = None):
    response = {
        "code": code,
        "message": message,
    }
    if detail:
        response["detail"] = detail
    return jsonify(response), code
```

---

## 16. 完整调用流程图

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         完整请求处理流程                                      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Flutter 前端                                                               │
│  ┌──────────┐     ┌──────────────┐                                         │
│  │ 用户输入  │     │  长按录音     │                                         │
│  │ 文字消息  │     │  松手停止     │                                         │
│  └────┬─────┘     └──────┬───────┘                                         │
│       │                  │                                                  │
│       │                  ▼                                                  │
│       │          POST /ai/speech-to-text                                    │
│       │          (multipart/form-data)                                      │
│       │                  │                                                  │
│       │                  ▼                                                  │
│       │          ┌───────────────┐                                          │
│       │          │ SpeechService │─── 校验文件 → 调用STT API → 返回文本     │
│       │          └───────┬───────┘                                          │
│       │                  │ 识别文本                                          │
│       │◀─────────────────┘                                                  │
│       │                                                                     │
│       ▼                                                                     │
│  POST /api/v1/ai/chat                                                       │
│  {"message": "...", "system_prompt": "...", "conversation_history": [...]}   │
│       │                                                                     │
│  ═════╪═════════════════════════════════════════════════════════════════     │
│       │                                                                     │
│  Flask 后端                                                                  │
│       │                                                                     │
│       ▼                                                                     │
│  ┌─────────────────┐                                                        │
│  │  routes.py      │  参数提取 + 校验                                        │
│  │  (瘦控制器)      │                                                        │
│  └────────┬────────┘                                                        │
│           │                                                                  │
│           ▼                                                                  │
│  ┌─────────────────────┐                                                    │
│  │  schemas.py          │  validate_chat_request()                           │
│  │  (参数校验)          │  → InvalidRequestError (400)                       │
│  └────────┬─────────────┘                                                   │
│           │ 清洗后的参数                                                     │
│           ▼                                                                  │
│  ┌──────────────────────┐                                                   │
│  │  ai_chat_service.py  │  组装消息列表                                      │
│  │  (业务编排)          │  system_prompt + history + message                 │
│  └────────┬─────────────┘                                                   │
│           │ List[ChatMessageDTO]                                            │
│           ▼                                                                  │
│  ┌──────────────────────┐                                                   │
│  │  ProviderManager     │  优先级排序 → 依次尝试                              │
│  │  (降级策略)          │                                                    │
│  └────────┬─────────────┘                                                   │
│           │                                                                  │
│     ┌─────┴─────┐                                                           │
│     ▼           ▼                                                           │
│  ┌────────┐ ┌──────────┐                                                    │
│  │ Qwen   │ │ DeepSeek │  ← BaseAIProvider.call() 模板方法                  │
│  │Provider│ │ Provider │                                                    │
│  └───┬────┘ └────┬─────┘                                                    │
│      │           │                                                          │
│      │  ┌────────┘                                                          │
│      ▼  ▼                                                                   │
│  ┌──────────────┐                                                           │
│  │  retry装饰器  │  失败自动重试（指数退避）                                   │
│  └──────┬───────┘                                                           │
│         │                                                                   │
│         ▼                                                                   │
│  ┌──────────────┐                                                           │
│  │  HTTP请求     │  requests.post → AI大模型API                              │
│  └──────┬───────┘                                                           │
│         │                                                                   │
│         ▼                                                                   │
│  ┌──────────────┐                                                           │
│  │ ChatResponse  │  success=True → 返回内容                                 │
│  │              │  success=False → 尝试下一个Provider                        │
│  └──────┬───────┘  全部失败 → AllProvidersFailedError                       │
│         │                                                                   │
│  ═══════╪═══════════════════════════════════════════════════════════════     │
│         │                                                                   │
│         ▼                                                                   │
│  Flutter 收到响应                                                            │
│  {"code": 200, "data": {"content": "...", "provider": "qwen"}}              │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 重构对比总结

| 维度 | 重构前 | 重构后 |
|------|--------|--------|
| **文件结构** | 单文件 400+ 行 | 14 个文件，每个 < 120 行 |
| **提供商扩展** | 新增需改 `call_ai_with_fallback` + 写新函数 | 只需新建子类 + 注册一行 |
| **参数校验** | 路由方法内散落校验 | `schemas.py` 集中校验，返回清洗后数据 |
| **异常处理** | try-catch + 字符串拼接 | 异常体系 + `errorhandler` 统一捕获 |
| **重试机制** | 简单循环 | 指数退避 + 可配置异常类型 + 日志 |
| **配置管理** | 函数内字典 | `dataclass(frozen=True)` 不可变配置 |
| **语音识别** | 仅前端提及 | 完整后端服务（校验+调用+异常） |
| **日志** | 无 | 每层关键节点记录日志 |
| **可测试性** | 路由+业务+API调用耦合 | 三层解耦，可独立mock测试 |
| **线程安全** | 全局字典 | 单例 + Lock |