"""
激活码 API
"""
from flask import Blueprint, request
from flask_jwt_extended import jwt_required, get_jwt_identity
from services.activation_service import ActivationService
from utils.response import success_response, error_response

activation_bp = Blueprint('activation', __name__)

@activation_bp.route('/activate', methods=['POST'])
@jwt_required()
def activate():
    """激活激活码"""
    data = request.get_json()
    # 兼容多种参数名
    code = data.get('code') or data.get('activation_code')
    device_id = data.get('device_id', 'unknown')
    
    if not code:
        return error_response(400, "请输入激活码")
    
    user_id = get_jwt_identity()
    ip_address = request.remote_addr
    
    success, message, result_data = ActivationService.activate(code, user_id, device_id, ip_address)
    
    if success:
        return success_response(result_data, message)
    else:
        return error_response(400, message)

@activation_bp.route('/generate_test', methods=['POST'])
def generate_test():
    """生成测试激活码 (生产环境应禁用)"""
    data = request.get_json()
    plan_type = data.get('plan_type', 'month')
    duration_days = data.get('duration_days', 30)
    quantity = data.get('quantity', 1)
    
    codes = ActivationService.generate_codes("test_order", plan_type, quantity, duration_days)
    return success_response({"codes": codes}, "生成成功")
