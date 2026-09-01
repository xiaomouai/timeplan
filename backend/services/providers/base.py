"""
AI提供商抽象基类

定义统一的调用接口，所有具体提供商必须实现。
遵循开放-封闭原则：新增提供商只需添加子类，无需修改现有代码。
"""

from abc import ABC, abstractmethod
import logging
from typing import Optional, List, Tuple
import requests as http_requests

from services.ai_config import ProviderConfig
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
        messages: List[ChatMessageDTO],
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

    def _endpoint_url(self) -> str:
        """实际请求的 URL。默认即配置中的 base_url，子类可覆盖（如兼容模式补路径）。"""
        return self.config.base_url

    def call(
        self,
        messages: List[ChatMessageDTO],
        temperature: float = 0.7,
        max_tokens: int = 2000,
    ) -> ChatResponse:
        """
        调用AI API（模板方法）

        流程：构建请求 → 发送HTTP → 解析响应
        子类只需实现 _build_headers / _build_request_body / _parse_response
        """
        headers = self._build_headers()
        body = self._build_request_body(messages, temperature, max_tokens)

        logger.info(
            f"[{self.provider_id}] 调用API, "
            f"model={self.config.model}, messages={len(messages)}条"
        )

        try:
            response = http_requests.post(
                self._endpoint_url(),
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

    def health_check(self) -> Tuple[bool, Optional[float]]:
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
