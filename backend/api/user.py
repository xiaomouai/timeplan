"""
用户相关API接口（重构版 - 使用MySQL数据库）
"""
from flask import request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from . import api_v1
from services.user_service import UserService
from utils.response import success_response, error_response
from datetime import datetime


@api_v1.route('/user/profile', methods=['GET'])
@jwt_required()
def get_user_profile():
    """
    获取用户信息
    ---
    tags:
      - 用户中心
    summary: 获取用户信息
    description: 获取当前登录用户的详细信息
    security:
      - Bearer: []
    responses:
      200:
        description: 成功
      401:
        description: 未授权
    """
    current_user_id = get_jwt_identity()
    
    # 获取用户信息
    user = UserService.get_user_by_id(current_user_id)
    if not user:
        return error_response(404, '用户不存在')
    
    # 获取用户统计信息
    statistics = UserService.get_user_statistics(current_user_id)
    
    # TODO: 获取会员信息
    vip_info = {
        'level': 'free',
        'level_name': '免费用户',
        'expire_at': None,
        'is_active': False,
        'privileges': []
    }
    
    # TODO: 获取绑定的家长信息
    bind_parents = []
    
    return success_response({
        'user_id': user.id,
        'phone': user.phone[:3] + '****' + user.phone[-4:] if user.phone else '',
        'nickname': user.nickname,
        'avatar': user.avatar,
        'gender': user.gender,
        'birthday': user.birthday.isoformat() if user.birthday else None,
        'grade': user.grade,
        'role': user.role,
        'level': user.level,
        'exp': user.exp,
        'points': user.points,
        'streak_days': user.streak_days,
        'invite_code': user.invite_code,
        'textbook': {
            'id': 'PEPXiaoXue3_1',  # TODO: 从用户设置获取
            'name': '人教版',
            'grade': user.grade,
            'term': 1
        },
        'vip_info': vip_info,
        'bind_parents': bind_parents,
        'statistics': statistics,
        'created_at': user.created_at.isoformat() if user.created_at else None
    })


@api_v1.route('/user/learning_records', methods=['GET'])
@jwt_required()
def get_learning_records():
    """
    获取学习记录
    ---
    tags:
      - 用户中心
    summary: 获取学习记录
    description: 获取当前用户的所有单词学习记录
    security:
      - Bearer: []
    responses:
      200:
        description: 成功
    """
    current_user_id = get_jwt_identity()
    
    # TODO: 从数据库获取真实的学习记录
    # 目前返回模拟数据以支持前端运行
    records = []
    
    return success_response(records)


@api_v1.route('/user/learning_records/sync', methods=['POST'])
@jwt_required()
def sync_learning_records():
    """
    同步学习记录
    ---
    tags:
      - 用户中心
    summary: 同步学习记录
    description: 同步本地学习记录到服务器
    security:
      - Bearer: []
    parameters:
      - in: body
        name: body
        required: true
        schema:
          type: array
          items:
            type: object
    responses:
      200:
        description: 同步成功
    """
    current_user_id = get_jwt_identity()
    data = request.get_json()
    
    # TODO: 将同步过来的数据保存到数据库
    
    return success_response({}, '同步成功')


@api_v1.route('/user/profile', methods=['PUT'])
@jwt_required()
def update_user_profile():
    """
    更新用户信息
    ---
    tags:
      - 用户中心
    summary: 更新用户信息
    description: 更新当前用户的个人信息
    security:
      - Bearer: []
    parameters:
      - in: body
        name: body
        schema:
          type: object
          properties:
            nickname:
              type: string
              description: 昵称
            avatar:
              type: string
              description: 头像URL
            gender:
              type: string
              enum: [male, female, unknown]
              description: 性别
            birthday:
              type: string
              format: date
              description: 生日
            grade:
              type: integer
              description: 年级
    responses:
      200:
        description: 更新成功
      400:
        description: 参数错误
    """
    current_user_id = get_jwt_identity()
    data = request.get_json()
    
    # 更新用户信息
    updated_user = UserService.update_user(
        current_user_id,
        nickname=data.get('nickname'),
        avatar=data.get('avatar'),
        gender=data.get('gender'),
        birthday=data.get('birthday'),
        grade=data.get('grade')
    )
    
    if not updated_user:
        return error_response(500, '更新失败')
    
    return success_response({
        'user_id': updated_user.id,
        'nickname': updated_user.nickname,
        'avatar': updated_user.avatar,
        'gender': updated_user.gender,
        'birthday': updated_user.birthday.isoformat() if updated_user.birthday else None,
        'grade': updated_user.grade
    }, '更新成功')


@api_v1.route('/user/statistics', methods=['GET'])
@jwt_required()
def get_user_statistics():
    """
    获取用户学习统计
    ---
    tags:
      - 用户中心
    summary: 获取用户学习统计
    description: 获取用户的学习数据统计
    security:
      - Bearer: []
    responses:
      200:
        description: 成功
    """
    current_user_id = get_jwt_identity()
    
    statistics = UserService.get_user_statistics(current_user_id)
    
    return success_response(statistics)


