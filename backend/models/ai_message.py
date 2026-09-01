"""
AI消息数据模型

作为服务层内部的数据传输对象（DTO），
与前端传入的JSON和提供商API格式解耦。
"""

from dataclasses import dataclass, field
from enum import Enum
from typing import Optional, List


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

    messages: List[ChatMessageDTO]
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
