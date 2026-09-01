"""
教材和单元相关数据库模型
"""
from datetime import datetime
from extensions import db


class Textbook(db.Model):
    """教材表"""
    __tablename__ = 'textbooks'
    
    id = db.Column(db.String(32), primary_key=True)
    name = db.Column(db.String(50), nullable=False)
    publisher = db.Column(db.String(50))
    icon = db.Column(db.String(255))
    grades = db.Column(db.JSON)  # 支持的年级列表
    status = db.Column(db.Enum('active', 'disabled'), default='active')
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    # 关系
    units = db.relationship('Unit', backref='textbook', lazy='dynamic')


class Unit(db.Model):
    """单元表"""
    __tablename__ = 'units'
    
    id = db.Column(db.String(32), primary_key=True)
    textbook_id = db.Column(db.String(32), db.ForeignKey('textbooks.id'), nullable=False)
    grade = db.Column(db.SmallInteger, nullable=False)
    term = db.Column(db.SmallInteger, nullable=False)
    unit_number = db.Column(db.SmallInteger, nullable=False)
    name = db.Column(db.String(100), nullable=False)
    word_count = db.Column(db.Integer, default=0)
    sort_order = db.Column(db.Integer)
    status = db.Column(db.Enum('active', 'disabled'), default='active')
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    __table_args__ = (
        db.Index('idx_textbook_grade', 'textbook_id', 'grade', 'term'),
    )
