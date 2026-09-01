"""
签到 API
"""
from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from services.checkin_service import CheckinService
from utils.response import success_response, error_response

checkin_bp = Blueprint('checkin', __name__)
checkin_service = CheckinService()

@checkin_bp.route('', methods=['POST'])
@jwt_required()
def do_checkin():
    """
    执行签到
    ---
    tags:
      - 签到系统
    security:
      - Bearer: []
    responses:
      200:
        description: 签到结果
    """
    user_id = get_jwt_identity()
    result = checkin_service.do_checkin(user_id)
    
    if result.get('success'):
        # 移除 result 中的 success 和 message，将其作为 success_response 的参数
        message = result.pop('message', '签到成功')
        result.pop('success', None)
        return success_response(result, msg=message)
    else:
        return error_response(400, result.get('message', '签到失败'))

@checkin_bp.route('/page', methods=['GET'])
@jwt_required()
def get_checkin_page():
    """
    获取签到页面数据
    ---
    tags:
      - 签到系统
    security:
      - Bearer: []
    parameters:
      - name: year
        in: query
        type: integer
      - name: month
        in: query
        type: integer
    responses:
      200:
        description: 页面数据
    """
    user_id = get_jwt_identity()
    year = request.args.get('year', type=int)
    month = request.args.get('month', type=int)
    
    data = checkin_service.get_checkin_page_data(user_id, year, month)
    
    if 'error' in data:
        return error_response(400, data['error'])
    
    return success_response(data)
