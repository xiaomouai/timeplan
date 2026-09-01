"""
用户反馈数据模型
"""
from extensions import db
from datetime import datetime

class Feedback(db.Model):
    __tablename__ = 'feedback'
    
    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    user_id = db.Column(db.String(32), db.ForeignKey('users.id'), nullable=True) # 可以是匿名反馈
    content = db.Column(db.Text, nullable=False)
    contact = db.Column(db.String(100), nullable=True) # 手机或邮箱
    feedback_type = db.Column(db.String(50), nullable=True, default='general', index=True) # bug, suggestion, general
    status = db.Column(db.String(20), nullable=False, default='new', index=True) # new, seen, archived
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    user = db.relationship('User', backref=db.backref('feedbacks', lazy='dynamic'))

    def to_dict(self):
        return {
            'id': self.id,
            'user_id': self.user_id,
            'content': self.content,
            'contact': self.contact,
            'feedback_type': self.feedback_type,
            'status': self.status,
            'created_at': self.created_at.isoformat(),
            'updated_at': self.updated_at.isoformat()
        }
