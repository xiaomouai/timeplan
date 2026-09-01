"""
单词相关API接口（重构版 - 使用MySQL数据库）
"""
from flask import request, jsonify
from flask_jwt_extended import get_jwt_identity, jwt_required, verify_jwt_in_request
from datetime import datetime, timedelta
import uuid
from . import api_v1
from services.word_service import WordService
from models import db, User, UserWord
from utils.response import success_response, error_response


def calculate_next_review(mastery_level: int) -> datetime:
    """根据掌握程度计算下次复习时间（艾宾浩斯遗忘曲线）"""
    intervals = {
        0: 0,      # 未学习
        1: 1,      # 5分钟后
        2: 1,      # 1天后
        3: 2,      # 2天后
        4: 4,      # 4天后
        5: 7,      # 7天后
    }
    days = intervals.get(mastery_level, 0)
    return datetime.utcnow() + timedelta(days=days)


@api_v1.route('/words/<book_id>/<int:word_rank>', methods=['GET'])
def get_word_detail(book_id, word_rank):
    """
    获取单词详细信息
    ---
    tags:
      - 单词学习
    summary: 获取单词详情
    description: 根据词书ID和单词序号获取单词的完整信息
    parameters:
      - name: book_id
        in: path
        type: string
        required: true
        description: 词书ID
      - name: word_rank
        in: path
        type: integer
        required: true
        description: 单词序号
    responses:
      200:
        description: 成功
      404:
        description: 单词不存在
    """
    # 从数据库获取单词详情
    word = WordService.get_word_detail(book_id, word_rank)
    if not word:
        return error_response(404, '单词不存在')
    
    # 格式化返回数据
    formatted_word = {
        'bookId': word['book_id'],
        'wordRank': word['word_rank'],
        'word': word['head_word'],
        'ukphone': word['uk_phone'],
        'usphone': word['us_phone'],
        'ukspeech': word['uk_speech'],
        'usspeech': word['us_speech'],
        'translations': word.get('translations', []),
        'sentences': word.get('sentences', []),
        'phrases': word.get('phrases', []),
        'synonyms': word.get('synonyms', []),
        'relWords': word.get('relWords', []),
        'exams': word.get('exams', [])
    }
    
    formatted_word['userLearning'] = {
        'isLearned': False,
        'masteryLevel': 0,
        'learnCount': 0,
        'correctCount': 0,
        'wrongCount': 0,
        'lastLearnAt': None,
        'nextReviewAt': None
    }
    verify_jwt_in_request(optional=True)
    user_id = get_jwt_identity()
    if user_id:
        user_word = UserWord.query.filter_by(
            user_id=str(user_id),
            word_id=word['word_id'],
        ).first()
        if user_word:
            formatted_word['userLearning'] = {
                'isLearned': user_word.learn_count > 0,
                'masteryLevel': user_word.mastery_level,
                'learnCount': user_word.learn_count,
                'correctCount': user_word.correct_count,
                'wrongCount': user_word.wrong_count,
                'lastLearnAt': user_word.last_learn_at.isoformat() if user_word.last_learn_at else None,
                'nextReviewAt': user_word.next_review_at.isoformat() if user_word.next_review_at else None,
            }
    
    return success_response(formatted_word)


@api_v1.route('/words/<book_id>/<int:word_rank>/learn', methods=['POST'])
@jwt_required()
def update_word_learning(book_id, word_rank):
    """
    更新单词学习状态
    ---
    tags:
      - 单词学习
    summary: 更新单词学习状态
    description: 记录用户对单词的学习行为
    security:
      - Bearer: []
    parameters:
      - name: book_id
        in: path
        type: string
        required: true
        description: 词书ID
      - name: word_rank
        in: path
        type: integer
        required: true
        description: 单词序号
      - in: body
        name: body
        required: true
        schema:
          type: object
          required:
            - action
          properties:
            action:
              type: string
              enum: [view, listen, read, practice]
              description: 学习动作类型
            duration:
              type: integer
              description: 学习时长（秒）
            is_correct:
              type: boolean
              description: 是否答对（练习时）
            score:
              type: integer
              description: 得分（练习时）
    responses:
      200:
        description: 成功
      404:
        description: 单词不存在
    """
    data = request.get_json(silent=True) or {}
    action = data.get('action')  # view/listen/read/practice
    duration = data.get('duration', 0)
    is_correct = data.get('is_correct')
    score = data.get('score')
    
    # 验证单词存在
    word = WordService.get_word_detail(book_id, word_rank)
    if not word:
        return error_response(404, '单词不存在')
    
    user_id = str(get_jwt_identity())
    word_id = word['word_id']
    
    try:
        # 查找或创建用户单词记录
        user_word = UserWord.query.filter_by(
            user_id=user_id,
            word_id=word_id
        ).first()
        
        if not user_word:
            user_word = UserWord(
                id=uuid.uuid4().hex,
                user_id=user_id,
                word_id=word_id,
                mastery_level=0,
                learn_count=0,
                correct_count=0,
                wrong_count=0
            )
            db.session.add(user_word)
        
        # 更新学习记录
        user_word.learn_count += 1
        user_word.last_learn_at = datetime.utcnow()
        
        # 根据是否正确更新掌握程度
        if is_correct is not None:
            if is_correct:
                user_word.correct_count += 1
                # 提升掌握程度
                if user_word.mastery_level < 5:
                    user_word.mastery_level += 1
            else:
                user_word.wrong_count += 1
                # 降低掌握程度
                if user_word.mastery_level > 0:
                    user_word.mastery_level -= 1
        
        # 计算下次复习时间
        user_word.next_review_at = calculate_next_review(user_word.mastery_level)
        
        db.session.commit()
        
        # 计算奖励
        points_earned = 10 if is_correct else 5
        exp_earned = 5 if is_correct else 2
        
        return success_response({
            'wordRank': word_rank,
            'word': word.get('head_word', ''),
            'masteryLevel': user_word.mastery_level,
            'nextReviewAt': user_word.next_review_at.isoformat() if user_word.next_review_at else None,
            'points_earned': points_earned,
            'exp_earned': exp_earned,
            'streak_days': getattr(db.session.get(User, user_id), 'streak_days', 0),
            'achievements': []
        })
    except Exception as e:
        db.session.rollback()
        return error_response(500, f'更新失败: {str(e)}')


