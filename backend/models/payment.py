"""
支付相关数据库模型
"""
from datetime import datetime
from extensions import db


class PaymentOrder(db.Model):
    """支付订单表"""
    __tablename__ = 'payment_orders'
    
    id = db.Column(db.Integer, primary_key=True)
    
    # 订单信息
    order_no = db.Column(db.String(64), unique=True, nullable=False, index=True, comment='订单号')
    trade_no = db.Column(db.String(128), unique=True, index=True, comment='第三方交易号')
    
    # 用户信息
    user_id = db.Column(db.String(32), db.ForeignKey('users.id'), nullable=False, index=True)
    
    # 支付信息
    payment_method = db.Column(db.String(20), nullable=False, comment='支付方式: wechat/alipay')
    payment_scene = db.Column(db.String(50), nullable=False, comment='支付场景')
    
    # 商品信息
    product_name = db.Column(db.String(200), nullable=False, comment='商品名称')
    product_desc = db.Column(db.String(500), comment='商品描述')
    
    # 金额信息（单位：分）
    total_amount = db.Column(db.Integer, nullable=False, comment='订单总金额')
    paid_amount = db.Column(db.Integer, default=0, comment='实际支付金额')
    
    # 状态信息
    status = db.Column(db.Integer, default=0, comment='订单状态: 0待支付 1已支付 2已取消 3退款中 4已退款 5失败')
    
    # 时间信息
    created_at = db.Column(db.DateTime, default=datetime.utcnow, comment='创建时间')
    paid_at = db.Column(db.DateTime, comment='支付时间')
    expired_at = db.Column(db.DateTime, comment='过期时间')
    cancelled_at = db.Column(db.DateTime, comment='取消时间')
    
    # 扩展信息
    client_ip = db.Column(db.String(50), comment='客户端IP')
    extra_data = db.Column(db.Text, comment='扩展数据（JSON）')
    callback_data = db.Column(db.Text, comment='回调数据（JSON）')
    
    # 关联关系
    user = db.relationship('User', backref=db.backref('payment_orders', lazy='dynamic'))
    
    def to_dict(self):
        """转换为字典"""
        return {
            'id': self.id,
            'order_no': self.order_no,
            'trade_no': self.trade_no,
            'user_id': self.user_id,
            'payment_method': self.payment_method,
            'payment_scene': self.payment_scene,
            'product_name': self.product_name,
            'product_desc': self.product_desc,
            'total_amount': self.total_amount,
            'paid_amount': self.paid_amount,
            'status': self.status,
            'status_name': self.get_status_name(),
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'paid_at': self.paid_at.isoformat() if self.paid_at else None,
            'expired_at': self.expired_at.isoformat() if self.expired_at else None,
        }
    
    def get_status_name(self):
        """获取状态名称"""
        status_map = {
            0: '待支付',
            1: '已支付',
            2: '已取消',
            3: '退款中',
            4: '已退款',
            5: '支付失败'
        }
        return status_map.get(self.status, '未知')
    
    def __repr__(self):
        return f'<PaymentOrder {self.order_no}>'


class PaymentLog(db.Model):
    """支付日志表"""
    __tablename__ = 'payment_logs'
    
    id = db.Column(db.Integer, primary_key=True)
    
    # 订单信息
    order_no = db.Column(db.String(64), nullable=False, index=True)
    
    # 日志信息
    action = db.Column(db.String(50), nullable=False, comment='操作类型')
    message = db.Column(db.Text, comment='日志消息')
    request_data = db.Column(db.Text, comment='请求数据')
    response_data = db.Column(db.Text, comment='响应数据')
    
    # 时间
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    def __repr__(self):
        return f'<PaymentLog {self.order_no} - {self.action}>'


class VIPMembership(db.Model):
    """VIP会员表"""
    __tablename__ = 'vip_memberships'
    
    id = db.Column(db.Integer, primary_key=True)
    
    # 用户信息
    user_id = db.Column(db.String(32), db.ForeignKey('users.id'), nullable=False, unique=True)
    
    # 会员信息
    vip_type = db.Column(db.String(20), comment='会员类型: month/season/year')
    is_active = db.Column(db.Boolean, default=False, comment='是否激活')
    
    # 时间信息
    start_date = db.Column(db.DateTime, comment='开始时间')
    end_date = db.Column(db.DateTime, comment='结束时间')
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # 关联关系
    user = db.relationship('User', backref=db.backref('vip_membership', uselist=False))
    
    def is_valid(self):
        """检查会员是否有效"""
        if not self.is_active:
            return False
        if self.end_date and datetime.utcnow() > self.end_date:
            return False
        return True
    
    def to_dict(self):
        """转换为字典"""
        return {
            'id': self.id,
            'user_id': self.user_id,
            'vip_type': self.vip_type,
            'is_active': self.is_active,
            'is_valid': self.is_valid(),
            'start_date': self.start_date.isoformat() if self.start_date else None,
            'end_date': self.end_date.isoformat() if self.end_date else None,
        }
    
    def __repr__(self):
        return f'<VIPMembership user_id={self.user_id}>'


class UserCoins(db.Model):
    """用户金币表"""
    __tablename__ = 'user_coins'
    
    id = db.Column(db.Integer, primary_key=True)
    
    # 用户信息
    user_id = db.Column(db.String(32), db.ForeignKey('users.id'), nullable=False, unique=True)
    
    # 金币信息
    total_coins = db.Column(db.Integer, default=0, comment='总金币数')
    used_coins = db.Column(db.Integer, default=0, comment='已使用金币')
    available_coins = db.Column(db.Integer, default=0, comment='可用金币')
    
    # 时间
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # 关联关系
    user = db.relationship('User', backref=db.backref('coins', uselist=False))
    
    def to_dict(self):
        """转换为字典"""
        return {
            'user_id': self.user_id,
            'total_coins': self.total_coins,
            'used_coins': self.used_coins,
            'available_coins': self.available_coins,
        }
    
    def __repr__(self):
        return f'<UserCoins user_id={self.user_id} available={self.available_coins}>'
