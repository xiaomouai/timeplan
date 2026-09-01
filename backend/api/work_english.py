"""工作英语训练记录 API。

训练内容由现有 AI 接口生成；本模块只负责保存和读取用户自己的训练快照。
"""

from datetime import date, datetime
import string
from uuid import uuid4

from flask import request
from flask_jwt_extended import get_jwt_identity, jwt_required

from . import api_v1
from models import db
from models.study_models import StudyLog
from services.membership_service import MembershipService
from utils.response import error_response, success_response


MODULE = "work_english"
MAX_HISTORY = 50
MAX_TURNS = 12
PRO_FEATURE = "work_english_history"


def _text(data, key, limit, *, required=False):
    value = data.get(key)
    if value is None and not required:
        return ""
    if not isinstance(value, str):
        raise ValueError(f"{key} 必须是字符串")
    value = value.strip()
    if required and not value:
        raise ValueError(f"{key} 不能为空")
    if len(value) > limit:
        raise ValueError(f"{key} 长度不能超过 {limit} 个字符")
    return value


def _session_id(value):
    if value in (None, ""):
        return uuid4().hex
    if not isinstance(value, str) or len(value) != 32 or any(
        char not in string.hexdigits for char in value
    ):
        raise ValueError("session_id 必须是 32 位十六进制字符串")
    return value.lower()


def _turns(value):
    if value is None:
        return []
    if not isinstance(value, list) or len(value) > MAX_TURNS:
        raise ValueError(f"turns 必须是最多 {MAX_TURNS} 条记录的数组")

    result = []
    for index, turn in enumerate(value):
        if not isinstance(turn, dict):
            raise ValueError(f"turns[{index}] 必须是对象")
        scene_index = turn.get("scene_index")
        if isinstance(scene_index, bool) or not isinstance(scene_index, int) or not 1 <= scene_index <= 3:
            raise ValueError(f"turns[{index}].scene_index 必须是 1 到 3")
        result.append(
            {
                "scene_index": scene_index,
                "scene_title": _text(turn, "scene_title", 100, required=True),
                "phase": _text(turn, "phase", 40, required=True),
                "answer_en": _text(turn, "answer_en", 2000, required=True),
                "feedback": _text(turn, "feedback", 10000, required=True),
            }
        )
    return result


