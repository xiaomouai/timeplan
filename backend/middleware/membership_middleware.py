"""
会员权限中间件
用于验证用户会员权限
"""
from functools import wraps
from flask import jsonify
from flask_jwt_extended import get_jwt_identity, verify_jwt_in_request
from services.membership_service import MembershipService


def membership_required(membership_types=None):
    """
    会员权限装饰器
    :param membership_types: 允许的会员类型列表，如 ['month', 'season', 'year', 'lifetime']
                            如果为None，则只要是有效会员即可
    """
    def decorator(fn):
        @wraps(fn)
        def wrapper(*args, **kwargs):
            # 验证JWT Token
            verify_jwt_in_request()
            user_id = get_jwt_identity()
            
            # 检查会员是否有效
            if not MembershipService.check_membership_valid(user_id):
                return jsonify({
                    'code': 403,
                    'message': '需要会员权限',
                    'data': None
                }), 403
            
            # 如果指定了会员类型，检查是否符合
            if membership_types:
                user_membership_type = MembershipService.get_membership_type(user_id)
                if user_membership_type not in membership_types:
                    return jsonify({
                        'code': 403,
                        'message': f'需要 {",".join(membership_types)} 会员权限',
                        'data': None
                    }), 403
            
            return fn(*args, **kwargs)
        return wrapper
    return decorator


def benefit_required(benefit_type: str):
    """
    权益验证装饰器
    :param benefit_type: 权益类型，如 'unlimited_dictation', 'ai_tutor', 'no_ads'
    """
    def decorator(fn):
        @wraps(fn)
        def wrapper(*args, **kwargs):
            # 验证JWT Token
            verify_jwt_in_request()
            user_id = get_jwt_identity()
            
            # 检查是否有该权益
            if not MembershipService.check_benefit_access(user_id, benefit_type):
                return jsonify({
                    'code': 403,
                    'message': f'需要 {benefit_type} 权益',
                    'data': None
                }), 403
            
            return fn(*args, **kwargs)
        return wrapper
    return decorator


def vip_optional(fn):
    """
    可选会员装饰器
    会在request中注入 is_vip 和 membership_type 信息，但不强制要求会员
    """
    @wraps(fn)
    def wrapper(*args, **kwargs):
        from flask import g
        
        try:
            verify_jwt_in_request()
            user_id = get_jwt_identity()
            
            # 注入会员信息到 g 对象
            g.is_vip = MembershipService.check_membership_valid(user_id)
            g.membership_type = MembershipService.get_membership_type(user_id)
        except:
            g.is_vip = False
            g.membership_type = 'free'
        
        return fn(*args, **kwargs)
    return wrapper
