"""
多 Agent 任务框架数据模型（后端 API 驱动版）

原本任务/日志/结果以本地 markdown 三件套存在；现改为后端真实数据源：
- AgentTask：任务主体（目标/范围/验收/负责人/状态）
- AgentLog：执行日志（start/progress/handoff/finish 等节点）
- AgentResult：完成收据（交付物/验收证据/未完成边界）

这样「多 Agent 框架」本身也成为动态后端 API，不再依赖本地模拟文件。
"""
from datetime import datetime
from extensions import db
import uuid


class AgentTask(db.Model):
    __tablename__ = "agent_tasks"

    id = db.Column(db.String(32), primary_key=True)  # TASK-YYYYMMDD-NNN
    title = db.Column(db.String(128), nullable=False)
    goal = db.Column(db.Text)
    scope = db.Column(db.Text)
    status = db.Column(db.String(16), default="planned")  # planned/in_progress/blocked/completed
    owner = db.Column(db.String(32))  # Coordinator/Researcher/Implementer/...
    parent_id = db.Column(db.String(32), db.ForeignKey("agent_tasks.id"), nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    logs = db.relationship(
        "AgentLog", backref="task", lazy="dynamic", cascade="all, delete-orphan",
        order_by="AgentLog.created_at",
    )
    result = db.relationship(
        "AgentResult", backref="task", uselist=False, cascade="all, delete-orphan"
    )

    def to_dict(self, with_logs=False, with_result=False):
        data = {
            "id": self.id,
            "title": self.title,
            "goal": self.goal,
            "scope": self.scope,
            "status": self.status,
            "owner": self.owner,
            "parent_id": self.parent_id,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None,
        }
        if with_logs:
            data["logs"] = [log.to_dict() for log in self.logs.all()]
        if with_result and self.result:
            data["result"] = self.result.to_dict()
        return data


class AgentLog(db.Model):
    __tablename__ = "agent_logs"

    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    task_id = db.Column(db.String(32), db.ForeignKey("agent_tasks.id"), nullable=False, index=True)
    node = db.Column(db.String(16), nullable=False)  # start/progress/handoff/finish
    actor = db.Column(db.String(32))  # 角色
    content = db.Column(db.Text, nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    def to_dict(self):
        return {
            "id": self.id,
            "task_id": self.task_id,
            "node": self.node,
            "actor": self.actor,
            "content": self.content,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }


class AgentResult(db.Model):
    __tablename__ = "agent_results"

    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    task_id = db.Column(db.String(32), db.ForeignKey("agent_tasks.id"), nullable=False, unique=True)
    receipt = db.Column(db.Text)
    acceptance = db.Column(db.Text)  # JSON 字符串
    changed_files = db.Column(db.Text)  # JSON 字符串
    boundary = db.Column(db.Text)
    next_steps = db.Column(db.Text)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    def to_dict(self):
        return {
            "task_id": self.task_id,
            "receipt": self.receipt,
            "acceptance": self.acceptance,
            "changed_files": self.changed_files,
            "boundary": self.boundary,
            "next_steps": self.next_steps,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }
