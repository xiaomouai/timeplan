"""
用户相关数据库模型
"""
from datetime import datetime
from extensions import db


class User(db.Model):
    """用户表"""
    __tablename__ = 'users'
    
    id = db.Column(db.String(32), primary_key=True)
    phone = db.Column(db.String(20), unique=True, nullable=False, index=True)
    password_hash = db.Column(db.String(128))
    nickname = db.Column(db.String(50))
    avatar = db.Column(db.String(255))
    gender = db.Column(db.Enum('male', 'female', 'unknown'), default='unknown')
    birthday = db.Column(db.Date)
    role = db.Column(db.Enum('student', 'parent', 'admin'), nullable=False)
    grade = db.Column(db.SmallInteger)
    level = db.Column(db.Integer, default=1)
    exp = db.Column(db.Integer, default=0)
    points = db.Column(db.Integer, default=0)
    streak_days = db.Column(db.Integer, default=0)
    total_checkin_days = db.Column(db.Integer, default=0)
    max_streak_days = db.Column(db.Integer, default=0)
    last_checkin_date = db.Column(db.Date)
    invite_code = db.Column(db.String(10), unique=True, index=True)
    invited_by = db.Column(db.String(32))
    status = db.Column(db.Enum('active', 'disabled'), default='active')
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # 关系
    user_words = db.relationship('UserWord', backref='user', lazy='dynamic')
    achievements = db.relationship('UserAchievement', backref='user', lazy='dynamic')
    study_logs = db.relationship('StudyLog', backref='user', lazy='dynamic')
    wrong_records = db.relationship('WrongRecord', backref='user', lazy='dynamic')
    
    def to_dict(self):
        """转换为字典"""
        return {
            'id': self.id,
            'phone': self.phone,
            'nickname': self.nickname,
            'avatar': self.avatar,
            'gender': self.gender,
            'birthday': self.birthday.isoformat() if self.birthday else None,
            'role': self.role,
            'grade': self.grade,
            'level': self.level,
            'exp': self.exp,
            'points': self.points,
            'streak_days': self.streak_days,
            'invite_code': self.invite_code,
            'status': self.status,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None
        }


class UserWord(db.Model):
    """用户单词学习记录表"""
    __tablename__ = 'user_words'
    
    id = db.Column(db.String(32), primary_key=True)
    user_id = db.Column(db.String(32), db.ForeignKey('users.id'), nullable=False, index=True)
    word_id = db.Column(db.String(32), nullable=False, index=True)
    mastery_level = db.Column(db.SmallInteger, default=0)  # 掌握程度 0-5
    learn_count = db.Column(db.Integer, default=0)
    correct_count = db.Column(db.Integer, default=0)
    wrong_count = db.Column(db.Integer, default=0)
    last_learn_at = db.Column(db.DateTime, default=datetime.utcnow)
    next_review_at = db.Column(db.DateTime)
    is_favorite = db.Column(db.Boolean, default=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    __table_args__ = (
        db.UniqueConstraint('user_id', 'word_id', name='uk_user_word'),
        db.Index('idx_user_mastery', 'user_id', 'mastery_level'),
        db.Index('idx_next_review', 'user_id', 'next_review_at'),
    )
    
    def to_dict(self):
        """转换为字典"""
        return {
            'id': self.id,
            'user_id': self.user_id,
            'word_id': self.word_id,
            'mastery_level': self.mastery_level,
            'learn_count': self.learn_count,
            'correct_count': self.correct_count,
            'wrong_count': self.wrong_count,
            'last_learn_at': self.last_learn_at.isoformat() if self.last_learn_at else None,
            'next_review_at': self.next_review_at.isoformat() if self.next_review_at else None,
            'is_favorite': self.is_favorite
        }


class UserAchievement(db.Model):
    """用户成就表"""
    __tablename__ = 'user_achievements'
    
    id = db.Column(db.String(32), primary_key=True)
    user_id = db.Column(db.String(32), db.ForeignKey('users.id'), nullable=False, index=True)
    achievement_id = db.Column(db.String(32), nullable=False)
    earned_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    __table_args__ = (
        db.UniqueConstraint('user_id', 'achievement_id', name='uk_user_achievement'),
    )


class ParentChild(db.Model):
    """家长-孩子关联表"""
    __tablename__ = 'parent_child'
    
    id = db.Column(db.String(32), primary_key=True)
    parent_id = db.Column(db.String(32), nullable=False, index=True)
    child_id = db.Column(db.String(32), nullable=False, index=True)
    relationship = db.Column(db.String(20))  # mother/father/grandparent/other
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    __table_args__ = (
        db.UniqueConstraint('parent_id', 'child_id', name='uk_parent_child'),
    )



