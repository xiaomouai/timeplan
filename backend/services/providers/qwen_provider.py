"""
通义千问 AI 提供商实现

千问API使用 DashScope 格式，与标准 OpenAI 格式不同：
- 请求体包裹在 input.messages 和 parameters 中
- 响应在 output.choices[].message.content 中
"""

from typing import List
from models.ai_message import ChatMessageDTO
from models.ai_message import ChatResponse
from .base import BaseAIProvider
from .official_sdk import call_official_sdk
from services.ai_config import ProviderConfig


class QwenProvider(BaseAIProvider):
    """通义千问API适配器"""

    def call(
        self,
        messages: List[ChatMessageDTO],
        temperature: float = 0.7,
        max_tokens: int = 2000,
    ) -> ChatResponse:
        if self.config.client == "official_sdk":
            return call_official_sdk(
                self.provider_id, self.config, messages, temperature, max_tokens
            )
        return super().call(messages, temperature, max_tokens)

    def _build_headers(self) -> dict:
        return {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {self.config.api_key}",
            "X-DashScope-SSE": "disable",
        }

    def _is_compatible_mode(self) -> bool:
        """base_url 含 compatible-mode 时为 OpenAI 兼容接口。"""
        return "compatible-mode" in (self.config.base_url or "")

    def _endpoint_url(self) -> str:
        url = (self.config.base_url or "").rstrip("/")
        if self._is_compatible_mode() and not url.endswith("chat/completions"):
            url = url + "/chat/completions"
        return url

    def _build_request_body(
        self,
        messages: List[ChatMessageDTO],
        temperature: float,
        max_tokens: int,
    ) -> dict:
        if self._is_compatible_mode():
            # OpenAI 兼容格式：messages 平铺，无 input/parameters 包裹
            return {
                "model": self.config.model,
                "messages": [msg.to_dict() for msg in messages],
                "temperature": temperature,
                "max_tokens": max_tokens,
            }
        # DashScope 原生格式
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
        解析千问响应，兼容两种格式：
        - OpenAI 兼容（compatible-mode）：{ "choices": [{"message": {"content": "..."}}] }
        - DashScope 原生：{ "output": { "choices": [{"message": {"content": "..."}}] } }
        """
        if "output" not in response_data:
            # OpenAI 兼容格式
            choices = response_data.get("choices")
            if not choices or len(choices) == 0:
                raise ValueError("响应缺少 'choices' 字段")
            content = choices[0].get("message", {}).get("content")
            if content is None:
                raise ValueError("响应缺少 'content' 字段")
            return content

        # DashScope 原生格式
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
