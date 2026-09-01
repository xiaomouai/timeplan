"""
会员信息相关API
"""
from flask import Blueprint, request
from flask_jwt_extended import jwt_required, get_jwt_identity
from services.membership_service import MembershipService
from services.activation_service import ActivationService
from utils.response import success_response, error_response
from models.membership_models import MembershipOrder

# 创建一个蓝图，注意变量名是 bp，与 __init__.py 中的导入对应
bp = Blueprint("membership", __name__)


@bp.route("/status", methods=["GET"])
@jwt_required()
def get_membership_status():
    """
    获取当前用户的会员状态
    ---
    tags:
      - 会员
    security:
      - Bearer: []
    responses:
      200:
        description: 成功获取会员状态
      401:
        description: 未授权
    """
    try:
        user_id = get_jwt_identity()
        if not user_id:
            return error_response(401, "用户未登录")

        membership_info = MembershipService.get_membership_stats(user_id)

        return success_response(membership_info)

    except Exception as e:
        return error_response(500, f"服务器错误: {str(e)}")


@bp.route("/check-feature", methods=["POST"])
@jwt_required()
def check_feature_access():
    """
    检查功能访问权限
    ---
    tags:
      - 会员
    security:
      - Bearer: []
    parameters:
      - name: body
        in: body
        required: true
        schema:
          type: object
          properties:
            feature:
              type: string
              description: 功能名称
    responses:
      200:
        description: 成功
    """
    try:
        user_id = get_jwt_identity()
        data = request.get_json(silent=True) or {}
        feature = data.get('feature')
        
        if not feature:
            return error_response(400, "请指定功能名称")
            
        has_access = MembershipService.check_benefit_access(user_id, feature)
        
        return success_response({"has_access": has_access})

    except Exception as e:
        return error_response(500, f"服务器错误: {str(e)}")


@bp.route("/order/create", methods=["POST"])
@jwt_required()
def create_membership_order():
    """
    创建会员订单
    ---
    tags:
      - 会员
    security:
      - Bearer: []
    responses:
      200:
        description: 订单创建成功
    """
    try:
        user_id = get_jwt_identity()
        data = request.get_json()
        plan_id = data.get('plan_id')
        payment_method = data.get('payment_method', 'wechat')
        
        if not plan_id:
            return error_response(400, "请选择套餐")
            
        order = MembershipService.create_order(user_id, plan_id, payment_method)
        
        if order:
            return success_response({
                "order_id": order.id,
                "order_no": order.order_no,
                "price": float(order.actual_price)
            })
        else:
            return error_response(400, "创建订单失败")

    except Exception as e:
        return error_response(500, f"服务器错误: {str(e)}")


@bp.route("/order/status", methods=["GET"])
@jwt_required()
def get_order_status():
    """
    获取订单状态
    ---
    tags:
      - 会员
    security:
      - Bearer: []
    parameters:
      - name: order_id
        in: query
        type: string
        required: true
    responses:
      200:
        description: 成功
    """
    try:
        order_id = request.args.get('order_id')
        if not order_id:
            return error_response(400, "缺少订单ID")
            
        user_id = get_jwt_identity()
        order = MembershipOrder.query.filter_by(id=order_id, user_id=user_id).first()
        if not order:
            return error_response(404, "订单不存在")
            
        return success_response({
            "order_id": order.id,
            "status": order.status,
            "paid_time": order.paid_time.isoformat() if order.paid_time else None
        })

    except Exception as e:
        return error_response(500, f"服务器错误: {str(e)}")


@bp.route("/order/test-pay", methods=["POST"])
@jwt_required()
def test_pay_order():
    """
    模拟支付订单 (测试用)
    """
    try:
        user_id = get_jwt_identity()
        data = request.get_json()
        order_id = data.get('order_id')
        
        if not order_id:
            return error_response(400, "缺少订单ID")
            
        # 验证订单属于该用户
        order = MembershipOrder.query.filter_by(id=order_id, user_id=user_id).first()
        if not order:
            return error_response(404, "订单不存在或无权操作")
            
        if order.status == 'paid':
            return success_response({"status": "paid"}, "订单已支付")
            
        # 激活会员
        success = MembershipService.activate_membership(order_id)
        
        if success:
            return success_response({"status": "paid"}, "模拟支付并激活成功")
        else:
            return error_response(400, "激活失败")
            
    except Exception as e:
        return error_response(500, f"服务器错误: {str(e)}")


@bp.route("/plans", methods=["GET"])
def get_membership_plans():
    """
    获取会员套餐列表
    ---
    tags:
      - 会员
    responses:
      200:
        description: 成功获取套餐列表
    """
    try:
        plans = MembershipService.get_all_plans()
        
        # 转换为列表字典
        plan_list = []
        for plan in plans:
            plan_list.append({
                "id": str(plan.id),
                "name": plan.name,
                "plan_type": plan.plan_type,
                "duration": f"{plan.duration_days}天" if plan.duration_days > 0 else "永久",
                "price": float(plan.price),
                "original_price": float(plan.original_price) if plan.original_price else 0.0,
                "description": plan.description,
                "features": plan.features.split(",") if plan.features else [],
                "recommended": plan.is_recommended,
                "tag": plan.discount_label
            })
            
        return success_response({"plans": plan_list})

    except Exception as e:
        return error_response(500, f"服务器错误: {str(e)}")


@bp.route("/activate", methods=["POST"])
@jwt_required()
def activate_membership():
    """
    激活会员（兼容性路由）
    ---
    tags:
      - 会员
    security:
      - Bearer: []
    parameters:
      - name: body
        in: body
        required: true
        schema:
          type: object
          properties:
            code:
              type: string
              description: 激活码
            activation_code:
              type: string
              description: 激活码 (兼容旧版)
    responses:
      200:
        description: 激活成功
      400:
        description: 参数错误
    """
    try:
        user_id = get_jwt_identity()
        data = request.get_json()
        
        # 兼容两种参数名
        code = data.get('code') or data.get('activation_code')
        device_id = data.get('device_id', 'unknown')
        
        if not code:
            return error_response(400, "请输入激活码")
            
        success, message, result = ActivationService.activate(code, user_id, device_id)
        
        if success:
            return success_response(result, message)
        else:
            return error_response(400, message)

    except Exception as e:
        return error_response(500, f"服务器错误: {str(e)}")
