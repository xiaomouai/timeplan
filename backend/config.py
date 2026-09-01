"""狮子英语 API 配置。

所有相对路径都以当前文件所在的后端目录为基准，避免从 Windows 任意目录
启动时出现数据库、词库和日志路径漂移。
"""

import os
from datetime import timedelta
from pathlib import Path

from dotenv import load_dotenv


BASE_DIR = Path(__file__).resolve().parent
INSTANCE_DIR = BASE_DIR / "instance"
# 兼容旧脚本直接导入 basedir 的写法。
basedir = str(BASE_DIR)

# 保留 Path 版本，供类内路径运算（避免被 str 转换后无法做 / 运算）。
_BASE_DIR_P = BASE_DIR
_INSTANCE_DIR_P = INSTANCE_DIR

# 只加载后端目录下的 .env；不会覆盖系统环境变量。
load_dotenv(BASE_DIR / ".env", override=False)


def _env_bool(name: str, default: bool = False) -> bool:
    value = os.getenv(name)
    if value is None:
        return default
    return value.strip().lower() in {"1", "true", "yes", "on"}


def _env_int(name: str, default: int) -> int:
    value = os.getenv(name)
    if value is None or not value.strip():
        return default
    try:
        return int(value)
    except ValueError:
        return default


def _resolve_path(value: str, default: Path) -> str:
    path = Path(value or default)
    return str(path if path.is_absolute() else BASE_DIR / path)


def _database_uri() -> str:
    """读取数据库 URI，并把相对 SQLite URI 固定到 instance 目录。"""
    uri = os.getenv("SQLALCHEMY_DATABASE_URI") or os.getenv("DATABASE_URL")
    if not uri:
        db_user = os.getenv("DB_USER", "root")
        db_password = os.getenv("DB_PASSWORD", "123456")
        db_host = os.getenv("DB_HOST", "localhost")
        db_port = _env_int("DB_PORT", 3306)
        db_name = os.getenv("DB_NAME", "xuebadict")
        return (
            f"mysql+pymysql://{db_user}:{db_password}@{db_host}:{db_port}/"
            f"{db_name}?charset=utf8mb4"
        )

    if uri.startswith("sqlite:///") and not uri.startswith("sqlite:////"):
        relative_path = uri.removeprefix("sqlite:///")
        if relative_path and not Path(relative_path).is_absolute():
            sqlite_path = (INSTANCE_DIR / relative_path).resolve().as_posix()
            return f"sqlite:///{sqlite_path}"
    return uri


def _cors_origins() -> list[str]:
    raw = os.getenv(
        "CORS_ORIGINS",
        "http://127.0.0.1:8080,http://localhost:8080,"
        "http://127.0.0.1:5000,http://localhost:5000",
    )
    return [origin.strip() for origin in raw.split(",") if origin.strip()]


