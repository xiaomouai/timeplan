"""
Dict词库数据库模型
"""
from datetime import datetime


class DictBook:
    """词书模型"""
    
    def __init__(self):
        self.id = None
        self.book_id = None  # 词书ID (如: PEPXiaoXue3_1)
        self.title = None  # 标题
        self.word_count = 0  # 单词数量
        self.category = None  # 分类 (小学/初中/高中)
        self.tag = None  # 标签 (人教版/外研社版等)
        self.grade = None  # 年级
        self.term = None  # 学期 (1上册 2下册)
        self.popularity = 0  # 背诵人数
        self.icon = None  # 图标URL
        self.zip_file = None  # ZIP文件名
        self.file_size = 0  # 文件大小
        self.created_at = datetime.now()
        self.updated_at = datetime.now()
    
    def to_dict(self):
        """转换为字典"""
        return {
            'id': self.id,
            'book_id': self.book_id,
            'title': self.title,
            'word_count': self.word_count,
            'category': self.category,
            'tag': self.tag,
            'grade': self.grade,
            'term': self.term,
            'popularity': self.popularity,
            'icon': self.icon,
            'zip_file': self.zip_file,
            'file_size': self.file_size,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None
        }


class DictWord:
    """单词模型"""
    
    def __init__(self):
        self.id = None
        self.book_id = None  # 所属词书ID
        self.word_rank = None  # 单词序号
        self.head_word = None  # 单词
        self.uk_phone = None  # 英音音标
        self.us_phone = None  # 美音音标
        self.uk_speech = None  # 英音发音URL
        self.us_speech = None  # 美音发音URL
        self.translations = None  # 翻译 (JSON)
        self.sentences = None  # 例句 (JSON)
        self.phrases = None  # 短语 (JSON)
        self.synonyms = None  # 同义词 (JSON)
        self.rel_words = None  # 同根词 (JSON)
        self.exams = None  # 考题 (JSON)
        self.content = None  # 完整内容 (JSON)
        self.created_at = datetime.now()
    
    def to_dict(self):
        """转换为字典"""
        return {
            'id': self.id,
            'book_id': self.book_id,
            'word_rank': self.word_rank,
            'head_word': self.head_word,
            'uk_phone': self.uk_phone,
            'us_phone': self.us_phone,
            'uk_speech': self.uk_speech,
            'us_speech': self.us_speech,
            'translations': self.translations,
            'sentences': self.sentences,
            'phrases': self.phrases,
            'synonyms': self.synonyms,
            'rel_words': self.rel_words,
            'exams': self.exams,
            'content': self.content,
            'created_at': self.created_at.isoformat() if self.created_at else None
        }


# 数据库表结构SQL
CREATE_TABLES_SQL = """
-- 词书表
CREATE TABLE IF NOT EXISTS dict_books (
    id VARCHAR(32) PRIMARY KEY,
    book_id VARCHAR(50) UNIQUE NOT NULL,
    title VARCHAR(200) NOT NULL,
    word_count INT DEFAULT 0,
    category VARCHAR(20),
    tag VARCHAR(50),
    grade INT,
    term INT,
    popularity INT DEFAULT 0,
    icon VARCHAR(500),
    zip_file VARCHAR(200),
    file_size INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_book_id (book_id),
    INDEX idx_category (category),
    INDEX idx_grade (grade),
    INDEX idx_tag (tag)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 单词表
CREATE TABLE IF NOT EXISTS dict_words (
    id VARCHAR(32) PRIMARY KEY,
    book_id VARCHAR(50) NOT NULL,
    word_rank INT NOT NULL,
    head_word VARCHAR(100) NOT NULL,
    uk_phone VARCHAR(100),
    us_phone VARCHAR(100),
    uk_speech VARCHAR(500),
    us_speech VARCHAR(500),
    translations JSON,
    sentences JSON,
    phrases JSON,
    synonyms JSON,
    rel_words JSON,
    exams JSON,
    content JSON,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_book_rank (book_id, word_rank),
    INDEX idx_book_id (book_id),
    INDEX idx_head_word (head_word),
    INDEX idx_word_rank (word_rank),
    FULLTEXT KEY ft_head_word (head_word)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
"""
