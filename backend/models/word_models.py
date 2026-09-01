"""
单词相关数据库模型
"""
from datetime import datetime
from extensions import db


class WordBook(db.Model):
    """词书表"""
    __tablename__ = 'word_books'
    
    id = db.Column(db.String(50), primary_key=True, comment='词书ID')
    title = db.Column(db.String(200), nullable=False, comment='词书标题')
    cover = db.Column(db.String(500), comment='封面图片URL')
    word_num = db.Column(db.Integer, default=0, comment='单词数量')
    recite_user_num = db.Column(db.Integer, default=0, comment='背诵人数')
    size = db.Column(db.Integer, default=0, comment='文件大小')
    introduce = db.Column(db.Text, comment='简介')
    origin_name = db.Column(db.String(100), comment='来源名称')
    version = db.Column(db.String(20), comment='版本号')
    tags = db.Column(db.String(200), comment='标签（逗号分隔）')
    offline_data = db.Column(db.String(500), comment='离线数据URL')
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # 关系
    words = db.relationship('Word', backref='book', lazy='dynamic', cascade='all, delete-orphan')
    
    def to_dict(self):
        """转换为字典"""
        return {
            'id': self.id,
            'title': self.title,
            'cover': self.cover,
            'word_num': self.word_num,
            'recite_user_num': self.recite_user_num,
            'size': self.size,
            'introduce': self.introduce,
            'origin_name': self.origin_name,
            'version': self.version,
            'tags': self.tags.split(',') if self.tags else [],
            'offline_data': self.offline_data,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None
        }


class Word(db.Model):
    """单词表"""
    __tablename__ = 'words'
    
    id = db.Column(db.BigInteger, primary_key=True, autoincrement=True)
    book_id = db.Column(db.String(50), db.ForeignKey('word_books.id'), nullable=False, index=True, comment='词书ID')
    word_id = db.Column(db.String(100), unique=True, nullable=False, index=True, comment='单词唯一ID')
    word_rank = db.Column(db.Integer, nullable=False, comment='单词序号')
    head_word = db.Column(db.String(100), nullable=False, index=True, comment='单词')
    us_phone = db.Column(db.String(100), comment='美式音标')
    uk_phone = db.Column(db.String(100), comment='英式音标')
    us_speech = db.Column(db.String(200), comment='美式发音参数')
    uk_speech = db.Column(db.String(200), comment='英式发音参数')
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # 关系
    translations = db.relationship('WordTranslation', backref='word', lazy='dynamic', cascade='all, delete-orphan')
    sentences = db.relationship('WordSentence', backref='word', lazy='dynamic', cascade='all, delete-orphan')
    phrases = db.relationship('WordPhrase', backref='word', lazy='dynamic', cascade='all, delete-orphan')
    synonyms = db.relationship('WordSynonym', backref='word', lazy='dynamic', cascade='all, delete-orphan')
    related_words = db.relationship('WordRelated', backref='word', lazy='dynamic', cascade='all, delete-orphan')
    
    __table_args__ = (
        db.Index('idx_word_rank', 'book_id', 'word_rank'),
    )
    
    def to_dict(self, include_details=False):
        """转换为字典"""
        data = {
            'id': self.id,
            'book_id': self.book_id,
            'word_id': self.word_id,
            'word_rank': self.word_rank,
            'head_word': self.head_word,
            'us_phone': self.us_phone,
            'uk_phone': self.uk_phone,
            'us_speech': self.us_speech or f"https://dict.youdao.com/dictvoice?audio={self.head_word}&type=2",
            'uk_speech': self.uk_speech or f"https://dict.youdao.com/dictvoice?audio={self.head_word}&type=1",
        }
        
        if include_details:
            data['translations'] = [t.to_dict() for t in self.translations]
            data['sentences'] = [s.to_dict() for s in self.sentences]
            data['phrases'] = [p.to_dict() for p in self.phrases]
            data['synonyms'] = [s.to_dict() for s in self.synonyms]
            data['related_words'] = [r.to_dict() for r in self.related_words]
        
        return data


class WordTranslation(db.Model):
    """单词释义表"""
    __tablename__ = 'word_translations'
    
    id = db.Column(db.BigInteger, primary_key=True, autoincrement=True)
    word_id = db.Column(db.String(100), db.ForeignKey('words.word_id', ondelete='CASCADE'), nullable=False, index=True, comment='单词ID')
    pos = db.Column(db.String(20), comment='词性')
    tran_cn = db.Column(db.Text, comment='中文释义')
    tran_other = db.Column(db.Text, comment='英文释义')
    desc_cn = db.Column(db.String(50), comment='中文说明')
    desc_other = db.Column(db.String(50), comment='其他说明')
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    def to_dict(self):
        """转换为字典"""
        return {
            'pos': self.pos,
            'tranCn': self.tran_cn,
            'tranOther': self.tran_other,
            'descCn': self.desc_cn,
            'descOther': self.desc_other
        }


class WordSentence(db.Model):
    """例句表"""
    __tablename__ = 'word_sentences'
    
    id = db.Column(db.BigInteger, primary_key=True, autoincrement=True)
    word_id = db.Column(db.String(100), db.ForeignKey('words.word_id', ondelete='CASCADE'), nullable=False, index=True, comment='单词ID')
    s_content = db.Column(db.Text, nullable=False, comment='英文例句')
    s_cn = db.Column(db.Text, comment='中文翻译')
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    def to_dict(self):
        """转换为字典"""
        return {
            'sContent': self.s_content,
            'sCn': self.s_cn,
            'sSpeech': f"https://dict.youdao.com/dictvoice?audio={self.s_content}&type=2"
        }


class WordPhrase(db.Model):
    """短语表"""
    __tablename__ = 'word_phrases'
    
    id = db.Column(db.BigInteger, primary_key=True, autoincrement=True)
    word_id = db.Column(db.String(100), db.ForeignKey('words.word_id', ondelete='CASCADE'), nullable=False, index=True, comment='单词ID')
    p_content = db.Column(db.String(200), nullable=False, comment='英文短语')
    p_cn = db.Column(db.Text, comment='中文翻译')
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    def to_dict(self):
        """转换为字典"""
        return {
            'pContent': self.p_content,
            'pCn': self.p_cn
        }


class WordSynonym(db.Model):
    """近义词表"""
    __tablename__ = 'word_synonyms'
    
    id = db.Column(db.BigInteger, primary_key=True, autoincrement=True)
    word_id = db.Column(db.String(100), db.ForeignKey('words.word_id', ondelete='CASCADE'), nullable=False, index=True, comment='单词ID')
    pos = db.Column(db.String(20), comment='词性')
    tran = db.Column(db.String(200), comment='词义')
    synonym = db.Column(db.String(100), nullable=False, comment='近义词')
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    def to_dict(self):
        """转换为字典"""
        return {
            'pos': self.pos,
            'tran': self.tran,
            'synonym': self.synonym
        }


class WordRelated(db.Model):
    """同根词表"""
    __tablename__ = 'word_related'
    
    id = db.Column(db.BigInteger, primary_key=True, autoincrement=True)
    word_id = db.Column(db.String(100), db.ForeignKey('words.word_id', ondelete='CASCADE'), nullable=False, index=True, comment='单词ID')
    pos = db.Column(db.String(20), comment='词性')
    related_word = db.Column(db.String(100), nullable=False, comment='同根词')
    tran = db.Column(db.Text, comment='翻译')
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    def to_dict(self):
        """转换为字典"""
        return {
            'pos': self.pos,
            'relatedWord': self.related_word,
            'tran': self.tran
        }
