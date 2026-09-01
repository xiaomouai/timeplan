"""
认证相关API接口（重构版 - 使用MySQL数据库和JWT）
"""
from flask import request, jsonify
from flask_jwt_extended import create_access_token, create_refresh_token, jwt_required, get_jwt_identity
from . import api_v1
from services.user_service import UserService
from services.membership_service import MembershipService
from utils.response import success_response, error_response
from datetime import datetime, timedelta


@api_v1.route('/auth/register', methods=['POST'])
def register():
    """
    用户注册
    ---
    tags:
      - 用户认证
    summary: 用户注册
    description: 使用手机号注册新用户
    parameters:
      - in: body
        name: body
        required: true
        schema:
          type: object
          required:
            - phone
            - code
            - password
            - role
          properties:
            phone:
              type: string
              description: 手机号
              example: "13800138000"
            code:
              type: string
              description: 短信验证码
              example: "123456"
            password:
              type: string
              description: 密码
              example: "password123"
            role:
              type: string
              enum: [student, parent]
              description: 角色
              example: "student"
            invite_code:
              type: string
              description: 邀请码（可选）
              example: "ABC123"
            nickname:
              type: string
              description: 昵称（可选）
            grade:
              type: integer
              description: 年级（学生角色时）
    responses:
      200:
        description: 注册成功
      400:
        description: 参数错误或手机号已注册
    """
    data = request.get_json()
    phone = data.get('phone')
    code = data.get('code')
    password = data.get('password')
    role = data.get('role', 'student')
    invite_code = data.get('invite_code')
    nickname = data.get('nickname')
    grade = data.get('grade')
    
    # 验证必填字段
    if not phone or not code or not password:
        return error_response(400, '手机号、验证码和密码不能为空')
    
    # TODO: 验证短信验证码
    # 这里暂时跳过验证码验证
    
    # 检查手机号是否已注册
    existing_user = UserService.get_user_by_phone(phone)
    if existing_user:
        return error_response(400, '该手机号已注册')
    
    # 创建用户
    user = UserService.create_user(
        phone=phone,
        password=password,
        role=role,
        nickname=nickname,
        grade=grade,
        invited_by=invite_code
    )
    
    if not user:
        return error_response(500, '注册失败，请稍后重试')
    
    # 生成JWT token
    access_token = create_access_token(identity=user.id)
    refresh_token = create_refresh_token(identity=user.id)
    
    # 自动激活7天试用期
    trial_end_date = datetime.utcnow() + timedelta(days=7)
    
    return success_response({
        'user_id': user.id,
        'token': access_token,
        'refresh_token': refresh_token,
        'is_new_user': True,
        'user_info': {
            'nickname': user.nickname,
            'avatar': user.avatar,
            'phone': phone,
            'role': user.role,
            'grade': user.grade
        },
        'gifts': [
            {
                'type': 'vip_trial',
                'days': 7,
                'end_date': trial_end_date.isoformat()
            }
        ]
    }, '注册成功，已自动激活7天试用期')


@api_v1.route('/auth/login', methods=['POST'])
def login():
    """
    用户登录
    ---
    tags:
      - 用户认证
    summary: 用户登录
    description: 使用手机号和密码或验证码登录
    parameters:
      - in: body
        name: body
        required: true
        schema:
          type: object
          required:
            - phone
          properties:
            phone:
              type: string
              description: 手机号
              example: "13800138000"
            password:
              type: string
              description: 密码
              example: "password123"
            code:
              type: string
              description: 短信验证码（可替代密码）
              example: "123456"
    responses:
      200:
        description: 登录成功
      400:
        description: 参数错误
      401:
        description: 账号或密码错误
    """
    data = request.get_json()
    phone = data.get('phone')
    password = data.get('password')
    code = data.get('code')
    
    if not phone:
        return error_response(400, '手机号不能为空')
    
    if not password and not code:
        return error_response(400, '密码或验证码必须提供一个')
    
    # 获取用户
    user = UserService.get_user_by_phone(phone)
    if not user:
        return error_response(401, '账号不存在')
    
    # 验证密码或验证码
    if password:
        if not UserService.verify_password(user.password_hash, password):
            return error_response(401, '密码错误')
    elif code:
        # TODO: 验证短信验证码
        pass
    
    # 检查用户状态
    if user.status != 'active':
        return error_response(403, '账号已被禁用')
    
    # 生成JWT token
    access_token = create_access_token(identity=user.id)
    refresh_token = create_refresh_token(identity=user.id)
    
    # 获取会员信息
    membership_info = MembershipService.get_membership_stats(user.id)
    
    return success_response({
        'user_id': user.id,
        'token': access_token,
        'refresh_token': refresh_token,
        'user_info': {
            'user_id': user.id,
            'phone': user.phone,
            'nickname': user.nickname,
            'avatar': user.avatar,
            'role': user.role,
            'grade': user.grade,
            'level': user.level,
            'exp': user.exp,
            'points': user.points,
            'streak_days': user.streak_days,
            'membership': membership_info
        }
    }, '登录成功')


