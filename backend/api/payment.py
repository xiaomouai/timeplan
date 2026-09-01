"""
支付API接口
"""
from flask import Blueprint, request, jsonify
from flask_jwt_extended import get_jwt_identity, jwt_required
from models.payment import PaymentOrder, VIPMembership, UserCoins
from extensions import db
from utils.response import success_response, error_response
from datetime import datetime

payment_bp = Blueprint('payment', __name__)


def _wechat_service():
    try:
        from services.wechat_pay_service import wechat_pay_service
    except ImportError as error:
        raise RuntimeError(f'微信支付依赖未安装: {error}') from error
    return wechat_pay_service


def _alipay_service():
    try:
        from services.alipay_service import alipay_service
    except ImportError as error:
        raise RuntimeError(f'支付宝依赖未安装: {error}') from error
    return alipay_service


@payment_bp.route('/create', methods=['POST'])
@jwt_required()
def create_payment():
    """
    创建支付订单
    ---
    tags:
      - 支付管理
    parameters:
      - name: body
        in: body
        required: true
        schema:
          type: object
          required:
            - user_id
            - product_type
            - payment_method
          properties:
            user_id:
              type: integer
              description: 用户ID
              example: 1
            product_type:
              type: string
              description: 商品类型 (vip_month/vip_season/vip_year/coins_100等)
              example: vip_month
            payment_method:
              type: string
              description: 支付方式 (wechat/alipay)
              example: wechat
            payment_scene:
              type: string
              description: 支付场景 (NATIVE/JSAPI/APP/MWEB for 微信, app/wap/pc for 支付宝)
              example: NATIVE
            openid:
              type: string
              description: 微信用户openid (JSAPI支付必填)
              example: oUpF8uMuAJO_M2pxb1Q9zNjWeS6o
    responses:
      200:
        description: 订单创建成功
        schema:
          type: object
          properties:
            code:
              type: integer
              example: 200
            message:
              type: string
              example: 订单创建成功
            data:
              type: object
              properties:
                order_no:
                  type: string
                  description: 订单号
                order_id:
                  type: integer
                  description: 订单ID
                payment_method:
                  type: string
                  description: 支付方式
                total_amount:
                  type: integer
                  description: 订单金额（分）
                expired_at:
                  type: string
                  description: 过期时间
                payment_data:
                  type: object
                  description: 支付参数
      400:
        description: 参数错误
    """
    try:
        data = request.get_json(silent=True) or {}
        
        user_id = str(get_jwt_identity())
        product_type = data.get('product_type')
        payment_method = data.get('payment_method')
        payment_scene = data.get('payment_scene', 'NATIVE')
        openid = data.get('openid')
        
        if not all([user_id, product_type, payment_method]):
            return error_response(400, '缺少必要参数')
        
        # 根据支付方式创建订单
        if payment_method == 'wechat':
            result = _wechat_service().create_order(
                user_id=user_id,
                product_type=product_type,
                payment_scene=payment_scene,
                openid=openid
            )
        elif payment_method == 'alipay':
            result = _alipay_service().create_order(
                user_id=user_id,
                product_type=product_type,
                payment_scene=payment_scene
            )
        else:
            return error_response(400, '不支持的支付方式')
        
        if result:
            return success_response(result, '订单创建成功')
        else:
            return error_response(500, '订单创建失败')
            
    except Exception as e:
        return error_response(500, f'创建订单失败: {str(e)}')


@payment_bp.route('/query/<order_no>', methods=['GET'])
@jwt_required()
def query_payment(order_no):
    """
    查询订单状态
    ---
    tags:
      - 支付管理
    parameters:
      - name: order_no
        in: path
        type: string
        required: true
        description: 订单号
    responses:
      200:
        description: 查询成功
        schema:
          type: object
          properties:
            code:
              type: integer
              example: 200
            message:
              type: string
              example: 查询成功
            data:
              type: object
              properties:
                order:
                  type: object
                  description: 数据库订单信息
                payment_status:
                  type: object
                  description: 第三方支付状态
    """
    try:
        # 查询数据库订单
        order = PaymentOrder.query.filter_by(
            order_no=order_no,
            user_id=str(get_jwt_identity()),
        ).first()
        if not order:
            return error_response(404, '订单不存在')
        
        # 查询第三方支付状态
        if order.payment_method == 'wechat':
            payment_status = _wechat_service().query_order(order_no)
        elif order.payment_method == 'alipay':
            payment_status = _alipay_service().query_order(order_no)
        else:
            payment_status = None
        
        return success_response({
            'order': order.to_dict(),
            'payment_status': payment_status
        }, '查询成功')
        
    except Exception as e:
        return error_response(500, f'查询失败: {str(e)}')


