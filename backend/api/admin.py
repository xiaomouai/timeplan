"""
后台管理 API
提供用户管理、订单管理、版本管理和报表功能
"""
from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from datetime import datetime
from services.user_service import UserService
from services.admin_service import AdminService
from api.version import DEFAULT_APP_VERSION, DEFAULT_API_VERSION
from models.version_model import AppVersion, ApiVersion
from extensions import db
from utils.response import success_response, error_response
from functools import wraps
from models.user_models import User

admin_bp = Blueprint('admin', __name__)

def admin_required(f):
    @wraps(f)
    @jwt_required()
    def decorated_function(*args, **kwargs):
        user_id = get_jwt_identity()
        user = User.query.get(user_id)
        if not user or user.role != 'admin':
            return error_response(403, "需要管理员权限")
        return f(*args, **kwargs)
    return decorated_function

@admin_bp.route('/login', methods=['POST'])
def admin_login():
    """管理员登录"""
    data = request.get_json()
    phone = data.get('phone')
    password = data.get('password')
    
    if not phone or not password:
        return error_response(400, "手机号和密码不能为空")
        
    user = UserService.get_user_by_phone(phone)
    if not user or user.role != 'admin':
        return error_response(401, "管理员账号不存在")
        
    if not UserService.verify_password(user.password_hash, password):
        return error_response(401, "密码错误")
        
    from flask_jwt_extended import create_access_token
    access_token = create_access_token(identity=user.id)
    
    return success_response({
        'token': access_token,
        'user_info': user.to_dict()
    }, "登录成功")

@admin_bp.route('/dashboard', methods=['GET'])
@admin_required
def get_dashboard():
    """获取仪表盘数据"""
    stats = AdminService.get_dashboard_stats()
    return success_response(stats)

@admin_bp.route('/users', methods=['GET'])
@admin_required
def list_users():
    """获取用户列表"""
    page = request.args.get('page', 1, type=int)
    per_page = request.args.get('per_page', 10, type=int)
    search = request.args.get('search')
    
    users_data = AdminService.list_users(page, per_page, search)
    return success_response(users_data)

@admin_bp.route('/orders', methods=['GET'])
@admin_required
def list_orders():
    """获取订单列表"""
    page = request.args.get('page', 1, type=int)
    per_page = request.args.get('per_page', 10, type=int)
    status = request.args.get('status')
    
    orders_data = AdminService.list_orders(page, per_page, status)
    return success_response(orders_data)

@admin_bp.route('/versions', methods=['GET'])
@admin_required
def get_versions():
    """获取版本信息"""
    platform = request.args.get('platform', 'android')
    
    app_ver = AppVersion.query.filter_by(platform=platform, is_latest=True).first()
    api_ver = ApiVersion.query.filter_by(is_active=True).order_by(ApiVersion.id.desc()).first()
    
    app_data = app_ver.to_dict() if app_ver else DEFAULT_APP_VERSION
    api_data = api_ver.to_dict() if api_ver else DEFAULT_API_VERSION
    
    # 获取历史版本
    history = AppVersion.query.filter_by(platform=platform).order_by(AppVersion.build_number.desc()).limit(10).all()
    history_data = [v.to_dict() for v in history]
    
    return success_response({
        'app_versions': {
            'latest': app_data,
            'history': history_data
        },
        'api_version': api_data
    })

@admin_bp.route('/versions/app', methods=['POST'])
@admin_required
def update_app_version():
    """添加/更新应用版本信息"""
    data = request.get_json()
    if not data or 'version' not in data or 'build_number' not in data:
        return error_response(400, "版本号和构建号不能为空")
    
    new_version = AdminService.add_app_version(data)
    return success_response(new_version.to_dict(), "应用版本信息更新成功")

@admin_bp.route('/versions/api', methods=['POST'])
@admin_required
def update_api_version():
    """更新 API 版本信息"""
    data = request.get_json()
    if not data or 'version' not in data:
        return error_response(400, "版本信息不能为空")
    
    new_api = AdminService.add_api_version(data)
    return success_response(new_api.to_dict(), "API 版本信息更新成功")

@admin_bp.route('/reports/user_growth', methods=['GET'])
@admin_required
def user_growth_report():
    """用户增长报表"""
    days = request.args.get('days', 7, type=int)
    data = AdminService.get_user_growth_report(days)
    return success_response(data)

@admin_bp.route('/reports/revenue', methods=['GET'])
@admin_required
def revenue_report():
    """营收报表"""
    days = request.args.get('days', 7, type=int)
    data = AdminService.get_revenue_report(days)
    return success_response(data)

@admin_bp.route('/users/<user_id>/status', methods=['PUT'])
@admin_required
def update_user_status(user_id):
    """更新用户状态"""
    data = request.get_json()
    status = data.get('status')
    if status not in ['active', 'disabled']:
        return error_response(400, "无效的状态值")
        
    if AdminService.update_user_status(user_id, status):
        return success_response(None, "用户状态更新成功")
    return error_response(500, "用户状态更新失败")

@admin_bp.route('/orders/<int:order_id>/status', methods=['PUT'])
@admin_required
def update_order_status(order_id):
    """更新订单状态"""
    data = request.get_json()
    status = data.get('status')
    if status not in ['pending', 'paid', 'cancelled', 'refunded']:
        return error_response(400, "无效的订单状态")
        
    if AdminService.update_order_status(order_id, status):
        return success_response(None, "订单状态更新成功")
    return error_response(500, "订单状态更新失败")

@admin_bp.route('/activation_codes', methods=['GET'])
@admin_required
def list_activation_codes():
    """获取激活码列表"""
    page = request.args.get('page', 1, type=int)
    per_page = request.args.get('per_page', 10, type=int)
    search = request.args.get('search')
    
    codes_data = AdminService.list_activation_codes(page, per_page, search)
    return success_response(codes_data)

@admin_bp.route('/activation_codes', methods=['POST'])
@admin_required
def generate_activation_codes():
    """批量生成激活码"""
    data = request.get_json()
    if not data:
        return error_response(400, "数据不能为空")
    
    codes = AdminService.generate_activation_codes(data)
    return success_response({"codes": codes}, f"成功生成 {len(codes)} 个激活码")

@admin_bp.route('/activation_codes/<int:code_id>/status', methods=['PUT'])
@admin_required
def update_activation_code_status(code_id):
    """更新激活码状态"""
    data = request.get_json()
    status = data.get('status')
    if status is None:
        return error_response(400, "状态不能为空")
    
    if AdminService.update_activation_code_status(code_id, status):
        return success_response(None, "激活码状态更新成功")
    return error_response(500, "激活码状态更新失败")
