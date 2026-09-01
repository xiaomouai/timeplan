"""
闯关模块 API
提供闯关题目生成、答题、成绩查询等接口
"""
from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from services.challenge_service import ChallengeService
from utils.response import success_response, error_response
from middleware.membership_middleware import vip_optional

# 创建闯关蓝图（不带前缀，由 api_v1 统一管理）
bp = Blueprint('challenge', __name__)


@bp.route('/create', methods=['POST'])
@jwt_required()
@vip_optional
def create_challenge():
    """
    创建闯关任务
    ---
    tags:
      - 闯关模块
    security:
      - Bearer: []
    parameters:
      - name: body
        in: body
        required: true
        schema:
          type: object
          required:
            - word_book_id
          properties:
            word_book_id:
              type: integer
              description: 词书ID
            difficulty:
              type: string
              description: 难度 (easy/medium/hard)
              default: easy
            question_type:
              type: string
              description: 题型 (choose_meaning/choose_word/spell_word/listen_choose)
              default: choose_meaning
    responses:
      200:
        description: 闯关创建成功
    """
    user_id = get_jwt_identity()
    data = request.get_json()
    
    word_book_id = data.get('word_book_id')
    difficulty = data.get('difficulty', 'easy')
    question_type = data.get('question_type', 'choose_meaning')
    
    if not word_book_id:
        return error_response(message='词书ID不能为空', code=400)
    
    # 非会员只能玩简单难度
    from flask import g
    if not g.is_vip and difficulty != 'easy':
        return error_response(message='非会员只能挑战简单难度，升级会员解锁更多难度', code=403)
    
    result = ChallengeService.create_challenge(
        user_id=user_id,
        word_book_id=word_book_id,
        difficulty=difficulty,
        question_type=question_type
    )
    
    if not result:
        return error_response(message='创建闯关失败', code=500)
    
    return success_response(data=result, message='闯关创建成功')


@bp.route('/<int:challenge_id>/submit', methods=['POST'])
@jwt_required()
def submit_answer(challenge_id):
    """
    提交答案
    ---
    tags:
      - 闯关模块
    security:
      - Bearer: []
    parameters:
      - name: challenge_id
        in: path
        type: integer
        required: true
      - name: body
        in: body
        required: true
        schema:
          type: object
          required:
            - word_id
            - user_answer
            - is_correct
          properties:
            word_id:
              type: integer
              description: 单词ID
            user_answer:
              type: string
              description: 用户答案
            is_correct:
              type: boolean
              description: 是否正确
            time_spent:
              type: integer
              description: 答题耗时（秒）
    responses:
      200:
        description: 提交成功
    """
    data = request.get_json()
    
    word_id = data.get('word_id')
    user_answer = data.get('user_answer')
    is_correct = data.get('is_correct')
    time_spent = data.get('time_spent', 0)
    
    if not all([word_id, user_answer is not None, is_correct is not None]):
        return error_response(message='参数不完整', code=400)
    
    success = ChallengeService.submit_answer(
        challenge_id=challenge_id,
        word_id=word_id,
        user_answer=user_answer,
        is_correct=is_correct,
        time_spent=time_spent
    )
    
    if not success:
        return error_response(message='提交答案失败', code=500)
    
    return success_response(message='提交成功')


@bp.route('/<int:challenge_id>/finish', methods=['POST'])
@jwt_required()
def finish_challenge(challenge_id):
    """
    完成闯关
    ---
    tags:
      - 闯关模块
    security:
      - Bearer: []
    parameters:
      - name: challenge_id
        in: path
        type: integer
        required: true
    responses:
      200:
        description: 闯关完成
    """
    result = ChallengeService.finish_challenge(challenge_id)
    
    if not result:
        return error_response(message='完成闯关失败', code=500)
    
    return success_response(data=result, message='闯关完成')


@bp.route('/history', methods=['GET'])
@jwt_required()
def get_history():
    """
    获取闯关历史
    ---
    tags:
      - 闯关模块
    security:
      - Bearer: []
    parameters:
      - name: page
        in: query
        type: integer
        default: 1
      - name: per_page
        in: query
        type: integer
        default: 20
    responses:
      200:
        description: 成功返回闯关历史
    """
    user_id = get_jwt_identity()
    page = request.args.get('page', 1, type=int)
    per_page = request.args.get('per_page', 20, type=int)
    
    result = ChallengeService.get_challenge_history(user_id, page, per_page)
    
    return success_response(data=result, message='获取闯关历史成功')


@bp.route('/stats', methods=['GET'])
@jwt_required()
def get_stats():
    """
    获取闯关统计
    ---
    tags:
      - 闯关模块
    security:
      - Bearer: []
    responses:
      200:
        description: 成功返回闯关统计
    """
    user_id = get_jwt_identity()
    stats = ChallengeService.get_challenge_stats(user_id)
    
    return success_response(data=stats, message='获取闯关统计成功')


@bp.route('/types', methods=['GET'])
def get_question_types():
    """
    获取题型列表
    ---
    tags:
      - 闯关模块
    responses:
      200:
        description: 成功返回题型列表
    """
    types = []
    for key, value in ChallengeService.QUESTION_TYPES.items():
        types.append({
            'type': key,
            'name': value['name'],
            'options_count': value['options_count']
        })
    
    return success_response(data=types, message='获取题型列表成功')


@bp.route('/difficulties', methods=['GET'])
def get_difficulties():
    """
    获取难度列表
    ---
    tags:
      - 闯关模块
    responses:
      200:
        description: 成功返回难度列表
    """
    difficulties = []
    for key, value in ChallengeService.DIFFICULTY_CONFIG.items():
        difficulties.append({
            'difficulty': key,
            'name': value['name'],
            'questions_count': value['questions_count'],
            'pass_score': value['pass_score']
        })
    
    return success_response(data=difficulties, message='获取难度列表成功')
