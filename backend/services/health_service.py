"""
健康业务服务：打卡、聚合、阶段解锁、种子。

所有数据真实落库（SQLite/MySQL），由后端 API 下发，不依赖客户端硬编码。
习惯 key 与 Flutter 端 health_models 的 id 严格一致，保证多端对齐。
"""
from datetime import datetime, date, timedelta
from extensions import db
from models.health_models import (
    HealthProfile,
    HealthHabit,
    HealthCheckin,
    HealthBiometric,
    HealthPlan,
)


# 证据化种子：柳叶刀委员会 2024（14 项风险）+ eClinicalMedicine 2026 SPAN。
# key 与 Flutter health_models 的 id 一致；phase 0..3 对应 4 周落地阶段。
# 阈值与出处动态存库下发，客户端不再写死。
SEED_HABITS = [
    {
        "key": "sleep", "title": "睡眠 7.2–8.0 小时（固定作息）", "grade": "A",
        "category": "sleep", "description": "认知产能维护成本，固定起床/入睡时间。",
        "unit": "hours", "min_value": 7.2, "max_value": 8.0, "target_value": 7.6, "step": 0.5,
        "frequency": "daily", "phase": 0,
        "source": "eClinicalMedicine 2026 SPAN（UK Biobank 59078人，随访8.1年）：睡眠是组间差9.35年的核心因子",
    },
    {
        "key": "break", "title": "每 50 分钟起身 3 分钟", "grade": "routine",
        "category": "focus", "description": "护眼护颈，维持下午认知峰值。",
        "unit": "count", "min_value": 6, "target_value": 6, "step": 1,
        "frequency": "daily", "phase": 0,
        "source": "认知产能维护惯例（非 RCT，但低成本高收益）",
    },
    {
        "key": "diet", "title": "膳食质量评分 57.5–72.5", "grade": "A",
        "category": "eat", "description": "10 项：蔬果/全谷物/鱼/少含糖饮料等。",
        "unit": "score", "min_value": 57.5, "max_value": 72.5, "target_value": 65, "step": 10,
        "frequency": "daily", "phase": 0,
        "source": "SPAN 2026：膳食质量评分区间与预期寿命正相关",
    },
    {
        "key": "exercise", "title": "中高强度运动 >42 分钟/天", "grade": "A",
        "category": "move", "description": "微喘、心跳加快即可（快走/爬楼/骑行）。",
        "unit": "min", "min_value": 42, "target_value": 45, "step": 5,
        "frequency": "daily", "phase": 1,
        "source": "SPAN 2026：运动剂量反应曲线，>42min/天进入收益区",
    },
    {
        "key": "cognition", "title": "持续认知活跃（学习 + 看书）", "grade": "C",
        "category": "cognitive", "description": "委员会原话：保持认知活跃，无单一活动保护证据——你的学习正好挂第 11 条。",
        "unit": "min", "min_value": 75, "target_value": 75, "step": 5,
        "frequency": "daily", "phase": 2,
        "source": "柳叶刀委员会 2024：推荐保持认知/身体/社交活跃，但无单一活动保护证据",
    },
    {
        "key": "nosmoke", "title": "零吸烟（含电子烟/二手烟）", "grade": "A",
        "category": "avoid", "description": "任何形式烟草均计入风险。",
        "unit": "boolean", "target_value": 1, "step": 1,
        "frequency": "daily", "phase": 3,
        "source": "柳叶刀委员会 2024：吸烟为痴呆可改变风险因素",
    },
    {
        "key": "alcohol", "title": "限酒 <21 单位/周（最好不喝）", "grade": "A",
        "category": "avoid", "description": "1 单位≈350ml 啤酒/150ml 葡萄酒。",
        "unit": "units", "min_value": 0, "max_value": 21, "target_value": 0, "step": 1,
        "frequency": "weekly", "phase": 3,
        "source": "柳叶刀委员会 2024：过量饮酒为可改变风险因素",
    },
    {
        "key": "bp", "title": "血压 <130 mmHg", "grade": "B",
        "category": "monitor", "description": "季度体检重点项（收缩压）。",
        "unit": "mmHg", "max_value": 130, "target_value": 125, "step": 1,
        "frequency": "quarterly", "phase": 3,
        "source": "柳叶刀委员会 2024：高血压为可改变风险因素",
    },
    {
        "key": "ldl", "title": "LDL 胆固醇 <3.4 mmol/L", "grade": "B",
        "category": "monitor", "description": "高危人群目标更严，遵医嘱。",
        "unit": "mmol", "max_value": 3.4, "target_value": 2.6, "step": 0.1,
        "frequency": "quarterly", "phase": 3,
        "source": "柳叶刀委员会 2024（更新版新增高 LDL 胆固醇，约7%）",
    },
    {
        "key": "vision", "title": "视力达标（无未治疗视力受损）", "grade": "B",
        "category": "monitor", "description": "2024 新增未治疗视力受损（约2%）。",
        "unit": "boolean", "target_value": 1, "step": 1,
        "frequency": "quarterly", "phase": 3,
        "source": "柳叶刀委员会 2024（更新版新增视力受损）",
    },
    {
        "key": "hearing", "title": "听力保护达标", "grade": "B",
        "category": "monitor", "description": "避免长期高分贝暴露。",
        "unit": "boolean", "target_value": 1, "step": 1,
        "frequency": "quarterly", "phase": 3,
        "source": "柳叶刀委员会 2024：听力损失为可改变风险因素",
    },
    {
        "key": "metabolic", "title": "体重/BMI/腰围达标", "grade": "B",
        "category": "monitor", "description": "月度记录体重、腰围、静息心率。",
        "unit": "bmi", "min_value": 18.5, "max_value": 24, "target_value": 22, "step": 0.1,
        "frequency": "monthly", "phase": 3,
        "source": "柳叶刀委员会 2024：中年肥胖与认知下降相关",
    },
    {
        "key": "social", "title": "线下社交 ≥60 分钟/周", "grade": "C",
        "category": "social", "description": "线上不算；真实面对面互动。",
        "unit": "min", "min_value": 60, "target_value": 60, "step": 5,
        "frequency": "weekly", "phase": 3,
        "source": "柳叶刀委员会 2024：社交孤立为可改变风险因素",
    },
]


