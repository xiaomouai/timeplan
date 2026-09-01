"""
Dict词库服务
处理Dict ZIP文件的读取和解析，以及SQLite数据库查询
"""
import os
import json
import zipfile
import sqlite3
from pathlib import Path
from typing import List, Dict, Any, Optional
from functools import lru_cache


class DictService:
    """Dict词库服务类"""

    # 词库服务可能被 API、脚本或测试从不同工作目录调用，因此不依赖 cwd。
    BASE_DIR = Path(__file__).resolve().parents[1]
    DICT_PATH = os.getenv("DICT_PATH", str(BASE_DIR / "dict" / "book"))
    DB_PATH = os.getenv("DICT_DB_PATH", str(BASE_DIR / "lioneng.db"))
    
    @classmethod
    def get_db_connection(cls):
        """获取数据库连接"""
        return sqlite3.connect(cls.DB_PATH)
    
    @classmethod
    def dict_row_factory(cls, cursor, row):
        """将数据库行转换为字典"""
        fields = [column[0] for column in cursor.description]
        return {key: value for key, value in zip(fields, row)}
    
    # 词书元数据
    BOOKS_METADATA = [
        {'id': 'PEPXiaoXue3_1', 'title': '人教版小学英语-三年级上册', 'wordCount': 64, 'category': '小学', 'grade': 3, 'term': 1, 'tag': '人教版'},
        {'id': 'PEPXiaoXue3_2', 'title': '人教版小学英语-三年级下册', 'wordCount': 72, 'category': '小学', 'grade': 3, 'term': 2, 'tag': '人教版'},
        {'id': 'PEPXiaoXue4_1', 'title': '人教版小学英语-四年级上册', 'wordCount': 84, 'category': '小学', 'grade': 4, 'term': 1, 'tag': '人教版'},
        {'id': 'PEPXiaoXue4_2', 'title': '人教版小学英语-四年级下册', 'wordCount': 104, 'category': '小学', 'grade': 4, 'term': 2, 'tag': '人教版'},
        {'id': 'PEPXiaoXue5_1', 'title': '人教版小学英语-五年级上册', 'wordCount': 131, 'category': '小学', 'grade': 5, 'term': 1, 'tag': '人教版'},
        {'id': 'PEPXiaoXue5_2', 'title': '人教版小学英语-五年级下册', 'wordCount': 156, 'category': '小学', 'grade': 5, 'term': 2, 'tag': '人教版'},
        {'id': 'PEPXiaoXue6_1', 'title': '人教版小学英语-六年级上册', 'wordCount': 130, 'category': '小学', 'grade': 6, 'term': 1, 'tag': '人教版'},
        {'id': 'PEPXiaoXue6_2', 'title': '人教版小学英语-六年级下册', 'wordCount': 108, 'category': '小学', 'grade': 6, 'term': 2, 'tag': '人教版'},
        {'id': 'PEPChuZhong7_1', 'title': '人教版初中英语-七年级上册', 'wordCount': 392, 'category': '初中', 'grade': 7, 'term': 1, 'tag': '人教版'},
        {'id': 'PEPChuZhong7_2', 'title': '人教版初中英语-七年级下册', 'wordCount': 492, 'category': '初中', 'grade': 7, 'term': 2, 'tag': '人教版'},
        {'id': 'PEPChuZhong8_1', 'title': '人教版初中英语-八年级上册', 'wordCount': 419, 'category': '初中', 'grade': 8, 'term': 1, 'tag': '人教版'},
        {'id': 'PEPChuZhong8_2', 'title': '人教版初中英语-八年级下册', 'wordCount': 466, 'category': '初中', 'grade': 8, 'term': 2, 'tag': '人教版'},
        {'id': 'PEPChuZhong9_1', 'title': '人教版初中英语-九年级全册', 'wordCount': 551, 'category': '初中', 'grade': 9, 'term': 1, 'tag': '人教版'},
    ]
    
    # ==================== 数据库查询方法 ====================
    
    @classmethod
    def get_books_from_db(cls, category: str = None, grade: int = None) -> List[Dict[str, Any]]:
        """从数据库获取词书列表"""
        conn = cls.get_db_connection()
        conn.row_factory = cls.dict_row_factory
        cursor = conn.cursor()
        
        try:
            query = "SELECT * FROM dict_books WHERE 1=1"
            params = []
            
            if category:
                query += " AND category = ?"
                params.append(category)
            
            if grade:
                query += " AND grade = ?"
                params.append(grade)
            
            query += " ORDER BY grade, term"
            
            cursor.execute(query, params)
            books = cursor.fetchall()
            return books
        finally:
            conn.close()
    
    @classmethod
    def get_book_by_id(cls, book_id: str) -> Optional[Dict[str, Any]]:
        """从数据库获取单个词书"""
        conn = cls.get_db_connection()
        conn.row_factory = cls.dict_row_factory
        cursor = conn.cursor()
        
        try:
            cursor.execute("SELECT * FROM dict_books WHERE book_id = ?", (book_id,))
            return cursor.fetchone()
        finally:
            conn.close()
    
    @classmethod
    def get_words_from_db(cls, book_id: str, page: int = 1, page_size: int = 20) -> Dict[str, Any]:
        """从数据库获取单词列表（分页）"""
        conn = cls.get_db_connection()
        conn.row_factory = cls.dict_row_factory
        cursor = conn.cursor()
        
        try:
            # 获取总数
            cursor.execute("SELECT COUNT(*) as total FROM dict_words WHERE book_id = ?", (book_id,))
            total = cursor.fetchone()['total']
            
            # 获取分页数据
            offset = (page - 1) * page_size
            cursor.execute("""
                SELECT id, book_id, word_rank, head_word, uk_phone, us_phone, 
                       uk_speech, us_speech, translations
                FROM dict_words 
                WHERE book_id = ? 
                ORDER BY word_rank
                LIMIT ? OFFSET ?
            """, (book_id, page_size, offset))
            
            words = cursor.fetchall()
            
            # 解析JSON字段
            for word in words:
                if word.get('translations'):
                    try:
                        word['translations'] = json.loads(word['translations'])
                    except:
                        word['translations'] = []
            
            return {
                'total': total,
                'page': page,
                'page_size': page_size,
                'total_pages': (total + page_size - 1) // page_size,
                'words': words
            }
        finally:
            conn.close()
    
    @classmethod
    def get_word_from_db(cls, book_id: str, word_rank: int) -> Optional[Dict[str, Any]]:
        """从数据库获取单词详情"""
        conn = cls.get_db_connection()
        conn.row_factory = cls.dict_row_factory
        cursor = conn.cursor()
        
        try:
            cursor.execute("""
                SELECT * FROM dict_words 
                WHERE book_id = ? AND word_rank = ?
            """, (book_id, word_rank))
            
            word = cursor.fetchone()
            if not word:
                return None
            
            # 解析JSON字段
            json_fields = ['translations', 'sentences', 'phrases', 'synonyms', 'rel_words', 'exams', 'content']
            for field in json_fields:
                if word.get(field):
                    try:
                        word[field] = json.loads(word[field])
                    except:
                        word[field] = {} if field in ['sentences', 'phrases', 'synonyms', 'rel_words', 'content'] else []
            
            return word
        finally:
            conn.close()
    
    @classmethod
    def search_words_in_db(cls, keyword: str, book_id: str = None, limit: int = 50) -> List[Dict[str, Any]]:
        """在数据库中搜索单词"""
        conn = cls.get_db_connection()
        conn.row_factory = cls.dict_row_factory
        cursor = conn.cursor()
        
        try:
            query = """
                SELECT w.*, b.title as book_title, b.category, b.grade
                FROM dict_words w
                LEFT JOIN dict_books b ON w.book_id = b.book_id
                WHERE w.head_word LIKE ?
            """
            params = [f"%{keyword}%"]
            
            if book_id:
                query += " AND w.book_id = ?"
                params.append(book_id)
            
            query += " ORDER BY w.word_rank LIMIT ?"
            params.append(limit)
            
            cursor.execute(query, params)
            words = cursor.fetchall()
            
            # 解析translations字段
            for word in words:
                if word.get('translations'):
                    try:
                        word['translations'] = json.loads(word['translations'])
                    except:
                        word['translations'] = []
            
            return words
        finally:
            conn.close()
    
    @classmethod
    def get_words_by_ranks(cls, book_id: str, word_ranks: List[int]) -> List[Dict[str, Any]]:
        """批量获取单词"""
        conn = cls.get_db_connection()
        conn.row_factory = cls.dict_row_factory
        cursor = conn.cursor()
        
        try:
            placeholders = ','.join('?' * len(word_ranks))
            query = f"""
                SELECT * FROM dict_words 
                WHERE book_id = ? AND word_rank IN ({placeholders})
                ORDER BY word_rank
            """
            
            cursor.execute(query, [book_id] + word_ranks)
            words = cursor.fetchall()
            
            # 解析JSON字段
            json_fields = ['translations', 'sentences', 'phrases', 'synonyms', 'rel_words', 'exams']
            for word in words:
                for field in json_fields:
                    if word.get(field):
                        try:
                            word[field] = json.loads(word[field])
                        except:
                            word[field] = {} if field in ['sentences', 'phrases', 'synonyms', 'rel_words'] else []
            
            return words
        finally:
            conn.close()
    
    # ==================== 原有ZIP文件方法（保留作为备用） ====================
    
    @classmethod
    def find_zip_file(cls, book_id: str) -> Optional[str]:
        """查找指定词书的ZIP文件"""
        try:
            if not os.path.exists(cls.DICT_PATH):
                return None
            
            zip_files = [
                f for f in os.listdir(cls.DICT_PATH) 
                if book_id in f and f.endswith('.zip')
            ]
            return os.path.join(cls.DICT_PATH, zip_files[0]) if zip_files else None
        except Exception as e:
            print(f"Error finding zip file for {book_id}: {e}")
            return None
    
    @classmethod
    def read_words_from_zip(cls, zip_path: str) -> List[Dict[str, Any]]:
        """从ZIP文件读取所有单词"""
        words = []
        try:
            with zipfile.ZipFile(zip_path, 'r') as zip_ref:
                json_files = [f for f in zip_ref.namelist() if f.endswith('.json')]
                
                for json_file in json_files:
                    with zip_ref.open(json_file) as f:
                        content = f.read().decode('utf-8')
                        
                        try:
                            data = json.loads(content)
                            if isinstance(data, list):
                                words.extend(data)
                            elif isinstance(data, dict):
                                words.append(data)
                        except json.JSONDecodeError:
                            for line in content.strip().split('\n'):
                                if line.strip():
                                    try:
                                        word_data = json.loads(line)
                                        words.append(word_data)
                                    except json.JSONDecodeError:
                                        continue
        except Exception as e:
            print(f"Error reading zip file {zip_path}: {e}")
        
        return words
    
    @classmethod
    @lru_cache(maxsize=20)
    def load_book_words(cls, book_id: str) -> Optional[List[Dict[str, Any]]]:
        """加载词书的所有单词（带缓存）"""
        zip_path = cls.find_zip_file(book_id)
        if not zip_path:
            return None
        return cls.read_words_from_zip(zip_path)
    
    @classmethod
    def find_word_by_rank(cls, book_id: str, word_rank: int) -> Optional[Dict[str, Any]]:
        """根据wordRank查找单词"""
        words = cls.load_book_words(book_id)
        if not words:
            return None
        
        for word in words:
            if word.get('wordRank') == word_rank:
                return word
        return None
    
    @classmethod
    def extract_word_content(cls, word_data: Dict[str, Any]) -> Dict[str, Any]:
        """提取单词内容"""
        content = {}
        if 'content' in word_data and isinstance(word_data['content'], dict):
            if 'word' in word_data['content'] and isinstance(word_data['content']['word'], dict):
                content = word_data['content']['word'].get('content', {})
        return content
    
    @classmethod
    def format_word_detail(cls, word_data: Dict[str, Any], book_id: str) -> Dict[str, Any]:
        """格式化单词详情"""
        content = cls.extract_word_content(word_data)
        head_word = word_data.get('headWord', '')
        
        return {
            'bookId': book_id,
            'wordRank': word_data.get('wordRank'),
            'word': head_word,
            'ukphone': content.get('ukphone', ''),
            'usphone': content.get('usphone', ''),
            'ukspeech': f"https://dict.youdao.com/dictvoice?audio={head_word}&type=1",
            'usspeech': f"https://dict.youdao.com/dictvoice?audio={head_word}&type=2",
            'translations': cls._extract_translations(content),
            'sentences': cls._extract_sentences(content),
            'phrases': cls._extract_phrases(content),
            'synonyms': cls._extract_synonyms(content),
            'relWords': cls._extract_rel_words(content),
            'exams': cls._extract_exams(content)
        }
    
    @classmethod
    def format_word_simple(cls, word_data: Dict[str, Any]) -> Dict[str, Any]:
        """格式化简单单词信息"""
        content = cls.extract_word_content(word_data)
        
        trans_list = content.get('trans', [])
        simple_trans = ''
        if isinstance(trans_list, list) and len(trans_list) > 0:
            first_trans = trans_list[0]
            if isinstance(first_trans, dict):
                pos = first_trans.get('pos', '')
                tran_cn = first_trans.get('tranCn', '')
                simple_trans = f"{pos}. {tran_cn}" if pos else tran_cn
        
        head_word = word_data.get('headWord', '')
        
        return {
            'wordRank': word_data.get('wordRank'),
            'headWord': head_word,
            'usphone': content.get('usphone', ''),
            'ukphone': content.get('ukphone', ''),
            'translation': simple_trans,
            'usspeech': f"https://dict.youdao.com/dictvoice?audio={head_word}&type=2",
            'ukspeech': f"https://dict.youdao.com/dictvoice?audio={head_word}&type=1"
        }
    
    @staticmethod
    def _extract_translations(content: Dict) -> List[Dict[str, str]]:
        """提取翻译"""
        translations = []
        trans_list = content.get('trans', [])
        if isinstance(trans_list, list):
            for trans in trans_list:
                if isinstance(trans, dict):
                    translations.append({
                        'pos': trans.get('pos', ''),
                        'tranCn': trans.get('tranCn', ''),
                        'tranOther': trans.get('tranOther', '')
                    })
        return translations
    
    @staticmethod
    def _extract_sentences(content: Dict) -> List[Dict[str, str]]:
        """提取例句"""
        sentences = []
        sentence_data = content.get('sentence', {})
        if isinstance(sentence_data, dict):
            sentence_list = sentence_data.get('sentences', [])
            if isinstance(sentence_list, list):
                for sent in sentence_list:
                    if isinstance(sent, dict):
                        sentences.append({
                            'sCn': sent.get('sCn', ''),
                            'sContent': sent.get('sContent', '')
                        })
        return sentences
    
    @staticmethod
    def _extract_phrases(content: Dict) -> List[Dict[str, str]]:
        """提取短语"""
        phrases = []
        phrase_data = content.get('phrase', {})
        if isinstance(phrase_data, dict):
            phrase_list = phrase_data.get('phrases', [])
            if isinstance(phrase_list, list):
                for phrase in phrase_list:
                    if isinstance(phrase, dict):
                        phrases.append({
                            'pContent': phrase.get('pContent', ''),
                            'pCn': phrase.get('pCn', '')
                        })
        return phrases
    
    @staticmethod
    def _extract_synonyms(content: Dict) -> List[Dict[str, Any]]:
        """提取同义词"""
        synonyms = []
        syno_data = content.get('syno', {})
        if isinstance(syno_data, dict):
            syno_list = syno_data.get('synos', [])
            if isinstance(syno_list, list):
                for syno in syno_list:
                    if isinstance(syno, dict):
                        synonyms.append({
                            'pos': syno.get('pos', ''),
                            'tran': syno.get('tran', ''),
                            'hwds': syno.get('hwds', [])
                        })
        return synonyms
    
    @staticmethod
    def _extract_rel_words(content: Dict) -> List[Dict[str, Any]]:
        """提取相关词"""
        rel_words = []
        rel_word_data = content.get('relWord', {})
        if isinstance(rel_word_data, dict):
            rel_word_list = rel_word_data.get('rels', [])
            if isinstance(rel_word_list, list):
                for rel in rel_word_list:
                    if isinstance(rel, dict):
                        rel_words.append({
                            'pos': rel.get('pos', ''),
                            'words': rel.get('words', [])
                        })
        return rel_words
    
    @staticmethod
    def _extract_exams(content: Dict) -> List[Dict[str, Any]]:
        """提取考题"""
        exams = []
        exam_list = content.get('exam', [])
        if isinstance(exam_list, list):
            for exam in exam_list:
                if isinstance(exam, dict):
                    exams.append({
                        'question': exam.get('question', ''),
                        'examType': exam.get('examType', 1),
                        'choices': exam.get('choices', []),
                        'answer': exam.get('answer', {})
                    })
        return exams
    
    @classmethod
    def get_book_metadata(cls, book_id: str) -> Optional[Dict[str, Any]]:
        """获取词书元数据"""
        for book in cls.BOOKS_METADATA:
            if book['id'] == book_id:
                return book
        return None
    
    @classmethod
    def get_books_by_category(cls, category: str = None) -> List[Dict[str, Any]]:
        """按分类获取词书列表"""
        if category:
            return [b for b in cls.BOOKS_METADATA if b.get('category') == category]
        return cls.BOOKS_METADATA
    
    @classmethod
    def search_words(cls, keyword: str, book_id: str = None, limit: int = 50) -> List[Dict[str, Any]]:
        """搜索单词"""
        results = []
        keyword_lower = keyword.lower()
        
        books_to_search = [book_id] if book_id else [b['id'] for b in cls.BOOKS_METADATA[:10]]
        
        for bid in books_to_search:
            words = cls.load_book_words(bid)
            if not words:
                continue
            
            book_meta = cls.get_book_metadata(bid)
            
            for word in words:
                if keyword_lower in word.get('headWord', '').lower():
                    simple_word = cls.format_word_simple(word)
                    simple_word['bookId'] = bid
                    if book_meta:
                        simple_word['bookTitle'] = book_meta['title']
                        simple_word['category'] = book_meta.get('category', '')
                        simple_word['grade'] = book_meta.get('grade', 0)
                    results.append(simple_word)
                    
                    if len(results) >= limit:
                        return results
        
        return results
