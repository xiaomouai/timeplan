"""
Flask 扩展模块
用于初始化和配置所有 Flask 扩展
"""

from flask_sqlalchemy import SQLAlchemy
from flask_migrate import Migrate
from flask_jwt_extended import JWTManager

# 初始化 Flask 扩展
db = SQLAlchemy()
migrate = Migrate()
jwt = JWTManager()