def ensure_seeded():
    """习惯定义表为空时写入证据化种子（幂等）。"""
    if HealthHabit.query.count() == 0:
        for h in SEED_HABITS:
            db.session.add(HealthHabit(**h))
        db.session.commit()


def get_or_create_profile(client_id, nickname=None):
    profile = HealthProfile.query.filter_by(client_id=client_id).first()
    if profile is None:
        profile = HealthProfile(client_id=client_id, nickname=nickname)
        db.session.add(profile)
        db.session.commit()
    return profile


def set_phase(profile_id, phase):
    if not isinstance(phase, int) or phase < 0 or phase > 3:
        raise ValueError("phase 必须为 0..3")
    profile = HealthProfile.query.get(profile_id)
    if profile is None:
        return None
    profile.current_phase = phase
    db.session.commit()
    return profile.to_dict()


def list_habits(profile_id=None, include_inactive=False):
    ensure_seeded()
    q = HealthHabit.query
    if not include_inactive:
        q = q.filter_by(active=True)
    habits = q.order_by(HealthHabit.phase, HealthHabit.id).all()
    return [h.to_dict() for h in habits]


def upsert_checkins(profile_id, log_date, entries):
    saved = []
    for e in entries or []:
        key = e.get("habit_key")
        if not key:
            continue
        habit = HealthHabit.query.filter_by(key=key).first()
        if habit is None:
            continue
        rec = HealthCheckin.query.filter_by(
            profile_id=profile_id, habit_key=key, log_date=log_date
        ).first()
        if rec is None:
            rec = HealthCheckin(profile_id=profile_id, habit_key=key, log_date=log_date)
            db.session.add(rec)
        rec.value = e.get("value")
        rec.done = bool(e.get("done", False))
        rec.note = e.get("note")
        saved.append(rec)
    db.session.commit()
    return [r.to_dict() for r in saved]


