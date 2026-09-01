"""
会员和订单相关数据库模型
"""
from datetime import datetime
from extensions import db


class Membership(db.Model):
    """会员表（旧表，保留兼容）"""
    __tablename__ = 'memberships'
    
    id = db.Column(db.String(32), primary_key=True)
    user_id = db.Column(db.String(32), nullable=False, index=True)
    plan_id = db.Column(db.String(32), nullable=False)
    level = db.Column(db.Enum('free', 'basic', 'ai', 'vip'), nullable=False)
    start_at = db.Column(db.DateTime, nullable=False)
    expire_at = db.Column(db.DateTime, nullable=False, index=True)
    status = db.Column(db.Enum('active', 'expired', 'cancelled'), default='active')
    created_at = db.Column(db.DateTime, default=datetime.utcnow)


class Order(db.Model):
    """订单表（旧表，保留兼容）"""
    __tablename__ = 'orders'
    
    id = db.Column(db.String(32), primary_key=True)
    user_id = db.Column(db.String(32), nullable=False, index=True)
    plan_id = db.Column(db.String(32), nullable=False)
    original_price = db.Column(db.Numeric(10, 2), nullable=False)
    discount = db.Column(db.Numeric(10, 2), default=0)
    final_price = db.Column(db.Numeric(10, 2), nullable=False)
    promo_code = db.Column(db.String(20))
    payment_method = db.Column(db.String(20))  # wechat/alipay
    payment_no = db.Column(db.String(64), index=True)  # 第三方支付订单号
    status = db.Column(db.Enum('pending', 'paid', 'expired', 'refunded'), default='pending', index=True)
    paid_at = db.Column(db.DateTime)
    expire_at = db.Column(db.DateTime, nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)


class MembershipPlan(db.Model):
    """会员套餐表"""
    __tablename__ = 'membership_plans'
    
    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    name = db.Column(db.String(50), nullable=False)
    plan_type = db.Column(db.String(20), nullable=False)  # month/season/year/lifetime
    duration_days = db.Column(db.Integer, default=0)  # 时长(天)，0表示永久
    price = db.Column(db.Numeric(10, 2), nullable=False)
    original_price = db.Column(db.Numeric(10, 2))
    description = db.Column(db.String(500))
    features = db.Column(db.Text)  # 特权列表，逗号分隔
    is_recommended = db.Column(db.Boolean, default=False)
    discount_label = db.Column(db.String(50))  # 折扣标签
    sort_order = db.Column(db.Integer, default=0)
    is_active = db.Column(db.Boolean, default=True)
    created_at = db.Column(db.DateTime, default=datetime.now)
    updated_at = db.Column(db.DateTime, default=datetime.now, onupdate=datetime.now)


class UserMembership(db.Model):
    """用户会员表"""
    __tablename__ = 'user_memberships'
    
    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    user_id = db.Column(db.String(32), db.ForeignKey('users.id'), nullable=False, unique=True, index=True)
    membership_type = db.Column(db.String(20), default='free')  # free/month/season/year/lifetime
    expire_time = db.Column(db.DateTime)  # 过期时间，NULL表示永久
    status = db.Column(db.String(20), default='active')  # active/expired/cancelled
    created_at = db.Column(db.DateTime, default=datetime.now)
    updated_at = db.Column(db.DateTime, default=datetime.now, onupdate=datetime.now)


class MembershipOrder(db.Model):
    """会员订单表"""
    __tablename__ = 'membership_orders'
    
    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    order_no = db.Column(db.String(64), unique=True, nullable=False, index=True)
    user_id = db.Column(db.String(32), db.ForeignKey('users.id'), nullable=False, index=True)
    plan_id = db.Column(db.Integer, db.ForeignKey('membership_plans.id'), nullable=False)
    original_price = db.Column(db.Numeric(10, 2), nullable=False)
    actual_price = db.Column(db.Numeric(10, 2), nullable=False)
    payment_method = db.Column(db.String(20), default='alipay')  # alipay/wechat
    payment_no = db.Column(db.String(64), index=True)  # 第三方支付订单号
    status = db.Column(db.String(20), default='pending', index=True)  # pending/paid/cancelled/refunded
    paid_time = db.Column(db.DateTime)
    created_at = db.Column(db.DateTime, default=datetime.now)
    updated_at = db.Column(db.DateTime, default=datetime.now, onupdate=datetime.now)


class MembershipBenefit(db.Model):
    """会员权益表"""
    __tablename__ = 'membership_benefits'
    
    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    name = db.Column(db.String(50), nullable=False)
    description = db.Column(db.String(500))
    benefit_type = db.Column(db.String(50), nullable=False)  # unlimited_dictation/ai_tutor/no_ads等
    benefit_value = db.Column(db.String(100))  # 权益值
    membership_type = db.Column(db.String(20), nullable=False)  # 适用会员类型
    icon = db.Column(db.String(50))
    is_active = db.Column(db.Boolean, default=True)
    sort_order = db.Column(db.Integer, default=0)
    created_at = db.Column(db.DateTime, default=datetime.now)


class UserMembershipBenefit(db.Model):
    """用户会员权益关联表"""
    __tablename__ = 'user_membership_benefits'
    
    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    user_id = db.Column(db.String(32), db.ForeignKey('users.id'), nullable=False, index=True)
    benefit_id = db.Column(db.Integer, db.ForeignKey('membership_benefits.id'), nullable=False)
    is_active = db.Column(db.Boolean, default=True)
    created_at = db.Column(db.DateTime, default=datetime.now)
    updated_at = db.Column(db.DateTime, default=datetime.now, onupdate=datetime.now)
    
    __table_args__ = (
        db.Index('idx_user_benefit', 'user_id', 'benefit_id'),
    )


class ActivationCode(db.Model):
    """激活码表"""
    __tablename__ = 'activation_codes'

    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    code = db.Column(db.String(32), unique=True, nullable=False, index=True)
    order_id = db.Column(db.String(64))
    plan_type = db.Column(db.String(32), nullable=False)  # trial/month/season/year/lifetime
    duration_days = db.Column(db.Integer, nullable=False, default=30)
    status = db.Column(db.SmallInteger, nullable=False, default=0)  # 0-未使用 1-已激活 2-已过期 3-已作废
    max_devices = db.Column(db.Integer, nullable=False, default=1)
    created_at = db.Column(db.DateTime, default=datetime.now)
    expired_at = db.Column(db.DateTime)  # 激活码本身的过期时间
    activated_at = db.Column(db.DateTime)
    activated_by = db.Column(db.String(32), db.ForeignKey('users.id'))
    activated_device_id = db.Column(db.String(128))


class ActivationLog(db.Model):
    """激活日志表"""
    __tablename__ = 'activation_logs'

    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    activation_code = db.Column(db.String(32), nullable=False, index=True)
    user_id = db.Column(db.String(32))
    device_id = db.Column(db.String(128))
    ip_address = db.Column(db.String(45))
    result = db.Column(db.SmallInteger, nullable=False)  # 1-成功 0-失败
    failure_reason = db.Column(db.Text)
    created_at = db.Column(db.DateTime, default=datetime.now)
