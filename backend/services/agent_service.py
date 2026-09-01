"""
多 Agent 任务框架服务：任务 / 日志 / 结果 的 CRUD。

状态真源从本地 markdown 三件套迁移到后端数据库，由 API 驱动，
配合 AGENTS.md 的纪律（每任务三件套 + 日志四节点）做结构校验。
"""
from extensions import db
from models.agent_models import AgentTask, AgentLog, AgentResult


VALID_STATUS = {"planned", "in_progress", "blocked", "completed"}
VALID_NODES = {"start", "progress", "decision", "handoff", "blocker", "finish"}


def create_task(data):
    task = AgentTask(
        id=data["id"],
        title=data["title"],
        goal=data.get("goal"),
        scope=data.get("scope"),
        status=data.get("status", "planned"),
        owner=data.get("owner"),
        parent_id=data.get("parent_id"),
    )
    db.session.add(task)
    db.session.commit()
    return task.to_dict()


def get_task(task_id, with_logs=True, with_result=True):
    task = AgentTask.query.get(task_id)
    if not task:
        return None
    return task.to_dict(with_logs=with_logs, with_result=with_result)


def list_tasks(status=None, owner=None):
    q = AgentTask.query
    if status:
        q = q.filter_by(status=status)
    if owner:
        q = q.filter_by(owner=owner)
    tasks = q.order_by(AgentTask.created_at.desc()).all()
    return [t.to_dict() for t in tasks]


def update_status(task_id, status, owner=None):
    if status not in VALID_STATUS:
        raise ValueError(f"非法状态: {status}")
    task = AgentTask.query.get(task_id)
    if not task:
        return None
    task.status = status
    if owner:
        task.owner = owner
    db.session.commit()
    return task.to_dict()


def append_log(task_id, node, content, actor=None):
    if node not in VALID_NODES:
        raise ValueError(f"非法日志节点: {node}")
    task = AgentTask.query.get(task_id)
    if not task:
        return None
    log = AgentLog(task_id=task_id, node=node, content=content, actor=actor)
    db.session.add(log)
    db.session.commit()
    return log.to_dict()


def upsert_result(task_id, data):
    task = AgentTask.query.get(task_id)
    if not task:
        return None
    res = AgentResult.query.filter_by(task_id=task_id).first()
    if res is None:
        res = AgentResult(task_id=task_id)
        db.session.add(res)
    res.receipt = data.get("receipt")
    res.acceptance = data.get("acceptance")
    res.changed_files = data.get("changed_files")
    res.boundary = data.get("boundary")
    res.next_steps = data.get("next_steps")
    db.session.commit()
    return res.to_dict()


def registry():
    tasks = AgentTask.query.order_by(AgentTask.created_at.desc()).all()
    return [t.to_dict(with_logs=False, with_result=False) for t in tasks]
