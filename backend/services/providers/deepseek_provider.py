"""
DeepSeek AI 提供商实现

DeepSeek 兼容 OpenAI API 格式：
- 标准 messages 数组
- 响应在 choices[].message.content 中
"""

from typing import List
from models.ai_message import ChatMessageDTO, ChatResponse
from .base import BaseAIProvider
from .official_sdk import call_official_sdk


class DeepSeekProvider(BaseAIProvider):
    """DeepSeek API适配器"""

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
            "User-Agent": "LionEng/1.0",
        }

    def _build_request_body(
        self,
        messages: List[ChatMessageDTO],
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
