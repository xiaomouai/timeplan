"""狮子英语 API 应用入口。"""

import os
from datetime import datetime
from pathlib import Path

from flask import Flask, jsonify, send_from_directory
from flask_cors import CORS
from flasgger import Swagger


def create_app(config_name=None):
    """创建 Flask 应用，保留 ``app`` 模块级入口供 gunicorn 等加载。"""
    from config import config as app_config

    config_name = config_name or os.getenv("FLASK_ENV", "development")
    app = Flask(__name__)
    app.config.from_object(app_config.get(config_name, app_config["development"]))
    app.config["JSON_AS_ASCII"] = False

    _ensure_runtime_directories(app)
    CORS(
        app,
        supports_credentials=True,
        resources={r"/*": {"origins": app.config["CORS_ORIGINS"]}},
    )
    _init_extensions(app)

    # 导入模型以确保 db.create_all() 能识别到表结构。
    with app.app_context():
        import models  # noqa: F401

    _create_tables_if_enabled(app)
    _init_swagger(app)
    register_blueprints(app)
    register_core_routes(app)
    register_admin_routes(app)
    register_error_handlers(app)
    return app


def _ensure_runtime_directories(app):
    """创建本地启动必需的运行目录。"""
    Path(app.config["INSTANCE_DIR"]).mkdir(parents=True, exist_ok=True)
    Path(app.config["UPLOAD_FOLDER"]).mkdir(parents=True, exist_ok=True)
    Path(app.config["LOG_FILE"]).parent.mkdir(parents=True, exist_ok=True)


def _init_extensions(app):
    from extensions import db, migrate, jwt

    db.init_app(app)
    migrate.init_app(app, db)
    jwt.init_app(app)


def _create_tables_if_enabled(app):
    if not app.config.get("AUTO_CREATE_DB"):
        return

    from extensions import db

    with app.app_context():
        try:
            db.create_all()
            app.logger.info("数据库表自动创建/验证完成")
        except Exception:
            # 数据库未启动时仍让健康检查和 Swagger 可用，具体错误写入日志。
            app.logger.warning("数据库表创建失败，请检查 SQLALCHEMY_DATABASE_URI", exc_info=True)


def _init_swagger(app):
    swagger_config = {
        "headers": [],
        "specs": [
            {
                "endpoint": "apispec",
                "route": "/apispec.json",
                "rule_filter": lambda rule: True,
                "model_filter": lambda tag: True,
            }
        ],
        "static_url_path": "/flasgger_static",
        "swagger_ui": True,
        "specs_route": "/api/docs",
    }
    swagger_template = {
        "swagger": "2.0",
        "info": {
            "title": "狮子英语 API",
            "description": "基于Dict词库的小学英语学习API - 完整的RESTful接口文档",
            "version": "2.0.0",
            "contact": {"name": "狮子英语团队", "email": "support@lioneng.com"},
        },
        "host": "localhost:5000",
        "basePath": "/",
        "schemes": ["http", "https"],
        "securityDefinitions": {
            "Bearer": {
                "type": "apiKey",
                "name": "Authorization",
                "in": "header",
                "description": "JWT授权，格式: Bearer {token}",
            }
        },
        "tags": [
            {"name": "教材管理", "description": "教材版本和词书管理"},
            {"name": "单词学习", "description": "单词查询、学习和搜索"},
            {"name": "闯关练习", "description": "单元闯关和挑战"},
            {"name": "听写练习", "description": "单词和短语听写"},
            {"name": "用户认证", "description": "注册、登录和token管理"},
            {"name": "用户中心", "description": "用户信息和设置"},
        ],
    }
    Swagger(app, config=swagger_config, template=swagger_template)


def register_blueprints(app):
    """注册统一使用 ``/api/v1`` 前缀的业务蓝图。"""
    from api import api_v1

    app.register_blueprint(api_v1, url_prefix="/api/v1")
    app.logger.info("API 路由注册完成")


def register_core_routes(app):
    @app.route("/")
    def index():
        return jsonify(
            {
                "name": "狮子英语 API",
                "version": "2.0.0",
                "status": "running",
                "description": "基于Dict词库的小学英语学习API",
                "documentation": "/api/docs",
                "base_url": "/api/v1",
                "modules": {
                    "textbook": "教材管理",
                    "word": "单词学习",
                    "auth": "用户认证",
                    "user": "用户中心",
                    "membership": "会员系统",
                    "payment": "支付系统",
                    "speech": "独立发音评测",
                    "challenge": "闯关练习",
                    "dictation": "听写练习",
                },
                "key_endpoints": {
                    "health": "/api/v1/health",
                    "textbooks": "/api/v1/textbooks",
                    "books": "/api/v1/books",
                    "words": "/api/v1/words/{book_id}/{word_rank}",
                    "membership": "/api/v1/membership/status",
                    "challenge": "/api/v1/challenge/create",
                    "dictation": "/api/v1/dictation/create",
                    "payment": "/api/v1/payment/create",
                    "speech": "/api/v1/speech/evaluate",
                },
            }
        )

    @app.route("/health")
    @app.route("/api/v1/health")
    def health():
        """健康检查接口。"""
        from utils.response import success_response

        return success_response(
            {
                "status": "healthy",
                "message": "API is running",
                "version": "2.0.0",
                "timestamp": datetime.now().isoformat(),
            }
        )


def register_admin_routes(app):
    admin_path = Path(app.root_path) / "admin"

    @app.route("/xuebaApi/admin/")
    @app.route("/xuebaApi/admin/<path:path>")
    def serve_admin(path="index.html"):
        return send_from_directory(admin_path, path)


def register_error_handlers(app):
    from utils.response import error_response

    @app.errorhandler(400)
    def bad_request(error):
        return error_response(400, "请求参数错误")

    @app.errorhandler(401)
    def unauthorized(error):
        return error_response(401, "未授权，请先登录")

    @app.errorhandler(403)
    def forbidden(error):
        return error_response(403, "禁止访问")

    @app.errorhandler(404)
    def not_found(error):
        return error_response(404, "资源不存在")

    @app.errorhandler(500)
    def internal_error(error):
        return error_response(500, "服务器内部错误")


# 保留模块级实例，兼容 ``python app.py``、gunicorn 和既有部署脚本。
app = create_app()


if __name__ == "__main__":
    host = app.config.get("HOST", "0.0.0.0")
    port = app.config.get("PORT", 5000)
    debug = app.config.get("DEBUG", False)
    print("狮子英语 API 服务启动中...")
    print(f"服务地址: http://localhost:{port}")
    print(f"健康检查: http://localhost:{port}/health")
    print(f"API 文档: http://localhost:{port}/api/docs")
    app.run(host=host, port=port, debug=debug)
