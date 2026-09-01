"""
多 Agent 任务框架 API（后端驱动版）

端点（挂载于 /api/v1/agents）：
  GET  /tasks                 列表（可按 status/owner 过滤）
  POST /tasks                创建任务（id + title 必填）
  GET  /tasks/<id>           任务详情（含日志 + 结果）
  PUT  /tasks/<id>/status    更新状态
  POST /tasks/<id>/logs      追加日志节点
  POST /tasks/<id>/result    写入/更新完成收据
  GET  /registry             注册表总览
"""
from flask import Blueprint, request
from utils.response import success_response, error_response
from services import agent_service as ags

bp = Blueprint("agents", __name__)


@bp.route("/tasks", methods=["GET"])
def list_tasks():
    return success_response({"tasks": ags.list_tasks(
        request.args.get("status"), request.args.get("owner")
    )})


@bp.route("/tasks", methods=["POST"])
def create_task():
    data = request.get_json(silent=True) or {}
    if not data.get("id") or not data.get("title"):
        return error_response(400, "id 与 title 必填")
    if ags.get_task(data["id"]):
        return error_response(409, "任务已存在")
    try:
        return success_response(ags.create_task(data), msg="created")
    except Exception as e:
        return error_response(400, str(e))


@bp.route("/tasks/<task_id>", methods=["GET"])
def get_task(task_id):
    task = ags.get_task(task_id, with_logs=True, with_result=True)
    if not task:
        return error_response(404, "任务不存在")
    return success_response(task)


@bp.route("/tasks/<task_id>/status", methods=["PUT"])
def update_status(task_id):
    data = request.get_json(silent=True) or {}
    status = data.get("status")
    if not status:
        return error_response(400, "status 必填")
    try:
        task = ags.update_status(task_id, status, data.get("owner"))
    except ValueError as e:
        return error_response(400, str(e))
    if not task:
        return error_response(404, "任务不存在")
    return success_response(task)


@bp.route("/tasks/<task_id>/logs", methods=["POST"])
def append_log(task_id):
    data = request.get_json(silent=True) or {}
    node = data.get("node")
    content = data.get("content")
    if not node or not content:
        return error_response(400, "node 与 content 必填")
    try:
        log = ags.append_log(task_id, node, content, data.get("actor"))
    except ValueError as e:
        return error_response(400, str(e))
    if not log:
        return error_response(404, "任务不存在")
    return success_response(log, msg="logged")


@bp.route("/tasks/<task_id>/result", methods=["POST", "PUT"])
def upsert_result(task_id):
    data = request.get_json(silent=True) or {}
    res = ags.upsert_result(task_id, data)
    if not res:
        return error_response(404, "任务不存在")
    return success_response(res, msg="saved")


@bp.route("/registry", methods=["GET"])
def registry():
    return success_response({"tasks": ags.registry()})