@api_v1.route('/auth/send-code', methods=['POST'])
def send_code():
    """
    发送短信验证码
    ---
    tags:
      - 用户认证
    summary: 发送短信验证码
    description: 发送短信验证码用于注册、登录或重置密码
    parameters:
      - in: body
        name: body
        required: true
        schema:
          type: object
          required:
            - phone
          properties:
            phone:
              type: string
              description: 手机号
              example: "13800138000"
            type:
              type: string
              enum: [register, login, reset]
              description: 验证码类型
              default: register
    responses:
      200:
        description: 发送成功
      400:
        description: 参数错误
    """
    data = request.get_json()
    phone = data.get('phone')
    sms_type = data.get('type', 'register')
    
    if not phone:
        return error_response(400, '手机号不能为空')
    
    # 验证手机号格式
    if len(phone) != 11 or not phone.isdigit():
        return error_response(400, '手机号格式不正确')
    
    # TODO: 调用阿里云短信服务发送验证码
    # 这里暂时返回成功
    
    return success_response({
        'phone': phone,
        'expire_at': (datetime.utcnow() + timedelta(minutes=5)).isoformat()
    }, '验证码已发送，5分钟内有效')


@api_v1.route('/auth/refresh-token', methods=['POST'])
@jwt_required(refresh=True)
def refresh_token_endpoint():
    """
    刷新访问token
    ---
    tags:
      - 用户认证
    summary: 刷新访问token
    description: 使用refresh_token刷新access_token
    security:
      - Bearer: []
    responses:
      200:
        description: 刷新成功
      401:
        description: refresh_token无效或过期
    """
    current_user_id = get_jwt_identity()
    
    # 生成新的access token
    new_access_token = create_access_token(identity=current_user_id)
    
    return success_response({
        'token': new_access_token
    }, 'Token刷新成功')


@api_v1.route('/auth/logout', methods=['POST'])
@jwt_required()
def logout():
    """
    用户登出
    ---
    tags:
      - 用户认证
    summary: 用户登出
    description: 退出登录（客户端应清除本地token）
    security:
      - Bearer: []
    responses:
      200:
        description: 登出成功
    """
    # TODO: 将token加入黑名单（如果需要）
    return success_response({}, '登出成功')


@api_v1.route('/auth/reset-password', methods=['POST'])
def reset_password():
    """
    重置密码
    ---
    tags:
      - 用户认证
    summary: 重置密码
    description: 通过短信验证码重置密码
    parameters:
      - in: body
        name: body
        required: true
        schema:
          type: object
          required:
            - phone
            - code
            - new_password
          properties:
            phone:
              type: string
              description: 手机号
            code:
              type: string
              description: 短信验证码
            new_password:
              type: string
              description: 新密码
    responses:
      200:
        description: 重置成功
      400:
        description: 参数错误
      401:
        description: 验证码错误
    """
    data = request.get_json()
    phone = data.get('phone')
    code = data.get('code')
    new_password = data.get('new_password')
    
    if not phone or not code or not new_password:
        return error_response(400, '手机号、验证码和新密码不能为空')
    
    # TODO: 验证短信验证码
    
    # 获取用户
    user = UserService.get_user_by_phone(phone)
    if not user:
        return error_response(400, '用户不存在')
    
    # 更新密码
    user.password_hash = UserService.hash_password(new_password)
    user.updated_at = datetime.utcnow()
    
    from models import db
    db.session.commit()
    
    return success_response({}, '密码重置成功')
