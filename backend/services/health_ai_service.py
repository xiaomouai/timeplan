"""
健康 AI 服务：调用真实 DeepSeek（经 ProviderManager）动态生成个性化计划。

关键点：
- 不使用任何模拟数据：模型未配置/调用失败（含所有 provider 全部不可用）时明确返回
  error，绝不回退到假数据。
- 计划完全基于用户真实打卡 + 体检数据，输出结构化 JSON 并落库可追溯。
"""
import json
import logging
from datetime import date, timedelta
from extensions import db
from models.health_models import (
    HealthProfile,
    HealthHabit,
    HealthCheckin,
    HealthBiometric,
    HealthPlan,
)
import services.ai_chat_service as ai_chat_service
from services.ai_config import ai_config

logger = logging.getLogger(__name__)

SYSTEM_PROMPT = """你是一名循证健康教练，依据柳叶刀委员会 2024（14 项痴呆可改变风险因素）与 eClinicalMedicine 2026 SPAN 研究（UK Biobank 59078 人、随访 8.1 年）为用户生成个性化健康计划。
原则：
1. 只基于用户真实打卡与体检数据给建议，绝不编造数值或指标。
2. 区分证据等级：
   - A 级（明确阈值）：睡眠 7.2–8h、中高强度运动 >42min、膳食质量 57.5–72.5、零吸烟、限酒 <21 单位/周；
   - B 级（监测）：血压 <130、LDL <2.6、视力、听力、体重腰围；
   - C 级（委员会原话：保持认知/身体/社交活跃，但无单一活动保护证据）。
3. 尊重 4 周落地节奏（阶段 0..3）：阶段 0 只推睡眠/起身/蔬菜；阶段 1 加运动；阶段 2 加认知；阶段 3 才全量。
4. 输出严格 JSON，不要 markdown 代码块，不要任何解释性前缀。"""


def _build_context(profile_id, period):
    profile = HealthProfile.query.get(profile_id)
    habits = HealthHabit.query.filter_by(active=True).all()
    today = date.today()
    start = today - timedelta(days=14)
    checks = HealthCheckin.query.filter(
        HealthCheckin.profile_id == profile_id,
        HealthCheckin.log_date >= start,
    ).all()

    agg = {}
    for h in habits:
        hs = [c for c in checks if c.habit_key == h.key]
        if h.unit == "boolean":
            done = sum(1 for c in hs if c.done)
            agg[h.key] = {
                "done_days": done,
                "tracked_days": len(hs),
                "rate": round(done / len(hs), 2) if hs else 0,
            }
        else:
            vals = [c.value for c in hs if c.value is not None]
            agg[h.key] = {
                "avg": round(sum(vals) / len(vals), 2) if vals else None,
                "tracked_days": len(vals),
                "target": h.target_value,
                "unit": h.unit,
            }

    bio = HealthBiometric.query.filter_by(profile_id=profile_id).order_by(
        HealthBiometric.record_date.desc()
    ).first()

    return {
        "phase": profile.current_phase if profile else 0,
        "habits": [
            {"key": h.key, "title": h.title, "grade": h.grade,
             "target": h.target_value, "unit": h.unit, "phase": h.phase}
            for h in habits
        ],
        "recent_14d": agg,
        "biometric": bio.to_dict() if bio else None,
    }


def _period_cn(period):
    return {"daily": "今日", "weekly": "本周", "quarterly": "本季"}.get(period, "今日")


def _extract_json(text):
    try:
        s = text.index("{")
        e = text.rindex("}") + 1
        return json.loads(text[s:e])
    except Exception:
        return None


def _call_ai(**kwargs):
    """统一调用 AI，捕获 provider 全失败抛出的异常，转为失败结果（绝不回退模拟）。"""
    try:
        return ai_chat_service.chat(**kwargs)
    except Exception as e:  # AllProvidersFailedError 等
        logger.error("AI 调用异常: %s", e)
        return None


def generate_plan(profile_id, period="daily"):
    """调用真实 LLM 生成个性化计划并落库。失败返回 error（无模拟回退）。"""
    ctx = _build_context(profile_id, period)
    period_cn = _period_cn(period)

    user_msg = (
        f"用户当前阶段：{ctx['phase']}。\n"
        f"可追踪习惯与阈值：{json.dumps(ctx['habits'], ensure_ascii=False)}\n"
        f"近 14 天真实数据：{json.dumps(ctx['recent_14d'], ensure_ascii=False)}\n"
        f"最近体检：{json.dumps(ctx['biometric'], ensure_ascii=False)}\n\n"
        f"请基于以上真实数据，生成{period_cn}个性化健康计划，严格 JSON：\n"
        "{\n"
        '  "focus": "一句话重点",\n'
        '  "actions": [{"habit_key":"...","title":"...","why":"基于数据的理由","target_today":"具体可执行目标"}],\n'
        '  "watchouts": ["风险提醒（基于 B 级监测项）"],\n'
        '  "coach_note": "鼓励性总结"\n'
        "}"
    )

    resp = _call_ai(
        message=user_msg,
        system_prompt=SYSTEM_PROMPT,
        preferred_provider=ai_config.default_provider,
        temperature=0.5,
        max_tokens=1500,
    )
    if resp is None or not getattr(resp, "success", False):
        err = getattr(resp, "error", None) if resp else "AI 服务无响应"
        logger.error("AI 生成计划失败: %s", err)
        return {"success": False, "error": err or "AI 返回失败"}

    content = resp.content or ""
    parsed = _extract_json(content)
    plan = HealthPlan(
        profile_id=profile_id,
        period=period,
        model=getattr(resp, "model", None),
        provider=getattr(resp, "provider", None),
        content=json.dumps(parsed, ensure_ascii=False) if parsed else content,
        summary=parsed.get("focus") if isinstance(parsed, dict) else None,
        based_on=json.dumps(ctx, ensure_ascii=False)[:2000],
    )
    db.session.add(plan)
    db.session.commit()
    return {
        "success": True,
        "content": plan.content,
        "summary": plan.summary,
        "plan": plan.to_dict(),
        "parsed": parsed,
        "raw": content,
    }


def coach(profile_id, message, history=None):
    """AI 健康教练对话（真实 LLM，无模拟）。"""
    ctx = _build_context(profile_id, "daily")
    sys_prompt = (
        SYSTEM_PROMPT
        + f"\n用户当前阶段：{ctx['phase']}。"
        + f"最近 14 天真实数据：{json.dumps(ctx['recent_14d'], ensure_ascii=False)}。"
        + "请结合用户数据用简体中文对话式回答，不编造指标。"
    )
    resp = _call_ai(
        message=message,
        system_prompt=sys_prompt,
        conversation_history=history,
        preferred_provider=ai_config.default_provider,
        temperature=0.7,
        max_tokens=1200,
    )
    if resp is None or not getattr(resp, "success", False):
        err = getattr(resp, "error", None) if resp else "AI 服务无响应"
        return {"success": False, "error": err or "AI 返回失败"}
    return {
        "success": True,
        "content": resp.content,
        "provider": resp.provider,
        "model": resp.model,
    }
