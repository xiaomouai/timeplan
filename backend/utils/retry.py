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
from typing import Type, Tuple

logger = logging.getLogger(__name__)


def retry_on_failure(
    max_retries: int = 3,
    delay: float = 1.0,
    backoff_factor: float = 2.0,
    exceptions: Tuple[Type[Exception], ...] = (Exception,),
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
