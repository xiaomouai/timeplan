"""
健康计划 API（动态后端驱动 + 真实 AI 生成）

挂载于 /api/v1/health：
  POST /bootstrap        设备级身份 → 换 JWT + 档案
  GET  /habits           习惯定义（证据化，动态下发）
  GET  /dashboard        今日看板（阶段/连续天数/打卡项/周聚合/体检/最近计划）
  POST /checkin          打卡（批量 upsert）
  POST /biometrics       季度体检记录
  POST /plan/generate    调用真实 LLM 生成个性化计划（落库，失败即报错不回退模拟）
  GET  /plan             计划列表
  POST /coach            AI 健康教练对话（真实 LLM）
  POST /phase            设置落地阶段 0..3
"""
from datetime import date, datetime

from flask import Blueprint, request
from flask_jwt_extended import jwt_required, create_access_token, get_jwt_identity

from utils.response import success_response, error_response
from services import health_service as hs
import services.health_ai_service as hai


bp = Blueprint("health", __name__)


def _profile_id():
    return get_jwt_identity()


def _parse_date(value):
    if not value:
        return date.today()
    try:
        return datetime.strptime(value, "%Y-%m-%d").date()
    except Exception:
        return None


@bp.route("/bootstrap", methods=["POST"])
def bootstrap():
    """设备级身份（client_id）→ 创建/取回档案并签发 JWT。无真实注册体系时的鉴权握手。"""
    data = request.get_json(silent=True) or {}
    client_id = data.get("client_id")
    if not client_id:
        return error_response(400, "client_id 必填")
    try:
        profile = hs.get_or_create_profile(client_id, data.get("nickname"))
        token = create_access_token(identity=profile.id)
        return success_response(
            {"token": token, "profile": profile.to_dict()}, msg="bootstrapped"
        )
    except Exception as e:
        return error_response(400, str(e))


@bp.route("/habits", methods=["GET"])
@jwt_required()
def habits():
    try:
        return success_response({"habits": hs.list_habits()})
    except Exception as e:
        return error_response(400, str(e))


@bp.route("/dashboard", methods=["GET"])
@jwt_required()
def dashboard():
    td = _parse_date(request.args.get("date"))
    if td is None:
        return error_response(400, "date 格式应为 YYYY-MM-DD")
    try:
        return success_response(hs.get_dashboard(_profile_id(), td))
    except Exception as e:
        return error_response(400, str(e))


@bp.route("/checkin", methods=["POST"])
@jwt_required()
def checkin():
    data = request.get_json(silent=True) or {}
    ld = _parse_date(data.get("log_date"))
    if ld is None:
        return error_response(400, "log_date 必填且格式为 YYYY-MM-DD")
    entries = data.get("entries") or []
    try:
        saved = hs.upsert_checkins(_profile_id(), ld, entries)
        return success_response({"saved": saved}, msg="checked in")
    except Exception as e:
        return error_response(400, str(e))


@bp.route("/biometrics", methods=["POST"])
@jwt_required()
def biometrics():
    data = request.get_json(silent=True) or {}
    rd = _parse_date(data.get("record_date"))
    if rd is None:
        return error_response(400, "record_date 必填且格式为 YYYY-MM-DD")
    try:
        saved = hs.upsert_biometric(_profile_id(), rd, data)
        return success_response(saved, msg="saved")
    except Exception as e:
        return error_response(400, str(e))


@bp.route("/plan/generate", methods=["POST"])
@jwt_required()
def plan_generate():
    data = request.get_json(silent=True) or {}
    period = data.get("period", "daily")
    if period not in ("daily", "weekly", "quarterly"):
        return error_response(400, "period 必须是 daily/weekly/quarterly")
    result = hai.generate_plan(_profile_id(), period)
    if not result.get("success"):
        return error_response(502, result.get("error", "AI 生成失败"))
    return success_response(result, msg="generated")


@bp.route("/plan", methods=["GET"])
@jwt_required()
def plan_list():
    period = request.args.get("period")
    try:
        limit = int(request.args.get("limit", 5))
    except Exception:
        limit = 5
    try:
        return success_response({"plans": hs.list_plans(_profile_id(), period, limit)})
    except Exception as e:
        return error_response(400, str(e))


@bp.route("/coach", methods=["POST"])
@jwt_required()
def coach():
    data = request.get_json(silent=True) or {}
    message = data.get("message")
    if not message:
        return error_response(400, "message 必填")
    history = data.get("history")
    result = hai.coach(_profile_id(), message, history)
    if not result.get("success"):
        return error_response(502, result.get("error", "AI 教练失败"))
    return success_response(result, msg="ok")


@bp.route("/phase", methods=["POST"])
@jwt_required()
def set_phase():
    data = request.get_json(silent=True) or {}
    try:
        phase = int(data.get("phase"))
    except (TypeError, ValueError):
        return error_response(400, "phase 必须是 0..3 的整数")
    try:
        prof = hs.set_phase(_profile_id(), phase)
    except ValueError as e:
        return error_response(400, str(e))
    if prof is None:
        return error_response(404, "档案不存在")
    return success_response(prof, msg="phase updated")
