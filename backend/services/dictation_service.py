"""
听写模块服务
提供听写任务创建、答题记录、成绩统计等功能
"""
from datetime import datetime
from typing import Optional, Dict, List
import random
from sqlalchemy import and_, func
from extensions import db
from models.study_models import Dictation, DictationRecord, DictationAnswer
from models.word_models import Word, WordBook
from services.word_service import WordService


class DictationService:
    """听写服务类"""
    
    # 听写模式配置
    MODES = {
        'sequential': {'name': '顺序听写', 'description': '按单词顺序依次听写'},
        'random': {'name': '随机听写', 'description': '随机抽取单词听写'},
        'wrong_words': {'name': '错词听写', 'description': '只听写之前错误的单词'}
    }
    
    @staticmethod
    def create_dictation(user_id: int, word_book_id: int, 
                        mode: str = 'sequential',
                        word_count: int = 20,
                        word_range: str = None) -> Optional[Dict]:
        """创建听写任务"""
        if mode not in DictationService.MODES:
            return None
        
        word_book = WordBook.query.get(word_book_id)
        if not word_book:
            return None
        
        # 创建听写记录
        dictation = Dictation(
            user_id=user_id,
            word_book_id=word_book_id,
            mode=mode,
            status='in_progress'
        )
        
        db.session.add(dictation)
        db.session.commit()
        
        # 获取待听写单词
        words = DictationService._select_words(
            user_id=user_id,
            word_book_id=word_book_id,
            mode=mode,
            count=word_count,
            word_range=word_range
        )
        
        dictation.total_words = len(words)
        db.session.commit()
        
        return {
            'dictation_id': dictation.id,
            'word_book_name': word_book.name,
            'mode': mode,
            'total_words': len(words),
            'words': words
        }
    
    @staticmethod
    def _select_words(user_id: int, word_book_id: int, mode: str, 
                     count: int, word_range: str = None) -> List[Dict]:
        """选择听写单词"""
        query = Word.query.filter_by(word_book_id=word_book_id)
        
        # 如果指定了范围，如 "1-100"
        if word_range:
            try:
                start, end = map(int, word_range.split('-'))
                query = query.filter(Word.word_index.between(start, end))
            except:
                pass
        
        words = query.all()
        
        if mode == 'random':
            # 随机模式
            if len(words) > count:
                words = random.sample(words, count)
        elif mode == 'wrong_words':
            # 错词模式 - 获取用户之前听错的单词
            wrong_word_ids = db.session.query(DictationAnswer.word_id)\
                .join(Dictation)\
                .filter(
                    Dictation.user_id == user_id,
                    DictationAnswer.is_correct == False
                ).distinct().all()
            
            wrong_word_ids = [wid[0] for wid in wrong_word_ids]
            
            if wrong_word_ids:
                words = [w for w in words if w.id in wrong_word_ids]
                if len(words) > count:
                    words = random.sample(words, count)
            else:
                # 如果没有错词，回退到随机模式
                if len(words) > count:
                    words = random.sample(words, count)
        else:
            # 顺序模式
            words = words[:count]
        
        result = []
        for idx, word in enumerate(words, 1):
            result.append({
                'index': idx,
                'word_id': word.id,
                'word': word.word,  # 前端需要验证答案时使用
                'definition': word.definition,
                'phonetic': word.phonetic,
                'audio_url': f'/api/word/audio/{word.id}'
            })
        
        return result
    
    @staticmethod
    def submit_answer(dictation_id: int, word_id: int, user_answer: str) -> Dict:
        """提交听写答案"""
        dictation = Dictation.query.get(dictation_id)
        if not dictation or dictation.status != 'in_progress':
            return {'success': False, 'message': '听写不存在或已结束'}
        
        word = Word.query.get(word_id)
        if not word:
            return {'success': False, 'message': '单词不存在'}
        
        # 判断正误（不区分大小写，去除首尾空格）
        correct_answer = word.word.strip().lower()
        user_answer_cleaned = user_answer.strip().lower()
        is_correct = (user_answer_cleaned == correct_answer)
        
        # 记录答题
        answer = DictationAnswer(
            dictation_id=dictation_id,
            word_id=word_id,
            user_answer=user_answer,
            correct_answer=word.word,
            is_correct=is_correct
        )
        
        db.session.add(answer)
        
        # 更新听写进度
        dictation.completed_words += 1
        if is_correct:
            dictation.correct_words += 1
        
        dictation.updated_at = datetime.now()
        
        db.session.commit()
        
        return {
            'success': True,
            'is_correct': is_correct,
            'correct_answer': word.word,
            'definition': word.definition,
            'completed': dictation.completed_words,
            'total': dictation.total_words
        }
    
    @staticmethod
    def finish_dictation(dictation_id: int) -> Optional[Dict]:
        """完成听写"""
        dictation = Dictation.query.get(dictation_id)
        if not dictation or dictation.status != 'in_progress':
            return None
        
        # 计算成绩
        if dictation.total_words > 0:
            accuracy = round((dictation.correct_words / dictation.total_words) * 100, 2)
        else:
            accuracy = 0
        
        dictation.accuracy = accuracy
        dictation.status = 'completed'
        dictation.completed_at = datetime.now()
        
        # 创建听写记录
        time_spent = (dictation.completed_at - dictation.created_at).total_seconds()
        
        record = DictationRecord(
            user_id=dictation.user_id,
            dictation_id=dictation.id,
            word_book_id=dictation.word_book_id,
            mode=dictation.mode,
            total_words=dictation.total_words,
            correct_words=dictation.correct_words,
            accuracy=accuracy,
            time_spent=int(time_spent)
        )
        
        db.session.add(record)
        db.session.commit()
        
        # 获取错词列表
        wrong_answers = DictationAnswer.query.filter_by(
            dictation_id=dictation_id,
            is_correct=False
        ).all()
        
        wrong_words = []
        for answer in wrong_answers:
            word = Word.query.get(answer.word_id)
            if word:
                wrong_words.append({
                    'word': word.word,
                    'definition': word.definition,
                    'user_answer': answer.user_answer
                })
        
        return {
            'dictation_id': dictation.id,
            'total_words': dictation.total_words,
            'correct_words': dictation.correct_words,
            'wrong_words_count': len(wrong_words),
            'accuracy': accuracy,
            'time_spent': int(time_spent),
            'wrong_words': wrong_words,
            'completed_at': dictation.completed_at.isoformat()
        }
    
    @staticmethod
    def get_dictation_detail(dictation_id: int, user_id: int) -> Optional[Dict]:
        """获取听写详情"""
        dictation = Dictation.query.filter_by(
            id=dictation_id,
            user_id=user_id
        ).first()
        
        if not dictation:
            return None
        
        word_book = WordBook.query.get(dictation.word_book_id)
        
        # 获取所有答题记录
        answers = DictationAnswer.query.filter_by(dictation_id=dictation_id).all()
        
        answer_list = []
        for answer in answers:
            word = Word.query.get(answer.word_id)
            if word:
                answer_list.append({
                    'word': word.word,
                    'definition': word.definition,
                    'phonetic': word.phonetic,
                    'user_answer': answer.user_answer,
                    'is_correct': answer.is_correct
                })
        
        return {
            'dictation_id': dictation.id,
            'word_book_name': word_book.name if word_book else '未知词书',
            'mode': dictation.mode,
            'status': dictation.status,
            'total_words': dictation.total_words,
            'completed_words': dictation.completed_words,
            'correct_words': dictation.correct_words,
            'accuracy': float(dictation.accuracy) if dictation.accuracy else 0,
            'answers': answer_list,
            'created_at': dictation.created_at.isoformat(),
            'completed_at': dictation.completed_at.isoformat() if dictation.completed_at else None
        }
    
    @staticmethod
    def get_dictation_history(user_id: int, page: int = 1, per_page: int = 20) -> Dict:
        """获取听写历史"""
        query = DictationRecord.query.filter_by(user_id=user_id)\
            .order_by(DictationRecord.created_at.desc())
        
        pagination = query.paginate(page=page, per_page=per_page, error_out=False)
        
        records = []
        for record in pagination.items:
            word_book = WordBook.query.get(record.word_book_id)
            records.append({
                'id': record.id,
                'dictation_id': record.dictation_id,
                'word_book_name': word_book.name if word_book else '未知词书',
                'mode': record.mode,
                'total_words': record.total_words,
                'correct_words': record.correct_words,
                'accuracy': float(record.accuracy),
                'time_spent': record.time_spent,
                'created_at': record.created_at.isoformat()
            })
        
        return {
            'records': records,
            'total': pagination.total,
            'page': page,
            'per_page': per_page,
            'pages': pagination.pages
        }
    
    @staticmethod
    def get_dictation_stats(user_id: int) -> Dict:
        """获取听写统计"""
        total_dictations = DictationRecord.query.filter_by(user_id=user_id).count()
        
        total_words = db.session.query(func.sum(DictationRecord.total_words))\
            .filter_by(user_id=user_id).scalar() or 0
        
        correct_words = db.session.query(func.sum(DictationRecord.correct_words))\
            .filter_by(user_id=user_id).scalar() or 0
        
        avg_accuracy = db.session.query(func.avg(DictationRecord.accuracy))\
            .filter_by(user_id=user_id).scalar() or 0
        
        highest_accuracy = db.session.query(func.max(DictationRecord.accuracy))\
            .filter_by(user_id=user_id).scalar() or 0
        
        return {
            'total_dictations': total_dictations,
            'total_words': int(total_words),
            'correct_words': int(correct_words),
            'overall_accuracy': round(correct_words / total_words * 100, 2) if total_words > 0 else 0,
            'average_accuracy': round(float(avg_accuracy), 2),
            'highest_accuracy': float(highest_accuracy)
        }
    
    @staticmethod
    def get_wrong_words(user_id: int, word_book_id: int = None) -> List[Dict]:
        """获取错词本"""
        query = db.session.query(
            Word.id,
            Word.word,
            Word.definition,
            Word.phonetic,
            func.count(DictationAnswer.id).label('wrong_count')
        ).join(
            DictationAnswer, Word.id == DictationAnswer.word_id
        ).join(
            Dictation, DictationAnswer.dictation_id == Dictation.id
        ).filter(
            Dictation.user_id == user_id,
            DictationAnswer.is_correct == False
        )
        
        if word_book_id:
            query = query.filter(Word.word_book_id == word_book_id)
        
        query = query.group_by(Word.id)\
            .order_by(func.count(DictationAnswer.id).desc())
        
        results = query.all()
        
        wrong_words = []
        for word_id, word, definition, phonetic, wrong_count in results:
            wrong_words.append({
                'word_id': word_id,
                'word': word,
                'definition': definition,
                'phonetic': phonetic,
                'wrong_count': wrong_count
            })
        
        return wrong_words