@api_v1.route('/user/checkin', methods=['POST'])
@jwt_required()
def checkin():
    """
    用户签到
    ---
    tags:
      - 用户中心
    summary: 用户签到
    description: 每日签到获取积分奖励
    security:
      - Bearer: []
    responses:
      200:
        description: 签到成功
      400:
        description: 今日已签到
    """
    current_user_id = get_jwt_identity()
    
    result = UserService.checkin(current_user_id)
    
    if not result['success']:
        return error_response(400, result['message'])
    
    return success_response({
        'date': result['date'],
        'streak_days': result['streak_days'],
        'points_earned': result['points_earned'],
        'bonus_points': result.get('bonus_points', 0),
        'total_points': result['total_points'],
        'next_milestone': result.get('next_milestone', {})
    }, '签到成功')


@api_v1.route('/user/change-password', methods=['POST'])
@jwt_required()
def change_password():
    """
    修改密码
    ---
    tags:
      - 用户中心
    summary: 修改密码
    description: 用户修改自己的密码
    security:
      - Bearer: []
    parameters:
      - in: body
        name: body
        required: true
        schema:
          type: object
          required:
            - old_password
            - new_password
          properties:
            old_password:
              type: string
              description: 旧密码
            new_password:
              type: string
              description: 新密码
    responses:
      200:
        description: 修改成功
      400:
        description: 旧密码错误
    """
    current_user_id = get_jwt_identity()
    data = request.get_json()
    
    old_password = data.get('old_password')
    new_password = data.get('new_password')
    
    if not old_password or not new_password:
        return error_response(400, '旧密码和新密码不能为空')
    
    # 获取用户
    user = UserService.get_user_by_id(current_user_id)
    if not user:
        return error_response(404, '用户不存在')
    
    # 验证旧密码
    if not UserService.verify_password(user.password_hash, old_password):
        return error_response(400, '旧密码错误')
    
    # 更新密码
    user.password_hash = UserService.hash_password(new_password)
    user.updated_at = datetime.utcnow()
    
    from models import db
    db.session.commit()
    
    return success_response({}, '密码修改成功')


@api_v1.route('/user/bind-textbook', methods=['POST'])
@jwt_required()
def bind_textbook():
    """
    绑定教材
    ---
    tags:
      - 用户中心
    summary: 绑定教材
    description: 设置用户正在学习的教材
    security:
      - Bearer: []
    parameters:
      - in: body
        name: body
        required: true
        schema:
          type: object
          required:
            - textbook_id
          properties:
            textbook_id:
              type: string
              description: 教材ID
              example: "PEP"
            grade:
              type: integer
              description: 年级
              example: 3
            term:
              type: integer
              description: 学期
              example: 1
    responses:
      200:
        description: 绑定成功
    """
    current_user_id = get_jwt_identity()
    data = request.get_json()
    
    textbook_id = data.get('textbook_id')
    grade = data.get('grade')
    term = data.get('term')
    
    if not textbook_id:
        return error_response(400, '教材ID不能为空')
    
    # TODO: 保存用户教材设置到数据库
    # 目前返回成功
    
    return success_response({
        'textbook_id': textbook_id,
        'grade': grade,
        'term': term
    }, '教材绑定成功')


@api_v1.route('/user/settings', methods=['GET'])
@jwt_required()
def get_settings():
    """
    获取用户设置
    ---
    tags:
      - 用户中心
    summary: 获取用户设置
    security:
      - Bearer: []
    responses:
      200:
        description: 成功
    """
    current_user_id = get_jwt_identity()
    
    # TODO: 从数据库获取用户设置
    settings = {
        'notification': {
            'daily_reminder': True,
            'study_report': True,
            'achievement': True
        },
        'study': {
            'daily_goal_words': 20,
            'daily_goal_duration': 30,  # 分钟
            'pronunciation_mode': 'us',  # us/uk
            'auto_play': True
        },
        'privacy': {
            'show_in_leaderboard': True,
            'allow_parent_view': True
        }
    }
    
    return success_response(settings)


@api_v1.route('/user/settings', methods=['PUT'])
@jwt_required()
def update_settings():
    """
    更新用户设置
    ---
    tags:
      - 用户中心
    summary: 更新用户设置
    security:
      - Bearer: []
    parameters:
      - in: body
        name: body
        schema:
          type: object
    responses:
      200:
        description: 更新成功
    """
    current_user_id = get_jwt_identity()
    data = request.get_json()
    
    # TODO: 保存用户设置到数据库
    
    return success_response({}, '设置更新成功')


@api_v1.route('/user/word_status/<book_id>/<int:word_rank>', methods=['GET'])
@jwt_required()
def get_word_status(book_id, word_rank):
    """
    获取单词收藏和掌握状态
    """
    current_user_id = get_jwt_identity()
    
    # 目前返回模拟数据，后续对接数据库
    return success_response({
        'is_favorited': False,
        'is_mastered': False
    })


@api_v1.route('/user/favorites', methods=['POST'])
@jwt_required()
def add_to_favorites():
    """
    收藏单词
    """
    current_user_id = get_jwt_identity()
    data = request.get_json()
    
    # 目前返回成功
    return success_response({}, '收藏成功')


@api_v1.route('/user/favorites', methods=['DELETE'])
@jwt_required()
def remove_from_favorites():
    """
    取消收藏单词
    """
    current_user_id = get_jwt_identity()
    data = request.get_json()
    
    # 目前返回成功
    return success_response({}, '取消收藏成功')
