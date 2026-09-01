"""仅创建 health + agent 相关表（绕过全量 create_all 在 SQLite 下对无关模型命名索引的已知错误）。"""
import os

os.environ["AUTO_CREATE_DB"] = "false"
os.environ["SQLALCHEMY_DATABASE_URI"] = "sqlite:///xueba_local.db"

from extensions import db
from models.health_models import (
    HealthProfile,
    HealthHabit,
    HealthCheckin,
    HealthBiometric,
    HealthPlan,
)
from models.agent_models import AgentTask, AgentLog, AgentResult
from app import app

TABLES = [
    HealthProfile.__table__,
    HealthHabit.__table__,
    HealthCheckin.__table__,
    HealthBiometric.__table__,
    HealthPlan.__table__,
    AgentTask.__table__,
    AgentLog.__table__,
    AgentResult.__table__,
]

with app.app_context():
    db.metadata.create_all(bind=db.engine, tables=TABLES, checkfirst=True)
    print("OK: health+agent tables ensured")

# 验证表存在
with app.app_context():
    from sqlalchemy import inspect

    insp = inspect(db.engine)
    print("tables:", sorted(insp.get_table_names()))