@api_v1.route('/words/batch', methods=['POST'])
def get_words_batch():
    """
    批量获取单词
    ---
    tags:
      - 单词学习
    summary: 批量获取单词详情
    parameters:
      - in: body
        name: body
        required: true
        schema:
          type: object
          properties:
            words:
              type: array
              items:
                type: object
                properties:
                  bookId:
                    type: string
                  wordRank:
                    type: integer
    responses:
      200:
        description: 成功
    """
    data = request.get_json()
    words_request = data.get('words', [])
    
    results = []
    for word_req in words_request:
        book_id = word_req.get('bookId')
        word_rank = word_req.get('wordRank')
        
        word = WordService.get_word_detail(book_id, word_rank)
        if word:
            formatted_word = {
                'bookId': word['book_id'],
                'wordRank': word['word_rank'],
                'word': word['head_word'],
                'ukphone': word['uk_phone'],
                'usphone': word['us_phone'],
                'ukspeech': word['uk_speech'],
                'usspeech': word['us_speech'],
                'translations': word.get('translations', []),
                'sentences': word.get('sentences', []),
                'phrases': word.get('phrases', []),
            }
            results.append(formatted_word)
    
    return success_response({
        'words': results,
        'total': len(results)
    })


@api_v1.route('/search', methods=['GET'])
@api_v1.route('/words/search', methods=['GET'])
def search_words():
    """
    搜索单词
    ---
    tags:
      - 单词学习
    summary: 搜索单词
    description: 根据关键词搜索单词
    parameters:
      - name: keyword
        in: query
        type: string
        required: true
        description: 搜索关键词
      - name: book_id
        in: query
        type: string
        required: false
        description: 限定词书ID
      - name: category
        in: query
        type: string
        required: false
        description: 限定分类
      - name: limit
        in: query
        type: integer
        required: false
        default: 50
        description: 返回数量限制
    responses:
      200:
        description: 成功
      400:
        description: 搜索关键词不能为空
    """
    keyword = request.args.get('keyword', '').strip()
    book_id = request.args.get('book_id')
    category = request.args.get('category')
    limit = request.args.get('limit', 50, type=int)
    
    if not keyword:
        return error_response(400, '搜索关键词不能为空')
    
    # 从数据库搜索单词
    import time
    start_time = time.time()
    
    results = WordService.search_words(keyword, book_id, category, limit)
    
    search_time = time.time() - start_time
    
    # 格式化结果
    formatted_results = []
    for word in results:
        formatted_results.append({
            'bookId': word['book_id'],
            'bookTitle': word.get('bookTitle', ''),
            'wordRank': word['word_rank'],
            'word': word['head_word'],
            'usphone': word['us_phone'],
            'translation': word.get('translation', ''),
            'category': word.get('category', ''),
            'grade': word.get('grade', 0)
        })
    
    return success_response({
        'keyword': keyword,
        'results': formatted_results,
        'total': len(formatted_results),
        'searchTime': round(search_time, 3)
    })


@api_v1.route('/words/recommended', methods=['GET'])
@api_v1.route('/words/daily-recommend', methods=['GET'])
def get_daily_recommend():
    """
    获取今日推荐单词
    ---
    tags:
      - 单词学习
    summary: 获取今日推荐单词
    parameters:
      - name: count
        in: query
        type: integer
        required: false
        default: 10
        description: 推荐数量
    responses:
      200:
        description: 成功
    """
    count = request.args.get('count', request.args.get('maxCount', 10, type=int), type=int)
    count = max(1, min(count, 50))
    book_id = request.args.get('book_id') or request.args.get('bookId')
    words = []
    if book_id:
        words = WordService.get_words_paginated(book_id, page=1, page_size=count)['words']
    return success_response({
        'date': datetime.utcnow().strftime('%Y-%m-%d'),
        'recommendReason': '基于您的学习进度和薄弱点推荐',
        'words': words,
        'total': len(words)
    })
