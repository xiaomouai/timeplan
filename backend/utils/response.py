"""
API响应封装
"""
from flask import jsonify
import uuid


def generate_request_id():
    """生成请求ID"""
    return uuid.uuid4().hex[:24]


def success_response(data=None, msg='success', code=200, **kwargs):
    """
    成功响应
    支持参数:
    - data: 返回的数据
    - msg/message: 提示信息
    - code/status_code: HTTP 状态码
    """
    # 处理参数别名
    msg = kwargs.get('message', msg)
    code = kwargs.get('status_code', code)
    
    response = {
        'success': True,
        'code': code,
        'message': msg,
        'msg': msg,  # 兼容旧版本
        'data': data if data is not None else {},
        'request_id': generate_request_id()
    }
    return jsonify(response), code


def error_response(code=400, msg='error', data=None, **kwargs):
    """
    错误响应
    支持参数:
    - code/status_code: HTTP 状态码
    - msg/message: 错误信息
    - data: 附加数据
    """
    # 处理参数别名
    msg = kwargs.get('message', msg)
    code = kwargs.get('status_code', code)
    
    response = {
        'success': False,
        'code': code,
        'message': msg,
        'msg': msg,  # 兼容旧版本
        'data': data if data is not None else {},
        'request_id': generate_request_id()
    }
    return jsonify(response), code


def paginated_response(items, total, page, page_size, msg='success'):
    """分页响应"""
    data = {
        'items': items,
        'total': total,
        'page': page,
        'page_size': page_size,
        'total_pages': (total + page_size - 1) // page_size
    }
    return success_response(data, msg)

