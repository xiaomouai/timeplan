"""
AI模块配置

所有AI相关的配置项集中管理，支持环境变量覆盖。
包含：提供商连接参数、默认模型参数、速率限制等。
"""

import os
from dataclasses import dataclass, field
from typing import Dict


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
    mode: str = "live"  # live 或 simulation
    client: str = "http"  # http 或 official_sdk

    @property
    def enabled(self) -> bool:
        return self.mode == "simulation" or bool(self.api_key and self.base_url)


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
    providers: Dict[str, ProviderConfig] = field(default_factory=dict)

    # 默认 provider：health/coach 等业务优先使用，可被 AI_DEFAULT_PROVIDER 覆盖
    default_provider: str = "deepseek"


def load_config() -> AIConfig:
    """从环境变量加载配置"""
    providers = {}
    requested_mode = os.getenv("AI_MODE", "live").strip().lower()
    simulation_enabled = requested_mode in {"simulation", "simulated", "mock", "demo"}
    simulation_enabled = simulation_enabled or os.getenv("AI_SIMULATION", "").strip().lower() in {
        "1",
        "true",
        "yes",
        "on",
    }
    provider_mode = "simulation" if simulation_enabled else "live"
    requested_client = os.getenv("AI_CLIENT", "http").strip().lower()
    provider_client = (
        "official_sdk"
        if requested_client in {"official_sdk", "official", "sdk"}
        else "http"
    )

    # 千问配置
    qwen_key = os.getenv("QWEN_API_KEY", "")
    qwen_url = os.getenv("QWEN_BASE_URL", "")
    if simulation_enabled or (qwen_key and qwen_url):
        providers["qwen"] = ProviderConfig(
            name="通义千问",
            api_key=qwen_key,
            base_url=qwen_url,
            model=os.getenv("QWEN_MODEL", "qwen-plus"),
            priority=1,
            mode=provider_mode,
            client=provider_client,
        )

    # DeepSeek配置
    ds_key = os.getenv("DEEPSEEK_API_KEY", "")
    ds_url = os.getenv("DEEPSEEK_BASE_URL", "")
    if simulation_enabled or (ds_key and ds_url):
        providers["deepseek"] = ProviderConfig(
            name="DeepSeek",
            api_key=ds_key,
            base_url=ds_url,
            model=os.getenv("DEEPSEEK_MODEL", "deepseek-chat"),
            priority=2,
            mode=provider_mode,
            client=provider_client,
        )

    default_provider = (
        os.getenv("AI_DEFAULT_PROVIDER", "deepseek").strip().lower() or "deepseek"
    )
    return AIConfig(
        speech_api_url=os.getenv("SPEECH_API_URL", ""),
        speech_api_key=os.getenv("SPEECH_API_KEY", ""),
        providers=providers,
        default_provider=default_provider,
    )


# 模块级单例
ai_config = load_config()
