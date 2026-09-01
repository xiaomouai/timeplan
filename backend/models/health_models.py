"""
健康计划数据模型

设计立场：健康不是工作的对立面，是认知产能的维护成本。
本模块承载「柳叶刀 12 条证据化」的动态数据源 —— 习惯定义、阈值、证据出处
全部存库，由后端 API 下发，不再硬编码在客户端；AI 生成计划也落库可追溯。
"""
from datetime import datetime, date
from extensions import db
import uuid


class HealthProfile(db.Model):
    """健康档案：每个客户端（设备）一个，作为所有健康数据的归属。"""
    __tablename__ = "health_profiles"

    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    client_id = db.Column(db.String(64), unique=True, nullable=False, index=True)
    nickname = db.Column(db.String(50))
    current_phase = db.Column(db.Integer, default=0)  # 4 周落地阶段 0..3（与 Flutter 端对齐）
    phase_start_date = db.Column(db.Date, default=date.today)
    onboarding_done = db.Column(db.Boolean, default=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    def to_dict(self):
        return {
            "id": self.id,
            "client_id": self.client_id,
            "nickname": self.nickname,
            "current_phase": self.current_phase,
            "phase_start_date": self.phase_start_date.isoformat() if self.phase_start_date else None,
            "onboarding_done": self.onboarding_done,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }


class HealthHabit(db.Model):
    """健康习惯定义（动态下发，证据化）。12 条 + 1 条执行项。"""
    __tablename__ = "health_habits"

    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    key = db.Column(db.String(32), unique=True, nullable=False, index=True)
    title = db.Column(db.String(64), nullable=False)
    grade = db.Column(db.String(8), nullable=False)  # A / B / C / routine
    category = db.Column(db.String(32))  # sleep/move/eat/avoid/monitor/cognitive/social/focus
    description = db.Column(db.Text)
    unit = db.Column(db.String(16))  # hours/min/kg/score/g/boolean/...
    min_value = db.Column(db.Float)
    max_value = db.Column(db.Float)
    target_value = db.Column(db.Float)
    step = db.Column(db.Float, default=1)
    frequency = db.Column(db.String(16), default="daily")  # daily/weekly/quarterly
    source = db.Column(db.Text)  # 证据出处
    phase = db.Column(db.Integer, default=1)  # 第几阶段解锁
    active = db.Column(db.Boolean, default=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    def to_dict(self):
        return {
            "id": self.id,
            "key": self.key,
            "title": self.title,
            "grade": self.grade,
            "category": self.category,
            "description": self.description,
            "unit": self.unit,
            "min_value": self.min_value,
            "max_value": self.max_value,
            "target_value": self.target_value,
            "step": self.step,
            "frequency": self.frequency,
            "source": self.source,
            "phase": self.phase,
            "active": self.active,
        }


class HealthCheckin(db.Model):
    """每日/每周健康打卡记录。"""
    __tablename__ = "health_checkins"

    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    profile_id = db.Column(db.String(36), db.ForeignKey("health_profiles.id"), nullable=False, index=True)
    habit_key = db.Column(db.String(32), nullable=False, index=True)
    log_date = db.Column(db.Date, nullable=False)
    value = db.Column(db.Float)  # 数值；布尔类用 0/1
    done = db.Column(db.Boolean, default=False)
    note = db.Column(db.String(255))
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    __table_args__ = (
        db.UniqueConstraint("profile_id", "habit_key", "log_date", name="uk_profile_habit_date"),
    )

    def to_dict(self):
        return {
            "id": self.id,
            "profile_id": self.profile_id,
            "habit_key": self.habit_key,
            "log_date": self.log_date.isoformat() if self.log_date else None,
            "value": self.value,
            "done": self.done,
            "note": self.note,
        }


class HealthBiometric(db.Model):
    """季度体检兜底数据：血压/LDL/HbA1c/视力/听力/体重腰围静息心率。"""
    __tablename__ = "health_biometrics"

    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    profile_id = db.Column(db.String(36), db.ForeignKey("health_profiles.id"), nullable=False, index=True)
    record_date = db.Column(db.Date, nullable=False)
    bp_systolic = db.Column(db.Float)
    bp_diastolic = db.Column(db.Float)
    ldl = db.Column(db.Float)
    hba1c = db.Column(db.Float)
    vision = db.Column(db.Float)
    hearing = db.Column(db.Float)
    weight = db.Column(db.Float)
    waist = db.Column(db.Float)
    resting_hr = db.Column(db.Integer)
    note = db.Column(db.String(255))
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    def to_dict(self):
        return {
            "id": self.id,
            "profile_id": self.profile_id,
            "record_date": self.record_date.isoformat() if self.record_date else None,
            "bp_systolic": self.bp_systolic,
            "bp_diastolic": self.bp_diastolic,
            "ldl": self.ldl,
            "hba1c": self.hba1c,
            "vision": self.vision,
            "hearing": self.hearing,
            "weight": self.weight,
            "waist": self.waist,
            "resting_hr": self.resting_hr,
            "note": self.note,
        }


class HealthPlan(db.Model):
    """AI 动态生成的个性化计划（日/周/季），落库可追溯。"""
    __tablename__ = "health_plans"

    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    profile_id = db.Column(db.String(36), db.ForeignKey("health_profiles.id"), nullable=False, index=True)
    period = db.Column(db.String(16), nullable=False)  # daily / weekly / quarterly
    generated_at = db.Column(db.DateTime, default=datetime.utcnow)
    model = db.Column(db.String(32))
    provider = db.Column(db.String(32))
    content = db.Column(db.Text)  # JSON 字符串
    summary = db.Column(db.Text)  # 人类可读摘要
    based_on = db.Column(db.Text)  # 输入摘要（可追溯）

    def to_dict(self):
        return {
            "id": self.id,
            "profile_id": self.profile_id,
            "period": self.period,
            "generated_at": self.generated_at.isoformat() if self.generated_at else None,
            "model": self.model,
            "provider": self.provider,
            "content": self.content,
            "summary": self.summary,
            "based_on": self.based_on,
        }
