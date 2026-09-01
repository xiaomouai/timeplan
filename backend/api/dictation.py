"""
听写模块 API
提供听写任务创建、答题、成绩查询等接口
"""
from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from services.dictation_service import DictationService
from utils.response import success_response, error_response
from middleware.membership_middleware import vip_optional

bp = Blueprint('dictation', __name__)


@bp.route('/create', methods=['POST'])
@jwt_required()
@vip_optional
def create_dictation():
    """
    创建听写任务
    ---
    tags:
      - 听写模块
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
            mode:
              type: string
              description: 听写模式 (sequential/random/wrong_words)
              default: sequential
            word_count:
              type: integer
              description: 听写单词数量
              default: 20
            word_range:
              type: string
              description: 单词范围，如 "1-100"
    responses:
      200:
        description: 听写创建成功
    """
    user_id = get_jwt_identity()
    data = request.get_json()
    
    word_book_id = data.get('word_book_id')
    mode = data.get('mode', 'sequential')
    word_count = data.get('word_count', 20)
    word_range = data.get('word_range')
    
    if not word_book_id:
        return error_response(message='词书ID不能为空', code=400)
    
    # 非会员限制听写次数（这里简化处理，实际可以查数据库）
    from flask import g
    if not g.is_vip and word_count > 20:
        return error_response(message='非会员每次最多听写20个单词，升级会员解锁更多', code=403)
    
    result = DictationService.create_dictation(
        user_id=user_id,
        word_book_id=word_book_id,
        mode=mode,
        word_count=word_count,
        word_range=word_range
    )
    
    if not result:
        return error_response(message='创建听写失败', code=500)
    
    return success_response(data=result, message='听写创建成功')


@bp.route('/<int:dictation_id>/submit', methods=['POST'])
@jwt_required()
def submit_answer(dictation_id):
    """
    提交听写答案
    ---
    tags:
      - 听写模块
    security:
      - Bearer: []
    parameters:
      - name: dictation_id
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
          properties:
            word_id:
              type: integer
              description: 单词ID
            user_answer:
              type: string
              description: 用户答案
    responses:
      200:
        description: 提交成功
    """
    data = request.get_json()
    
    word_id = data.get('word_id')
    user_answer = data.get('user_answer', '')
    
    if not word_id:
        return error_response(message='单词ID不能为空', code=400)
    
    result = DictationService.submit_answer(
        dictation_id=dictation_id,
        word_id=word_id,
        user_answer=user_answer
    )
    
    if not result.get('success'):
        return error_response(message=result.get('message', '提交失败'), code=500)
    
    return success_response(data=result, message='提交成功')


@bp.route('/<int:dictation_id>/finish', methods=['POST'])
@jwt_required()
def finish_dictation(dictation_id):
    """
    完成听写
    ---
    tags:
      - 听写模块
    security:
      - Bearer: []
    parameters:
      - name: dictation_id
        in: path
        type: integer
        required: true
    responses:
      200:
        description: 听写完成
    """
    result = DictationService.finish_dictation(dictation_id)
    
    if not result:
        return error_response(message='完成听写失败', code=500)
    
    return success_response(data=result, message='听写完成')


@bp.route('/<int:dictation_id>', methods=['GET'])
@jwt_required()
def get_dictation_detail(dictation_id):
    """
    获取听写详情
    ---
    tags:
      - 听写模块
    security:
      - Bearer: []
    parameters:
      - name: dictation_id
        in: path
        type: integer
        required: true
    responses:
      200:
        description: 成功返回听写详情
    """
    user_id = get_jwt_identity()
    result = DictationService.get_dictation_detail(dictation_id, user_id)
    
    if not result:
        return error_response(message='听写不存在', code=404)
    
    return success_response(data=result, message='获取听写详情成功')


@bp.route('/history', methods=['GET'])
@jwt_required()
def get_history():
    """
    获取听写历史
    ---
    tags:
      - 听写模块
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
        description: 成功返回听写历史
    """
    user_id = get_jwt_identity()
    page = request.args.get('page', 1, type=int)
    per_page = request.args.get('per_page', 20, type=int)
    
    result = DictationService.get_dictation_history(user_id, page, per_page)
    
    return success_response(data=result, message='获取听写历史成功')


@bp.route('/stats', methods=['GET'])
@jwt_required()
def get_stats():
    """
    获取听写统计
    ---
    tags:
      - 听写模块
    security:
      - Bearer: []
    responses:
      200:
        description: 成功返回听写统计
    """
    user_id = get_jwt_identity()
    stats = DictationService.get_dictation_stats(user_id)
    
    return success_response(data=stats, message='获取听写统计成功')


@bp.route('/wrong-words', methods=['GET'])
@jwt_required()
def get_wrong_words():
    """
    获取错词本
    ---
    tags:
      - 听写模块
    security:
      - Bearer: []
    parameters:
      - name: word_book_id
        in: query
        type: integer
        description: 词书ID（可选，不传则返回所有错词）
    responses:
      200:
        description: 成功返回错词本
    """
    user_id = get_jwt_identity()
    word_book_id = request.args.get('word_book_id', type=int)
    
    wrong_words = DictationService.get_wrong_words(user_id, word_book_id)
    
    return success_response(data=wrong_words, message='获取错词本成功')


@bp.route('/modes', methods=['GET'])
def get_modes():
    """
    获取听写模式列表
    ---
    tags:
      - 听写模块
    responses:
      200:
        description: 成功返回听写模式列表
    """
    modes = []
    for key, value in DictationService.MODES.items():
        modes.append({
            'mode': key,
            'name': value['name'],
            'description': value['description']
        })
    
    return success_response(data=modes, message='获取听写模式列表成功')
