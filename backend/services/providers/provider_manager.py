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
from typing import Optional, List, Dict, Type
from threading import Lock

from services.ai_config import AIConfig
from models.ai_message import ChatMessageDTO, ChatResponse
from exceptions.ai_exceptions import AllProvidersFailedError, ProviderUnavailableError
from utils.retry import retry_on_failure

from .base import BaseAIProvider
from .qwen_provider import QwenProvider
from .deepseek_provider import DeepSeekProvider
from .simulated_provider import SimulatedProvider

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
        self._providers: Dict[str, BaseAIProvider] = {}
        self._register_providers()

    def _register_providers(self):
        """注册所有已配置的提供商"""

        # 提供商类型映射表 — 新增提供商只需在此添加
        provider_classes: Dict[str, Type[BaseAIProvider]] = {
            "qwen": QwenProvider,
            "deepseek": DeepSeekProvider,
        }

        for provider_id, provider_config in self._config.providers.items():
            if not provider_config.enabled:
                logger.warning(f"[ProviderManager] {provider_id} 未启用，跳过注册")
                continue

            cls = SimulatedProvider if provider_config.mode == "simulation" else provider_classes.get(provider_id)
            if cls is None:
                logger.warning(f"[ProviderManager] 未知的提供商类型: {provider_id}")
                continue

            self._providers[provider_id] = cls(provider_id, provider_config)
            logger.info(
                f"[ProviderManager] 已注册 {provider_id} "
                f"(model={provider_config.model}, mode={provider_config.mode}, "
                f"client={provider_config.client}, "
                f"priority={provider_config.priority})"
            )

    def _get_sorted_providers(
        self, preferred: Optional[str] = None
    ) -> List[BaseAIProvider]:
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
        messages: List[ChatMessageDTO],
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

        errors: List[str] = []

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
        messages: List[ChatMessageDTO],
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

    def list_providers(self) -> List[dict]:
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
                    "mode": provider.config.mode,
                    "client": provider.config.client,
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
