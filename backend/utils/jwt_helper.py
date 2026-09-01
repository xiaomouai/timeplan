"""
JWT工具类
"""
import jwt
from datetime import datetime, timedelta
from functools import wraps
from flask import request, jsonify


# JWT配置
SECRET_KEY = 'your-secret-key-change-in-production'
ALGORITHM = 'HS256'
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24 * 7  # 7天
REFRESH_TOKEN_EXPIRE_MINUTES = 60 * 24 * 30  # 30天


def create_access_token(user_id, expires_delta=None):
    """创建访问令牌"""
    if expires_delta is None:
        expires_delta = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    
    expire = datetime.utcnow() + expires_delta
    payload = {
        'user_id': user_id,
        'exp': expire,
        'type': 'access'
    }
    
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)


def create_refresh_token(user_id, expires_delta=None):
    """创建刷新令牌"""
    if expires_delta is None:
        expires_delta = timedelta(minutes=REFRESH_TOKEN_EXPIRE_MINUTES)
    
    expire = datetime.utcnow() + expires_delta
    payload = {
        'user_id': user_id,
        'exp': expire,
        'type': 'refresh'
    }
    
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)


def decode_token(token):
    """解码令牌"""
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        return payload
    except jwt.ExpiredSignatureError:
        return None
    except jwt.InvalidTokenError:
        return None


def get_current_user_id():
    """从请求头获取当前用户ID"""
    auth_header = request.headers.get('Authorization')
    if not auth_header:
        return None
    
    try:
        token = auth_header.split(' ')[1]  # Bearer <token>
        payload = decode_token(token)
        if payload and payload.get('type') == 'access':
            return payload.get('user_id')
    except:
        pass
    
    return None


def require_auth(f):
    """需要认证的装饰器"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        user_id = get_current_user_id()
        if not user_id:
            return jsonify({
                'success': False,
                'error': '未授权，请先登录'
            }), 401
        
        # 将user_id传递给路由函数
        return f(user_id=user_id, *args, **kwargs)
    
    return decorated_function


def optional_auth(f):
    """可选认证的装饰器"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        user_id = get_current_user_id()
        return f(user_id=user_id, *args, **kwargs)
    
    return decorated_function