def _validate_state(turns, scene_index, completed):
    """校验客户端状态机，scene_index 表示下一个待进入的场景（0-2）。"""
    expected_scene_index = min(len(turns) // 2, 2)
    if scene_index != expected_scene_index:
        raise ValueError("训练状态不能跳过场景或回退")

    for position, turn in enumerate(turns):
        expected_scene = position // 2 + 1
        expected_phase = "first_attempt" if position % 2 == 0 else "retry"
        if turn["scene_index"] != expected_scene:
            raise ValueError(f"turns[{position}].scene_index 不符合训练顺序")
        if turn["phase"] != expected_phase:
            raise ValueError(f"turns[{position}].phase 必须是 {expected_phase}")

    if completed and len(turns) != 6:
        raise ValueError("完成训练前必须完成三个场景的首次表达和重说")
    if not completed and len(turns) == 6:
        raise ValueError("三个场景已完成，completed 必须为 true")


def _has_pro_access(user_id):
    """工作英语历史属于 Pro；免费用户仍可在本地完成训练和保存草稿。"""
    return MembershipService.check_benefit_access(user_id, PRO_FEATURE)


def _pro_error():
    return error_response(
        message="工作英语完成历史和跨设备复习属于 Pro 权益，请先升级会员",
        code=403,
        data={"feature": PRO_FEATURE, "requires_pro": True},
    )


def _snapshot(data):
    completed = data.get("completed", False)
    if not isinstance(completed, bool):
        raise ValueError("completed 必须是布尔值")

    scene_index = data.get("scene_index", 0)
    if isinstance(scene_index, bool) or not isinstance(scene_index, int) or not 0 <= scene_index <= 2:
        raise ValueError("scene_index 必须是 0 到 2")

    turns = _turns(data.get("turns"))
    _validate_state(turns, scene_index, completed)

    return {
        "source_zh": _text(data, "source_zh", 2000, required=True),
        "focus_word": _text(data, "focus_word", 100),
        "role_id": _text(data, "role_id", 80, required=True),
        "role_zh": _text(data, "role_zh", 100, required=True),
        "scenario_id": _text(data, "scenario_id", 80, required=True),
        "scenario_zh": _text(data, "scenario_zh", 100, required=True),
        "scene_index": scene_index,
        "completed": completed,
        "saved_at": datetime.utcnow().isoformat() + "Z",
        "turns": turns,
        "state_version": 1,
        "retry_required": not completed and len(turns) % 2 == 1,
        "current_scene": 3 if completed else scene_index + 1,
    }


def _record_data(record):
    details = record.details if isinstance(record.details, dict) else {}
    return {
        **details,
        "session_id": record.id,
        "created_at": record.created_at.isoformat() if record.created_at else None,
    }


def _payload():
    data = request.get_json(silent=True)
    if not isinstance(data, dict):
        raise ValueError("请求体必须是 JSON 对象")
    return data


@api_v1.route("/work-english/sessions", methods=["POST"])
@jwt_required()
def save_session():
    """创建或更新当前用户的工作英语训练快照。"""
    try:
        data = _payload()
        session_id = _session_id(data.get("session_id"))
        snapshot = _snapshot(data)
    except ValueError as error:
        return error_response(message=str(error), code=400)

    user_id = str(get_jwt_identity())
    record = db.session.get(StudyLog, session_id)
    if record and (record.user_id != user_id or record.module != MODULE):
        return error_response(message="训练记录不存在", code=404)

    if record and isinstance(record.details, dict):
        old_turns = record.details.get("turns")
        if isinstance(old_turns, list) and len(snapshot["turns"]) < len(old_turns):
            return error_response(message="训练状态不能回退", code=409)

    if snapshot["completed"]:
        try:
            if not _has_pro_access(user_id):
                return _pro_error()
        except Exception:
            return error_response(message="会员状态暂不可用，请稍后重试", code=503)

    created = record is None
    if created:
        record = StudyLog(
            id=session_id,
            user_id=user_id,
            date=date.today(),
            module=MODULE,
        )
        db.session.add(record)

    record.date = date.today()
    record.duration = 0
    record.words_count = len(snapshot["turns"])
    record.correct_count = 1 if snapshot["completed"] else 0
    record.details = snapshot
    record.created_at = datetime.utcnow()

    try:
        db.session.commit()
    except Exception:
        db.session.rollback()
        return error_response(message="训练记录保存失败，请稍后重试", code=500)

    return success_response(
        data=_record_data(record),
        message="训练记录已创建" if created else "训练记录已更新",
        status_code=201 if created else 200,
    )


@api_v1.route("/work-english/access", methods=["GET"])
@jwt_required()
def work_english_access():
    """返回工作英语的服务端权益边界，客户端不以本地缓存判定 Pro。"""
    user_id = str(get_jwt_identity())
    try:
        is_pro = _has_pro_access(user_id)
        membership_type = MembershipService.get_membership_type(user_id)
    except Exception:
        return error_response(message="会员状态暂不可用，请稍后重试", code=503)
    return success_response(
        data={
            "can_train": True,
            "can_save_draft": True,
            "can_save_history": is_pro,
            "can_replay_history": is_pro,
            "membership_type": membership_type,
            "feature": PRO_FEATURE,
        }
    )


@api_v1.route("/work-english/sessions", methods=["GET"])
@jwt_required()
def list_sessions():
    """获取当前用户已完成的工作英语训练记录。"""
    raw_limit = request.args.get("limit", "20")
    try:
        limit = int(raw_limit)
    except (TypeError, ValueError):
        return error_response(message="limit 必须是整数", code=400)
    if not 1 <= limit <= MAX_HISTORY:
        return error_response(message=f"limit 必须在 1 到 {MAX_HISTORY} 之间", code=400)

    user_id = str(get_jwt_identity())
    try:
        if not _has_pro_access(user_id):
            return _pro_error()
    except Exception:
        return error_response(message="会员状态暂不可用，请稍后重试", code=503)

    records = (
        StudyLog.query.filter_by(user_id=user_id, module=MODULE)
        .order_by(StudyLog.created_at.desc())
        .all()
    )
    completed = [
        record
        for record in records
        if isinstance(record.details, dict) and record.details.get("completed") is True
    ]
    items = [_record_data(record) for record in completed[:limit]]
    return success_response(
        data={"items": items, "total": len(completed), "limit": limit}
    )


@api_v1.route("/work-english/sessions/<session_id>", methods=["GET"])
@jwt_required()
def get_session(session_id):
    """获取当前用户的一条工作英语训练记录。"""
    user_id = str(get_jwt_identity())
    record = StudyLog.query.filter_by(
        id=session_id,
        user_id=user_id,
        module=MODULE,
    ).first()
    if not record:
        return error_response(message="训练记录不存在", code=404)
    if isinstance(record.details, dict) and record.details.get("completed") is True:
        try:
            if not _has_pro_access(user_id):
                return _pro_error()
        except Exception:
            return error_response(message="会员状态暂不可用，请稍后重试", code=503)
    return success_response(data=_record_data(record))


@api_v1.route("/work-english/sessions/<session_id>", methods=["DELETE"])
@jwt_required()
def delete_session(session_id):
    """删除当前用户的一条工作英语训练记录。"""
    user_id = str(get_jwt_identity())
    record = StudyLog.query.filter_by(
        id=session_id,
        user_id=user_id,
        module=MODULE,
    ).first()
    if not record:
        return error_response(message="训练记录不存在", code=404)

    try:
        db.session.delete(record)
        db.session.commit()
    except Exception:
        db.session.rollback()
        return error_response(message="训练记录删除失败，请稍后重试", code=500)
    return success_response(data={"session_id": session_id}, message="训练记录已删除")