class Config:
    """基础配置。"""

    BASE_DIR = str(_BASE_DIR_P)
    INSTANCE_DIR = str(_INSTANCE_DIR_P)

    SECRET_KEY = os.getenv("SECRET_KEY", "dev-secret-key-change-in-production")
    JWT_SECRET_KEY = os.getenv("JWT_SECRET_KEY", "dev-jwt-secret-key")
    JWT_ACCESS_TOKEN_EXPIRES = timedelta(days=7)
    JWT_REFRESH_TOKEN_EXPIRES = timedelta(days=30)

    # 保留旧配置字段，方便现有脚本继续读取；数据库连接统一由 URI 决定。
    DB_HOST = os.getenv("DB_HOST", "localhost")
    DB_PORT = _env_int("DB_PORT", 3306)
    DB_USER = os.getenv("DB_USER", "root")
    DB_PASSWORD = os.getenv("DB_PASSWORD", "123456")
    DB_NAME = os.getenv("DB_NAME", "xuebadict")

    SQLALCHEMY_DATABASE_URI = _database_uri()
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    SQLALCHEMY_ECHO = _env_bool("SQLALCHEMY_ECHO", False)
    SQLALCHEMY_POOL_SIZE = 10
    SQLALCHEMY_POOL_RECYCLE = 3600

    REDIS_HOST = os.getenv("REDIS_HOST", "localhost")
    REDIS_PORT = _env_int("REDIS_PORT", 6379)
    REDIS_PASSWORD = os.getenv("REDIS_PASSWORD", "")
    REDIS_DB = _env_int("REDIS_DB", 0)
    REDIS_URL = (
        f"redis://:{REDIS_PASSWORD}@{REDIS_HOST}:{REDIS_PORT}/{REDIS_DB}"
        if REDIS_PASSWORD
        else f"redis://{REDIS_HOST}:{REDIS_PORT}/{REDIS_DB}"
    )

    CELERY_BROKER_URL = REDIS_URL
    CELERY_RESULT_BACKEND = REDIS_URL

    MAX_CONTENT_LENGTH = _env_int("MAX_CONTENT_LENGTH", 16 * 1024 * 1024)
    UPLOAD_FOLDER = _resolve_path(os.getenv("UPLOAD_FOLDER", ""), _BASE_DIR_P / "uploads")
    ALLOWED_EXTENSIONS = {"png", "jpg", "jpeg", "gif", "mp3", "wav", "mp4"}

    PAGINATION_PAGE_SIZE = _env_int("PAGINATION_PAGE_SIZE", 20)
    CORS_ORIGINS = _cors_origins()
    HOST = os.getenv("HOST", "0.0.0.0")
    PORT = _env_int("PORT", 5000)
    AUTO_CREATE_DB = _env_bool(
        "AUTO_CREATE_DB", os.getenv("FLASK_ENV", "development") == "development"
    )

    ALIYUN_ACCESS_KEY_ID = os.getenv("ALIYUN_ACCESS_KEY_ID", "")
    ALIYUN_ACCESS_KEY_SECRET = os.getenv("ALIYUN_ACCESS_KEY_SECRET", "")
    ALIYUN_SMS_SIGN_NAME = os.getenv("ALIYUN_SMS_SIGN_NAME", "狮子英语")
    ALIYUN_SMS_TEMPLATE_CODE = os.getenv("ALIYUN_SMS_TEMPLATE_CODE", "")

    OSS_ENDPOINT = os.getenv("OSS_ENDPOINT", "")
    OSS_BUCKET_NAME = os.getenv("OSS_BUCKET_NAME", "")
    OSS_ACCESS_KEY_ID = os.getenv("OSS_ACCESS_KEY_ID", "")
    OSS_ACCESS_KEY_SECRET = os.getenv("OSS_ACCESS_KEY_SECRET", "")

    WECHAT_APP_ID = os.getenv("WECHAT_APP_ID", "")
    WECHAT_MCH_ID = os.getenv("WECHAT_MCH_ID", os.getenv("WECH_ID", ""))
    WECHAT_API_KEY = os.getenv("WECHAT_API_KEY", "")
    WECHAT_NOTIFY_URL = os.getenv("WECHAT_NOTIFY_URL", "")

    ALIPAY_APP_ID = os.getenv("ALIPAY_APP_ID", "")
    ALIPAY_PRIVATE_KEY_PATH = os.getenv("ALIPAY_PRIVATE_KEY_PATH", "")
    ALIPAY_PUBLIC_KEY_PATH = os.getenv("ALIPAY_PUBLIC_KEY_PATH", "")
    ALIPAY_NOTIFY_URL = os.getenv("ALIPAY_NOTIFY_URL", "")

    XUNFEI_APP_ID = os.getenv("XUNFEI_APP_ID", "")
    XUNFEI_API_KEY = os.getenv("XUNFEI_API_KEY", "")
    XUNFEI_API_SECRET = os.getenv("XUNFEI_API_SECRET", "")

    OPENAI_API_KEY = os.getenv("OPENAI_API_KEY", "")
    OPENAI_BASE_URL = os.getenv("OPENAI_BASE_URL", "https://api.openai.com/v1")

    LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO")
    LOG_FILE = _resolve_path(os.getenv("LOG_FILE", ""), _BASE_DIR_P / "logs" / "app.log")


class DevelopmentConfig(Config):
    """开发环境配置。"""

    DEBUG = _env_bool("FLASK_DEBUG", True)


class ProductionConfig(Config):
    """生产环境配置。"""

    DEBUG = False
    SQLALCHEMY_ECHO = False


class TestingConfig(Config):
    """测试环境配置。"""

    TESTING = True
    SQLALCHEMY_DATABASE_URI = "sqlite:///:memory:"
    AUTO_CREATE_DB = False


config = {
    "development": DevelopmentConfig,
    "production": ProductionConfig,
    "testing": TestingConfig,
    "default": DevelopmentConfig,
}
