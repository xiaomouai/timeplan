"""
签到相关数据库模型
"""
from datetime import datetime
from extensions import db

class CheckinRecord(db.Model):
    """签到记录表"""
    __tablename__ = 'checkin_records'
    
    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    user_id = db.Column(db.String(32), db.ForeignKey('users.id'), nullable=False, index=True)
    checkin_date = db.Column(db.Date, nullable=False)
    consecutive_day = db.Column(db.Integer, nullable=False, default=1)
    base_points = db.Column(db.Integer, nullable=False, default=0)
    bonus_points = db.Column(db.Integer, nullable=False, default=0)
    total_points = db.Column(db.Integer, nullable=False, default=0)
    checkin_time = db.Column(db.DateTime, default=datetime.utcnow)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    __table_args__ = (
        db.UniqueConstraint('user_id', 'checkin_date', name='uk_user_date'),
    )
    
    def to_dict(self):
        return {
            'id': self.id,
            'user_id': self.user_id,
            'checkin_date': self.checkin_date.isoformat(),
            'consecutive_day': self.consecutive_day,
            'base_points': self.base_points,
            'bonus_points': self.bonus_points,
            'total_points': self.total_points,
            'checkin_time': self.checkin_time.isoformat(),
            'created_at': self.created_at.isoformat()
        }

class LevelConfig(db.Model):
    """等级配置表"""
    __tablename__ = 'level_config'
    
    level = db.Column(db.Integer, primary_key=True)
    level_name = db.Column(db.String(32), nullable=False)
    min_points = db.Column(db.Integer, nullable=False)
    icon = db.Column(db.String(32))
    color = db.Column(db.String(16))
    daily_base_points = db.Column(db.Integer, nullable=False, default=10)
    description = db.Column(db.String(128))
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    def to_dict(self):
        return {
            'level': self.level,
            'level_name': self.level_name,
            'min_points': self.min_points,
            'icon': self.icon,
            'color': self.color,
            'daily_base_points': self.daily_base_points,
            'description': self.description
        }

class ConsecutiveRewardConfig(db.Model):
    """连续签到奖励配置表"""
    __tablename__ = 'consecutive_reward_config'
    
    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    consecutive_days = db.Column(db.Integer, nullable=False, unique=True)
    reward_type = db.Column(db.String(32), nullable=False)  # points/badge/coupon/item
    reward_value = db.Column(db.Integer, nullable=False, default=0)
    reward_name = db.Column(db.String(64), nullable=False)
    reward_icon = db.Column(db.String(32))
    description = db.Column(db.String(128))
    is_repeatable = db.Column(db.Boolean, nullable=False, default=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    def to_dict(self):
        return {
            'id': self.id,
            'consecutive_days': self.consecutive_days,
            'reward_type': self.reward_type,
            'reward_value': self.reward_value,
            'reward_name': self.reward_name,
            'reward_icon': self.reward_icon,
            'description': self.description,
            'is_repeatable': self.is_repeatable
        }

class PointsLog(db.Model):
    """积分流水表"""
    __tablename__ = 'points_log'
    
    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    user_id = db.Column(db.String(32), db.ForeignKey('users.id'), nullable=False, index=True)
    change_type = db.Column(db.String(32), nullable=False)  # checkin/bonus/consume/reward/admin
    change_points = db.Column(db.Integer, nullable=False)
    before_points = db.Column(db.Integer, nullable=False)
    after_points = db.Column(db.Integer, nullable=False)
    description = db.Column(db.String(128))
    ref_id = db.Column(db.Integer)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    def to_dict(self):
        return {
            'id': self.id,
            'user_id': self.user_id,
            'change_type': self.change_type,
            'change_points': self.change_points,
            'before_points': self.before_points,
            'after_points': self.after_points,
            'description': self.description,
            'ref_id': self.ref_id,
            'created_at': self.created_at.isoformat()
        }

class UserReward(db.Model):
    """用户获得的奖励记录"""
    __tablename__ = 'user_rewards'
    
    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    user_id = db.Column(db.String(32), db.ForeignKey('users.id'), nullable=False, index=True)
    reward_config_id = db.Column(db.Integer, nullable=False)
    consecutive_days = db.Column(db.Integer, nullable=False)
    reward_type = db.Column(db.String(32), nullable=False)
    reward_value = db.Column(db.Integer, nullable=False, default=0)
    reward_name = db.Column(db.String(64), nullable=False)
    claimed_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    def to_dict(self):
        return {
            'id': self.id,
            'user_id': self.user_id,
            'reward_config_id': self.reward_config_id,
            'consecutive_days': self.consecutive_days,
            'reward_type': self.reward_type,
            'reward_value': self.reward_value,
            'reward_name': self.reward_name,
            'claimed_at': self.claimed_at.isoformat()
        }
