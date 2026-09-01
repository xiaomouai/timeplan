"""
学习记录相关数据库模型
"""
from datetime import datetime
from extensions import db


class StudyLog(db.Model):
    """学习记录表"""
    __tablename__ = 'study_logs'
    
    id = db.Column(db.String(32), primary_key=True)
    user_id = db.Column(db.String(32), db.ForeignKey('users.id'), nullable=False, index=True)
    date = db.Column(db.Date, nullable=False)
    module = db.Column(db.String(20), nullable=False)  # word_learning/dictation/challenge等
    duration = db.Column(db.Integer, default=0)  # 学习时长(秒)
    words_count = db.Column(db.Integer, default=0)
    correct_count = db.Column(db.Integer, default=0)
    points_earned = db.Column(db.Integer, default=0)
    exp_earned = db.Column(db.Integer, default=0)
    details = db.Column(db.JSON)  # 详细数据
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    __table_args__ = (
        db.Index('idx_user_date', 'user_id', 'date'),
        db.Index('idx_date_module', 'date', 'module'),
    )


class WrongRecord(db.Model):
    """错题记录表"""
    __tablename__ = 'wrong_records'
    
    id = db.Column(db.String(32), primary_key=True)
    user_id = db.Column(db.String(32), db.ForeignKey('users.id'), nullable=False, index=True)
    word_id = db.Column(db.String(32), nullable=False, index=True)
    question_type = db.Column(db.String(20), nullable=False)  # choice/spell/listen等
    user_answer = db.Column(db.Text)
    correct_answer = db.Column(db.Text)
    error_type = db.Column(db.String(20))  # spelling/meaning/pronunciation
    is_mastered = db.Column(db.Boolean, default=False)
    mastered_at = db.Column(db.DateTime)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    __table_args__ = (
        db.Index('idx_user_word', 'user_id', 'word_id'),
        db.Index('idx_user_type', 'user_id', 'error_type'),
    )


class PronunciationRecord(db.Model):
    """发音评测记录表"""
    __tablename__ = 'pronunciation_records'
    
    id = db.Column(db.String(32), primary_key=True)
    user_id = db.Column(db.String(32), db.ForeignKey('users.id'), nullable=False, index=True)
    word_id = db.Column(db.String(32))
    text = db.Column(db.String(500), nullable=False)
    audio_url = db.Column(db.String(255), nullable=False)
    overall_score = db.Column(db.Integer)
    accuracy_score = db.Column(db.Integer)
    fluency_score = db.Column(db.Integer)
    pronunciation_score = db.Column(db.Integer)
    phoneme_details = db.Column(db.JSON)  # 音素详情
    evaluation_result = db.Column(db.JSON)  # 完整评测结果
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    __table_args__ = (
        db.Index('idx_user_created', 'user_id', 'created_at'),
    )


class Challenge(db.Model):
    """闯关表"""
    __tablename__ = 'challenges'
    
    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    user_id = db.Column(db.String(32), db.ForeignKey('users.id'), nullable=False, index=True)
    word_book_id = db.Column(db.String(50), nullable=False, index=True)
    difficulty = db.Column(db.String(20), nullable=False, default='easy')  # easy/medium/hard
    total_questions = db.Column(db.Integer, default=0)
    answered_questions = db.Column(db.Integer, default=0)
    correct_answers = db.Column(db.Integer, default=0)
    score = db.Column(db.Integer, default=0)
    status = db.Column(db.String(20), default='in_progress')  # in_progress/completed
    created_at = db.Column(db.DateTime, default=datetime.now)
    updated_at = db.Column(db.DateTime, default=datetime.now, onupdate=datetime.now)
    completed_at = db.Column(db.DateTime)
    
    __table_args__ = (
        db.Index('idx_user_status', 'user_id', 'status'),
    )


class ChallengeRecord(db.Model):
    """闯关记录表"""
    __tablename__ = 'challenge_records'
    
    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    user_id = db.Column(db.String(32), db.ForeignKey('users.id'), nullable=False, index=True)
    challenge_id = db.Column(db.Integer, db.ForeignKey('challenges.id'), nullable=False)
    word_book_id = db.Column(db.String(50), nullable=False, index=True)
    difficulty = db.Column(db.String(20), nullable=False)
    score = db.Column(db.Integer, default=0)
    total_questions = db.Column(db.Integer, default=0)
    correct_answers = db.Column(db.Integer, default=0)
    time_spent = db.Column(db.Integer, default=0)  # 耗时(秒)
    is_passed = db.Column(db.Boolean, default=False)
    created_at = db.Column(db.DateTime, default=datetime.now)
    
    __table_args__ = (
        db.Index('idx_user_created', 'user_id', 'created_at'),
    )


class ChallengeAnswer(db.Model):
    """闯关答题表"""
    __tablename__ = 'challenge_answers'
    
    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    challenge_id = db.Column(db.Integer, db.ForeignKey('challenges.id'), nullable=False, index=True)
    word_id = db.Column(db.BigInteger, nullable=False)
    user_answer = db.Column(db.String(255))
    is_correct = db.Column(db.Boolean, default=False)
    time_spent = db.Column(db.Integer, default=0)  # 答题耗时(秒)
    created_at = db.Column(db.DateTime, default=datetime.now)


class Dictation(db.Model):
    """听写表"""
    __tablename__ = 'dictations'
    
    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    user_id = db.Column(db.String(32), db.ForeignKey('users.id'), nullable=False, index=True)
    word_book_id = db.Column(db.String(50), nullable=False, index=True)
    mode = db.Column(db.String(20), nullable=False, default='sequential')  # sequential/random/wrong_words
    total_words = db.Column(db.Integer, default=0)
    completed_words = db.Column(db.Integer, default=0)
    correct_words = db.Column(db.Integer, default=0)
    accuracy = db.Column(db.Numeric(5, 2), default=0)  # 正确率
    status = db.Column(db.String(20), default='in_progress')  # in_progress/completed
    created_at = db.Column(db.DateTime, default=datetime.now)
    updated_at = db.Column(db.DateTime, default=datetime.now, onupdate=datetime.now)
    completed_at = db.Column(db.DateTime)
    
    __table_args__ = (
        db.Index('idx_user_status', 'user_id', 'status'),
    )


class DictationRecord(db.Model):
    """听写记录表"""
    __tablename__ = 'dictation_records'
    
    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    user_id = db.Column(db.String(32), db.ForeignKey('users.id'), nullable=False, index=True)
    dictation_id = db.Column(db.Integer, db.ForeignKey('dictations.id'), nullable=False)
    word_book_id = db.Column(db.String(50), nullable=False, index=True)
    mode = db.Column(db.String(20), nullable=False)
    total_words = db.Column(db.Integer, default=0)
    correct_words = db.Column(db.Integer, default=0)
    accuracy = db.Column(db.Numeric(5, 2), default=0)
    time_spent = db.Column(db.Integer, default=0)  # 耗时(秒)
    created_at = db.Column(db.DateTime, default=datetime.now)
    
    __table_args__ = (
        db.Index('idx_user_created', 'user_id', 'created_at'),
    )


class DictationAnswer(db.Model):
    """听写答题表"""
    __tablename__ = 'dictation_answers'
    
    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    dictation_id = db.Column(db.Integer, db.ForeignKey('dictations.id'), nullable=False, index=True)
    word_id = db.Column(db.BigInteger, nullable=False)
    user_answer = db.Column(db.String(255))
    correct_answer = db.Column(db.String(255))
    is_correct = db.Column(db.Boolean, default=False)
    created_at = db.Column(db.DateTime, default=datetime.now)