@payment_bp.route('/close/<order_no>', methods=['POST'])
@jwt_required()
def close_payment(order_no):
    """
    关闭订单
    ---
    tags:
      - 支付管理
    parameters:
      - name: order_no
        in: path
        type: string
        required: true
        description: 订单号
    responses:
      200:
        description: 关闭成功
    """
    try:
        # 查询数据库订单
        order = PaymentOrder.query.filter_by(
            order_no=order_no,
            user_id=str(get_jwt_identity()),
        ).first()
        if not order:
            return error_response(404, '订单不存在')
        
        # 检查订单状态
        if order.status != 0:
            return error_response(400, '订单状态不允许关闭')
        
        # 关闭第三方订单
        if order.payment_method == 'wechat':
            success = _wechat_service().close_order(order_no)
        elif order.payment_method == 'alipay':
            success = _alipay_service().close_order(order_no)
        else:
            success = False
        
        if success:
            return success_response(None, '订单已关闭')
        else:
            return error_response(500, '关闭订单失败')
            
    except Exception as e:
        return error_response(500, f'关闭失败: {str(e)}')


@payment_bp.route('/wechat/notify', methods=['POST'])
def wechat_notify():
    """
    微信支付回调
    ---
    tags:
      - 支付管理
    responses:
      200:
        description: 处理成功
    """
    try:
        data = request.get_json()
        success = _wechat_service().handle_callback(data)
        
        if success:
            return jsonify({'code': 'SUCCESS', 'message': '成功'})
        else:
            return jsonify({'code': 'FAIL', 'message': '失败'})
            
    except Exception as e:
        print(f"微信回调处理失败: {e}")
        return jsonify({'code': 'FAIL', 'message': str(e)})


@payment_bp.route('/alipay/notify', methods=['POST'])
def alipay_notify():
    """
    支付宝支付回调
    ---
    tags:
      - 支付管理
    responses:
      200:
        description: 处理成功
    """
    try:
        data = request.form.to_dict()
        success = _alipay_service().handle_callback(data)
        
        if success:
            return 'success'
        else:
            return 'fail'
            
    except Exception as e:
        print(f"支付宝回调处理失败: {e}")
        return 'fail'


@payment_bp.route('/orders/user/<user_id>', methods=['GET'])
@jwt_required()
def get_user_orders(user_id):
    """
    获取用户订单列表
    ---
    tags:
      - 支付管理
    parameters:
      - name: user_id
        in: path
        type: integer
        required: true
        description: 用户ID
      - name: page
        in: query
        type: integer
        description: 页码
        default: 1
      - name: per_page
        in: query
        type: integer
        description: 每页数量
        default: 10
      - name: status
        in: query
        type: integer
        description: 订单状态 (0待支付 1已支付 2已取消 3退款中 4已退款 5失败)
    responses:
      200:
        description: 查询成功
        schema:
          type: object
          properties:
            code:
              type: integer
              example: 200
            data:
              type: object
              properties:
                orders:
                  type: array
                  items:
                    type: object
                total:
                  type: integer
                page:
                  type: integer
                per_page:
                  type: integer
    """
    try:
        if str(user_id) != str(get_jwt_identity()):
            return error_response(403, '无权查看其他用户订单')
        page = request.args.get('page', 1, type=int)
        per_page = request.args.get('per_page', 10, type=int)
        status = request.args.get('status', type=int)
        
        query = PaymentOrder.query.filter_by(user_id=user_id)
        
        if status is not None:
            query = query.filter_by(status=status)
        
        # 分页查询
        pagination = query.order_by(PaymentOrder.created_at.desc()).paginate(
            page=page, per_page=per_page, error_out=False
        )
        
        orders = [order.to_dict() for order in pagination.items]
        
        return success_response({
            'orders': orders,
            'total': pagination.total,
            'page': page,
            'per_page': per_page,
            'pages': pagination.pages
        })
        
    except Exception as e:
        return error_response(500, f'查询失败: {str(e)}')


