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
from typing import Optional, List

from services.ai_config import ai_config
from models.ai_message import ChatMessageDTO, ChatResponse, MessageRole
from services.providers.provider_manager import ProviderManager

logger = logging.getLogger(__name__)

# 初始化提供商管理器（全局单例）
provider_manager = ProviderManager(ai_config)


def chat(
    message: str,
    system_prompt: Optional[str] = None,
    conversation_history: Optional[List[dict]] = None,
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
    messages: List[ChatMessageDTO] = []

    # 1. 系统提示词
    if system_prompt:
        messages.append(ChatMessageDTO.system(system_prompt))

    # 2. 对话历史（截取最近N条）
    if conversation_history:
        max_history = ai_config.max_conversation_history
        recent = conversation_history[-max_history:]
        for item in recent:
            try:
                if isinstance(item, ChatMessageDTO):
                    messages.append(item)
                else:
                    messages.append(ChatMessageDTO.from_dict(item))
            except (KeyError, ValueError, TypeError) as e:
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


def get_providers() -> List[dict]:
    """获取可用提供商列表"""
    return provider_manager.list_providers()


def check_provider_health(provider_id: str) -> dict:
    """健康检查"""
    return provider_manager.health_check(provider_id)
