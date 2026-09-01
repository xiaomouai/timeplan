"""
单词数据库服务
基于MySQL数据库的单词查询服务
"""
from models import db, WordBook, Word, WordTranslation, WordSentence, WordPhrase, WordSynonym, WordRelated
from sqlalchemy import or_, and_
from typing import List, Dict, Any, Optional


class WordService:
    """单词数据库服务"""
    
    @staticmethod
    def get_books(category: str = None, grade: int = None, tags: str = None) -> List[Dict[str, Any]]:
        """
        获取词书列表
        
        Args:
            category: 分类筛选（通过tags字段）
            grade: 年级筛选（通过tags字段解析）
            tags: 标签筛选
            
        Returns:
            词书列表
        """
        query = WordBook.query
        
        # 通过tags字段筛选
        filters = []
        if category:
            filters.append(WordBook.tags.like(f'%{category}%'))
        if grade:
            filters.append(WordBook.tags.like(f'%{grade}年级%'))
        if tags:
            filters.append(WordBook.tags.like(f'%{tags}%'))
        
        if filters:
            query = query.filter(or_(*filters))
        
        books = query.all()
        return [book.to_dict() for book in books]
    
    @staticmethod
    def get_book_by_id(book_id: str) -> Optional[Dict[str, Any]]:
        """
        根据ID获取词书
        
        Args:
            book_id: 词书ID
            
        Returns:
            词书信息或None
        """
        book = WordBook.query.filter_by(id=book_id).first()
        return book.to_dict() if book else None
    
    @staticmethod
    def get_words_paginated(book_id: str, page: int = 1, page_size: int = 20) -> Dict[str, Any]:
        """
        分页获取单词列表
        
        Args:
            book_id: 词书ID
            page: 页码
            page_size: 每页数量
            
        Returns:
            包含单词列表和分页信息的字典
        """
        query = Word.query.filter_by(book_id=book_id).order_by(Word.word_rank)
        pagination = query.paginate(page=page, per_page=page_size, error_out=False)
        
        words = []
        for word in pagination.items:
            word_dict = word.to_dict()
            # 获取首个翻译作为简要翻译
            first_trans = word.translations.first()
            if first_trans:
                word_dict['translation'] = f"{first_trans.pos}. {first_trans.tran_cn}" if first_trans.pos else first_trans.tran_cn
            else:
                word_dict['translation'] = ''
            words.append(word_dict)
        
        return {
            'words': words,
            'total': pagination.total,
            'page': page,
            'page_size': page_size,
            'total_pages': pagination.pages
        }
    
    @staticmethod
    def get_word_detail(book_id: str, word_rank: int) -> Optional[Dict[str, Any]]:
        """
        获取单词详细信息
        
        Args:
            book_id: 词书ID
            word_rank: 单词序号
            
        Returns:
            单词详情或None
        """
        word = Word.query.filter_by(book_id=book_id, word_rank=word_rank).first()
        if not word:
            return None
        
        # 获取完整信息
        word_dict = word.to_dict()
        
        # 获取翻译
        translations = []
        for trans in word.translations:
            translations.append(trans.to_dict())
        word_dict['translations'] = translations
        
        # 获取例句
        sentences = []
        for sent in word.sentences:
            sentences.append(sent.to_dict())
        word_dict['sentences'] = sentences
        
        # 获取短语
        phrases = []
        for phrase in word.phrases:
            phrases.append(phrase.to_dict())
        word_dict['phrases'] = phrases
        
        # 获取近义词 - 分组
        synonyms_dict = {}
        for syn in word.synonyms:
            pos = syn.pos or 'other'
            if pos not in synonyms_dict:
                synonyms_dict[pos] = {
                    'pos': pos,
                    'tran': syn.tran,
                    'hwds': []
                }
            synonyms_dict[pos]['hwds'].append({'w': syn.synonym})
        word_dict['synonyms'] = list(synonyms_dict.values())
        
        # 获取同根词 - 分组
        rel_words_dict = {}
        for rel in word.related_words:
            pos = rel.pos or 'other'
            if pos not in rel_words_dict:
                rel_words_dict[pos] = {
                    'pos': pos,
                    'words': []
                }
            rel_words_dict[pos]['words'].append({
                'hwd': rel.related_word,
                'tran': rel.tran
            })
        word_dict['relWords'] = list(rel_words_dict.values())
        
        # 考题数据（暂时为空，需要单独的考题表）
        word_dict['exams'] = []
        
        return word_dict
    
    @staticmethod
    def search_words(keyword: str, book_id: str = None, category: str = None, limit: int = 50) -> List[Dict[str, Any]]:
        """
        搜索单词
        
        Args:
            keyword: 搜索关键词
            book_id: 限定词书ID（可选）
            category: 限定分类（可选）
            limit: 返回数量限制
            
        Returns:
            匹配的单词列表
        """
        query = Word.query.filter(Word.head_word.like(f'%{keyword}%'))
        
        if book_id:
            query = query.filter(Word.book_id == book_id)
        
        if category:
            # 通过join词书表筛选分类
            query = query.join(WordBook).filter(WordBook.tags.like(f'%{category}%'))
        
        query = query.order_by(Word.word_rank).limit(limit)
        words = query.all()
        
        results = []
        for word in words:
            word_dict = word.to_dict()
            # 获取词书信息
            book = word.book
            if book:
                word_dict['bookTitle'] = book.title
                # 从tags解析category和grade
                tags = book.tags.split(',') if book.tags else []
                for tag in tags:
                    if '小学' in tag or '初中' in tag or '高中' in tag:
                        word_dict['category'] = tag
                    if '年级' in tag:
                        try:
                            word_dict['grade'] = int(tag.replace('年级', ''))
                        except:
                            pass
            
            # 获取首个翻译
            first_trans = word.translations.first()
            if first_trans:
                word_dict['translation'] = f"{first_trans.pos}. {first_trans.tran_cn}" if first_trans.pos else first_trans.tran_cn
            
            results.append(word_dict)
        
        return results
    
    @staticmethod
    def get_words_by_ranks(book_id: str, word_ranks: List[int]) -> List[Dict[str, Any]]:
        """
        批量获取单词
        
        Args:
            book_id: 词书ID
            word_ranks: 单词序号列表
            
        Returns:
            单词列表
        """
        words = Word.query.filter(
            and_(
                Word.book_id == book_id,
                Word.word_rank.in_(word_ranks)
            )
        ).order_by(Word.word_rank).all()
        
        results = []
        for word in words:
            word_dict = WordService.get_word_detail(book_id, word.word_rank)
            if word_dict:
                results.append(word_dict)
        
        return results
    
    @staticmethod
    def get_book_statistics(book_id: str) -> Dict[str, Any]:
        """
        获取词书统计信息
        
        Args:
            book_id: 词书ID
            
        Returns:
            统计信息
        """
        book = WordBook.query.filter_by(id=book_id).first()
        if not book:
            return {}
        
        word_count = Word.query.filter_by(book_id=book_id).count()
        
        return {
            'book_id': book_id,
            'title': book.title,
            'word_count': word_count,
            'total_users': book.recite_user_num
        }