@payment_bp.route('/vip/<user_id>', methods=['GET'])
@jwt_required()
def get_vip_status(user_id):
    """
    获取用户VIP状态
    ---
    tags:
      - 支付管理
    parameters:
      - name: user_id
        in: path
        type: integer
        required: true
        description: 用户ID
    responses:
      200:
        description: 查询成功
        schema:
          type: object
          properties:
            code:
              type: integer
              example: 200
            data:
              type: object
              properties:
                is_vip:
                  type: boolean
                vip_info:
                  type: object
    """
    try:
        if str(user_id) != str(get_jwt_identity()):
            return error_response(403, '无权查看其他用户会员状态')
        membership = VIPMembership.query.filter_by(user_id=user_id).first()
        
        if membership:
            return success_response({
                'is_vip': membership.is_valid(),
                'vip_info': membership.to_dict()
            })
        else:
            return success_response({
                'is_vip': False,
                'vip_info': None
            })
            
    except Exception as e:
        return error_response(500, f'查询失败: {str(e)}')


@payment_bp.route('/coins/<user_id>', methods=['GET'])
@jwt_required()
def get_user_coins(user_id):
    """
    获取用户金币
    ---
    tags:
      - 支付管理
    parameters:
      - name: user_id
        in: path
        type: integer
        required: true
        description: 用户ID
    responses:
      200:
        description: 查询成功
        schema:
          type: object
          properties:
            code:
              type: integer
              example: 200
            data:
              type: object
              properties:
                coins:
                  type: object
    """
    try:
        if str(user_id) != str(get_jwt_identity()):
            return error_response(403, '无权查看其他用户金币')
        coins = UserCoins.query.filter_by(user_id=user_id).first()
        
        if coins:
            return success_response({'coins': coins.to_dict()})
        else:
            return success_response({
                'coins': {
                    'user_id': user_id,
                    'total_coins': 0,
                    'used_coins': 0,
                    'available_coins': 0
                }
            })
            
    except Exception as e:
        return error_response(500, f'查询失败: {str(e)}')


@payment_bp.route('/products', methods=['GET'])
def get_products():
    """
    获取商品列表
    ---
    tags:
      - 支付管理
    responses:
      200:
        description: 查询成功
        schema:
          type: object
          properties:
            code:
              type: integer
              example: 200
            data:
              type: object
              properties:
                products:
                  type: array
                  items:
                    type: object
    """
    from config.payment_config import PaymentConfig
    
    products = []
    
    # VIP商品
    vip_products = [
        {
            'id': 'vip_month',
            'name': 'VIP月卡',
            'desc': '畅享所有VIP功能30天',
            'price': 1900,
            'price_yuan': 19.00,
            'duration': '30天',
            'type': 'vip'
        },
        {
            'id': 'vip_season',
            'name': 'VIP季卡',
            'desc': '畅享所有VIP功能90天',
            'price': 4900,
            'price_yuan': 49.00,
            'duration': '90天',
            'type': 'vip',
            'discount': '8.6折'
        },
        {
            'id': 'vip_year',
            'name': 'VIP年卡',
            'desc': '畅享所有VIP功能365天',
            'price': 9900,
            'price_yuan': 99.00,
            'duration': '365天',
            'type': 'vip',
            'discount': '4.3折'
        }
    ]
    
    # 金币商品
    coin_products = [
        {
            'id': 'coins_100',
            'name': '100金币',
            'desc': '可用于兑换学习资源',
            'price': 100,
            'price_yuan': 1.00,
            'coins': 100,
            'type': 'coins'
        },
        {
            'id': 'coins_500',
            'name': '500金币',
            'desc': '可用于兑换学习资源',
            'price': 500,
            'price_yuan': 5.00,
            'coins': 500,
            'type': 'coins'
        },
        {
            'id': 'coins_1000',
            'name': '1000金币',
            'desc': '可用于兑换学习资源',
            'price': 1000,
            'price_yuan': 10.00,
            'coins': 1000,
            'type': 'coins'
        }
    ]
    
    products = {
        'vip_products': vip_products,
        'coin_products': coin_products
    }
    
    return success_response({'products': products})
