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
