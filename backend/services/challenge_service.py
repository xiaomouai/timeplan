"""
闯关模块服务
提供闯关题目生成、答题记录、成绩统计等功能
"""
from datetime import datetime
from typing import Optional, Dict, List
import random
from sqlalchemy import and_, func
from extensions import db
from models.study_models import Challenge, ChallengeRecord, ChallengeAnswer
from models.word_models import Word, WordBook
from services.word_service import WordService


class ChallengeService:
    """闯关服务类"""
    
    # 题型配置
    QUESTION_TYPES = {
        'choose_meaning': {'name': '选择词义', 'options_count': 4},
        'choose_word': {'name': '选择单词', 'options_count': 4},
        'spell_word': {'name': '拼写单词', 'options_count': 0},
        'listen_choose': {'name': '听音选词', 'options_count': 4}
    }
    
    # 难度配置
    DIFFICULTY_CONFIG = {
        'easy': {'name': '简单', 'questions_count': 10, 'pass_score': 60},
        'medium': {'name': '中等', 'questions_count': 15, 'pass_score': 70},
        'hard': {'name': '困难', 'questions_count': 20, 'pass_score': 80}
    }
    
    @staticmethod
    def create_challenge(user_id: int, word_book_id: int, 
                        difficulty: str = 'easy',
                        question_type: str = 'choose_meaning') -> Optional[Challenge]:
        """创建闯关"""
        if difficulty not in ChallengeService.DIFFICULTY_CONFIG:
            return None
        
        if question_type not in ChallengeService.QUESTION_TYPES:
            return None
        
        config = ChallengeService.DIFFICULTY_CONFIG[difficulty]
        
        # 创建闯关记录
        challenge = Challenge(
            user_id=user_id,
            word_book_id=word_book_id,
            difficulty=difficulty,
            total_questions=config['questions_count'],
            status='in_progress'
        )
        
        db.session.add(challenge)
        db.session.commit()
        
        # 生成题目
        questions = ChallengeService._generate_questions(
            word_book_id=word_book_id,
            question_type=question_type,
            count=config['questions_count']
        )
        
        return {
            'challenge_id': challenge.id,
            'difficulty': difficulty,
            'total_questions': config['questions_count'],
            'pass_score': config['pass_score'],
            'questions': questions
        }
    
    @staticmethod
    def _generate_questions(word_book_id: int, question_type: str, count: int) -> List[Dict]:
        """生成题目"""
        # 从词书中随机抽取单词
        words = Word.query.filter_by(word_book_id=word_book_id).all()
        
        if len(words) < count:
            count = len(words)
        
        selected_words = random.sample(words, count)
        questions = []
        
        for idx, word in enumerate(selected_words, 1):
            if question_type == 'choose_meaning':
                question = ChallengeService._create_choose_meaning_question(word, words)
            elif question_type == 'choose_word':
                question = ChallengeService._create_choose_word_question(word, words)
            elif question_type == 'spell_word':
                question = ChallengeService._create_spell_word_question(word)
            elif question_type == 'listen_choose':
                question = ChallengeService._create_listen_choose_question(word, words)
            else:
                continue
            
            question['question_no'] = idx
            questions.append(question)
        
        return questions
    
    @staticmethod
    def _create_choose_meaning_question(word: Word, all_words: List[Word]) -> Dict:
        """创建选择词义题目"""
        # 随机选择3个干扰项
        other_words = [w for w in all_words if w.id != word.id]
        distractors = random.sample(other_words, min(3, len(other_words)))
        
        options = [
            {'option': 'A', 'text': word.definition, 'is_correct': True}
        ]
        
        for i, distractor in enumerate(distractors):
            options.append({
                'option': chr(66 + i),  # B, C, D
                'text': distractor.definition,
                'is_correct': False
            })
        
        random.shuffle(options)
        
        return {
            'word_id': word.id,
            'question_type': 'choose_meaning',
            'question': f'"{word.word}" 的意思是？',
            'word': word.word,
            'options': options
        }
    
    @staticmethod
    def _create_choose_word_question(word: Word, all_words: List[Word]) -> Dict:
        """创建选择单词题目"""
        other_words = [w for w in all_words if w.id != word.id]
        distractors = random.sample(other_words, min(3, len(other_words)))
        
        options = [
            {'option': 'A', 'text': word.word, 'is_correct': True}
        ]
        
        for i, distractor in enumerate(distractors):
            options.append({
                'option': chr(66 + i),
                'text': distractor.word,
                'is_correct': False
            })
        
        random.shuffle(options)
        
        return {
            'word_id': word.id,
            'question_type': 'choose_word',
            'question': f'"{word.definition}" 对应的单词是？',
            'definition': word.definition,
            'options': options
        }
    
    @staticmethod
    def _create_spell_word_question(word: Word) -> Dict:
        """创建拼写题目"""
        return {
            'word_id': word.id,
            'question_type': 'spell_word',
            'question': f'请拼写出"{word.definition}"对应的单词',
            'definition': word.definition,
            'phonetic': word.phonetic,
            'correct_answer': word.word
        }
    
    @staticmethod
    def _create_listen_choose_question(word: Word, all_words: List[Word]) -> Dict:
        """创建听音选词题目"""
        other_words = [w for w in all_words if w.id != word.id]
        distractors = random.sample(other_words, min(3, len(other_words)))
        
        options = [
            {'option': 'A', 'text': word.word, 'is_correct': True}
        ]
        
        for i, distractor in enumerate(distractors):
            options.append({
                'option': chr(66 + i),
                'text': distractor.word,
                'is_correct': False
            })
        
        random.shuffle(options)
        
        return {
            'word_id': word.id,
            'question_type': 'listen_choose',
            'question': '听音频，选择正确的单词',
            'audio_url': f'/api/word/audio/{word.id}',
            'options': options
        }
    
    @staticmethod
    def submit_answer(challenge_id: int, word_id: int, user_answer: str, 
                     is_correct: bool, time_spent: int = 0) -> bool:
        """提交答案"""
        challenge = Challenge.query.get(challenge_id)
        if not challenge or challenge.status != 'in_progress':
            return False
        
        # 记录答题
        answer = ChallengeAnswer(
            challenge_id=challenge_id,
            word_id=word_id,
            user_answer=user_answer,
            is_correct=is_correct,
            time_spent=time_spent
        )
        
        db.session.add(answer)
        
        # 更新闯关进度
        challenge.answered_questions += 1
        if is_correct:
            challenge.correct_answers += 1
        
        challenge.updated_at = datetime.now()
        
        db.session.commit()
        
        return True
    
    @staticmethod
    def finish_challenge(challenge_id: int) -> Optional[Dict]:
        """完成闯关"""
        challenge = Challenge.query.get(challenge_id)
        if not challenge or challenge.status != 'in_progress':
            return None
        
        # 计算成绩
        if challenge.total_questions > 0:
            score = int((challenge.correct_answers / challenge.total_questions) * 100)
        else:
            score = 0
        
        challenge.score = score
        challenge.status = 'completed'
        challenge.completed_at = datetime.now()
        
        # 判断是否通过
        difficulty_config = ChallengeService.DIFFICULTY_CONFIG.get(challenge.difficulty, {})
        pass_score = difficulty_config.get('pass_score', 60)
        is_passed = score >= pass_score
        
        # 创建闯关记录
        record = ChallengeRecord(
            user_id=challenge.user_id,
            challenge_id=challenge.id,
            word_book_id=challenge.word_book_id,
            difficulty=challenge.difficulty,
            score=score,
            total_questions=challenge.total_questions,
            correct_answers=challenge.correct_answers,
            time_spent=challenge.updated_at.timestamp() - challenge.created_at.timestamp(),
            is_passed=is_passed
        )
        
        db.session.add(record)
        db.session.commit()
        
        return {
            'challenge_id': challenge.id,
            'score': score,
            'total_questions': challenge.total_questions,
            'correct_answers': challenge.correct_answers,
            'is_passed': is_passed,
            'pass_score': pass_score,
            'completed_at': challenge.completed_at.isoformat()
        }
    
    @staticmethod
    def get_challenge_history(user_id: int, page: int = 1, per_page: int = 20) -> Dict:
        """获取闯关历史"""
        query = ChallengeRecord.query.filter_by(user_id=user_id)\
            .order_by(ChallengeRecord.created_at.desc())
        
        pagination = query.paginate(page=page, per_page=per_page, error_out=False)
        
        records = []
        for record in pagination.items:
            word_book = WordBook.query.get(record.word_book_id)
            records.append({
                'id': record.id,
                'word_book_name': word_book.name if word_book else '未知词书',
                'difficulty': record.difficulty,
                'score': record.score,
                'total_questions': record.total_questions,
                'correct_answers': record.correct_answers,
                'time_spent': int(record.time_spent),
                'is_passed': record.is_passed,
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
    def get_challenge_stats(user_id: int) -> Dict:
        """获取闯关统计"""
        total_challenges = ChallengeRecord.query.filter_by(user_id=user_id).count()
        passed_challenges = ChallengeRecord.query.filter_by(
            user_id=user_id, 
            is_passed=True
        ).count()
        
        avg_score = db.session.query(func.avg(ChallengeRecord.score))\
            .filter_by(user_id=user_id).scalar() or 0
        
        highest_score = db.session.query(func.max(ChallengeRecord.score))\
            .filter_by(user_id=user_id).scalar() or 0
        
        return {
            'total_challenges': total_challenges,
            'passed_challenges': passed_challenges,
            'pass_rate': round(passed_challenges / total_challenges * 100, 2) if total_challenges > 0 else 0,
            'average_score': round(float(avg_score), 2),
            'highest_score': int(highest_score)
        }