def _must_do_keys(current_phase):
    habits = HealthHabit.query.filter(
        HealthHabit.active == True,
        HealthHabit.phase <= current_phase,
        HealthHabit.grade.in_(["A", "routine"]),
    ).all()
    return [h.key for h in habits]


def compute_streak(profile_id, current_phase):
    keys = _must_do_keys(current_phase)
    if not keys:
        return 0

    def day_complete(d):
        checks = HealthCheckin.query.filter_by(profile_id=profile_id, log_date=d).all()
        done = {c.habit_key for c in checks if c.done}
        return all(k in done for k in keys)

    streak = 0
    d = date.today()
    if not day_complete(d):  # 今天还没打完也算从昨天起连续
        d = d - timedelta(days=1)
    while day_complete(d):
        streak += 1
        d = d - timedelta(days=1)
    return streak


def get_dashboard(profile_id, target_date=None):
    target_date = target_date or date.today()
    profile = HealthProfile.query.get(profile_id)
    ensure_seeded()
    current_phase = profile.current_phase if profile else 0

    habits = HealthHabit.query.filter_by(active=True).order_by(HealthHabit.phase, HealthHabit.id).all()
    checks = HealthCheckin.query.filter_by(profile_id=profile_id, log_date=target_date).all()
    check_map = {c.habit_key: c for c in checks}

    items = []
    for h in habits:
        c = check_map.get(h.key)
        items.append({
            **h.to_dict(),
            "logged": c.to_dict() if c else None,
            "done_today": bool(c and c.done),
        })

    streak = compute_streak(profile_id, current_phase)

    # 周聚合：周频习惯（限酒、社交）
    week_start = target_date - timedelta(days=target_date.weekday())
    week_checks = HealthCheckin.query.filter(
        HealthCheckin.profile_id == profile_id,
        HealthCheckin.log_date >= week_start,
        HealthCheckin.log_date <= target_date,
    ).all()
    weekly = {}
    for c in week_checks:
        weekly.setdefault(c.habit_key, 0)
        if c.value is not None:
            weekly[c.habit_key] += c.value

    # 最近一次体检
    bio = HealthBiometric.query.filter_by(profile_id=profile_id).order_by(
        HealthBiometric.record_date.desc()
    ).first()

    # 最近一次 AI 计划
    last_plan = HealthPlan.query.filter_by(profile_id=profile_id, period="daily").order_by(
        HealthPlan.generated_at.desc()
    ).first()

    return {
        "date": target_date.isoformat(),
        "phase": current_phase,
        "streak": streak,
        "items": items,
        "weekly": weekly,
        "biometric": bio.to_dict() if bio else None,
        "last_plan": last_plan.to_dict() if last_plan else None,
    }


def upsert_biometric(profile_id, record_date, data):
    bio = HealthBiometric.query.filter_by(
        profile_id=profile_id, record_date=record_date
    ).first()
    if bio is None:
        bio = HealthBiometric(profile_id=profile_id, record_date=record_date)
        db.session.add(bio)
    for field in [
        "bp_systolic", "bp_diastolic", "ldl", "hba1c",
        "vision", "hearing", "weight", "waist", "resting_hr", "note",
    ]:
        if field in data:
            setattr(bio, field, data[field])
    db.session.commit()
    return bio.to_dict()


def list_plans(profile_id, period=None, limit=5):
    q = HealthPlan.query.filter_by(profile_id=profile_id)
    if period:
        q = q.filter_by(period=period)
    plans = q.order_by(HealthPlan.generated_at.desc()).limit(limit).all()
    return [p.to_dict() for p in plans]
