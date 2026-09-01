"""API 路由包：统一创建 v1 蓝图并注册业务模块。"""

import logging
from importlib import import_module

from flask import Blueprint
from flask_cors import CORS


logger = logging.getLogger(__name__)
api_v1 = Blueprint("api_v1", __name__)
CORS(api_v1)


def _register_blueprint(module_name, blueprint_name, url_prefix):
    module = import_module(f"{__name__}.{module_name}")
    api_v1.register_blueprint(
        getattr(module, blueprint_name),
        url_prefix=url_prefix,
    )


def _load_optional(label, register):
    """加载可选模块；缺少第三方依赖时保留其他 API 可用。"""
    try:
        register()
    except ImportError as exc:
        logger.warning("%s module skipped: %s", label, exc)
    else:
        logger.info("%s module loaded", label)


# 核心模块缺失时应直接暴露错误，避免 API 启动后返回半套核心功能。
from . import textbook, word, auth, user, feedback, work_english  # noqa: F401,E402


# 业务子蓝图：保持原有 URL 前缀。
_load_optional(
    "Membership",
    lambda: _register_blueprint("membership", "bp", "/membership"),
)
_load_optional(
    "Challenge",
    lambda: _register_blueprint("challenge", "bp", "/challenge"),
)
_load_optional(
    "Dictation",
    lambda: _register_blueprint("dictation", "bp", "/dictation"),
)
_load_optional("Audio", lambda: import_module(f"{__name__}.audio"))
_load_optional(
    "AI",
    lambda: _register_blueprint("ai", "ai_bp", "/ai"),
)
_load_optional(
    "Version",
    lambda: _register_blueprint("version", "version_bp", "/version"),
)
_load_optional(
    "Admin",
    lambda: _register_blueprint("admin", "admin_bp", "/admin"),
)
_load_optional(
    "Spelling",
    lambda: _register_blueprint("word_spelling", "spelling_bp", "/spelling"),
)
_load_optional(
    "Activation",
    lambda: _register_blueprint("activation", "activation_bp", "/activation"),
)
_load_optional(
    "Checkin",
    lambda: _register_blueprint("checkin", "checkin_bp", "/checkin"),
)
_load_optional(
    "Payment",
    lambda: _register_blueprint("payment", "payment_bp", "/payment"),
)
_load_optional(
    "Speech evaluator",
    lambda: _register_blueprint("speech_evaluator", "speech_bp", "/speech"),
)
_load_optional(
    "Health",
    lambda: _register_blueprint("health", "bp", "/health"),
)
_load_optional(
    "Planner",
    lambda: _register_blueprint("planner", "bp", "/planner"),
)
_load_optional(
    "Agents",
    lambda: _register_blueprint("agents", "bp", "/agents"),
)


__all__ = ["api_v1"]
