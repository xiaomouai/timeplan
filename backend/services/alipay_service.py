"""
支付宝支付服务
"""
import time
import json
from datetime import datetime, timedelta
from alipay import AliPay
from config.payment_config import AliPayConfig, PaymentConfig
from models.payment import PaymentOrder, PaymentLog
from extensions import db


class AliPayService:
    """支付宝支付服务类"""
    
    def __init__(self):
        """初始化支付宝"""
        try:
            self.alipay = AliPay(
                appid=AliPayConfig.APP_ID,
                app_notify_url=AliPayConfig.NOTIFY_URL,
                app_private_key_string=AliPayConfig.APP_PRIVATE_KEY,
                alipay_public_key_string=AliPayConfig.ALIPAY_PUBLIC_KEY,
                sign_type=AliPayConfig.SIGN_TYPE,
                debug=False  # 生产环境设为False
            )
        except Exception as e:
            print(f"支付宝初始化失败: {e}")
            self.alipay = None
    
    def create_order(self, user_id, product_type, payment_scene='app'):
        """
        创建支付订单
        
        Args:
            user_id: 用户ID
            product_type: 商品类型 (vip_month, vip_year等)
            payment_scene: 支付场景 (app/wap/pc)
        
        Returns:
            dict: 订单信息和支付参数
        """
        try:
            # 生成订单号
            order_no = self._generate_order_no()
            
            # 获取商品信息
            product_name = PaymentConfig.PRODUCT_NAME.get(product_type, '狮子英语')
            total_amount = PaymentConfig.PRODUCT_PRICE.get(product_type, 100)
            # 支付宝金额单位是元
            total_amount_yuan = total_amount / 100
            
            # 创建数据库订单
            order = PaymentOrder(
                order_no=order_no,
                user_id=user_id,
                payment_method='alipay',
                payment_scene=product_type,
                product_name=product_name,
                product_desc=f'{product_name}购买',
                total_amount=total_amount,
                status=0,
                expired_at=datetime.utcnow() + timedelta(minutes=PaymentConfig.ORDER_EXPIRE_TIME)
            )
            db.session.add(order)
            db.session.commit()
            
            # 调用支付宝API
            if payment_scene == 'app':
                # APP支付
                result = self._create_app_pay(order_no, product_name, total_amount_yuan)
            elif payment_scene == 'wap':
                # 手机网站支付
                result = self._create_wap_pay(order_no, product_name, total_amount_yuan)
            elif payment_scene == 'pc':
                # PC网站支付
                result = self._create_pc_pay(order_no, product_name, total_amount_yuan)
            else:
                raise ValueError(f'不支持的支付场景: {payment_scene}')
            
            # 记录日志
            self._log_payment_action(order_no, 'create_order', '创建订单', {'result': result})
            
            return {
                'order_no': order_no,
                'order_id': order.id,
                'payment_method': 'alipay',
                'total_amount': total_amount,
                'expired_at': order.expired_at.isoformat(),
                'payment_data': result
            }
            
        except Exception as e:
            db.session.rollback()
            print(f"创建支付宝订单失败: {e}")
            return None
    
    def _create_app_pay(self, order_no, subject, total_amount):
        """创建APP支付"""
        if not self.alipay:
            return {'error': '支付宝未初始化'}
        
        try:
            order_string = self.alipay.api_alipay_trade_app_pay(
                out_trade_no=order_no,
                total_amount=str(total_amount),
                subject=subject,
                timeout_express=AliPayConfig.TIMEOUT_EXPRESS,
                product_code=AliPayConfig.PRODUCT_CODE['QUICK_MSECURITY_PAY']
            )
            
            return {
                'order_string': order_string,
                'payment_type': 'app'
            }
        except Exception as e:
            print(f"创建APP支付失败: {e}")
            return {'error': str(e)}
    
    def _create_wap_pay(self, order_no, subject, total_amount):
        """创建手机网站支付"""
        if not self.alipay:
            return {'error': '支付宝未初始化'}
        
        try:
            # 生成支付URL
            order_string = self.alipay.api_alipay_trade_wap_pay(
                out_trade_no=order_no,
                total_amount=str(total_amount),
                subject=subject,
                return_url=AliPayConfig.RETURN_URL,
                timeout_express=AliPayConfig.TIMEOUT_EXPRESS,
                product_code=AliPayConfig.PRODUCT_CODE['QUICK_WAP_WAY']
            )
            
            # 完整的支付URL
            pay_url = f"{AliPayConfig.GATEWAY}?{order_string}"
            
            return {
                'pay_url': pay_url,
                'payment_type': 'wap'
            }
        except Exception as e:
            print(f"创建手机网站支付失败: {e}")
            return {'error': str(e)}
    
    def _create_pc_pay(self, order_no, subject, total_amount):
        """创建PC网站支付"""
        if not self.alipay:
            return {'error': '支付宝未初始化'}
        
        try:
            # 生成支付URL
            order_string = self.alipay.api_alipay_trade_page_pay(
                out_trade_no=order_no,
                total_amount=str(total_amount),
                subject=subject,
                return_url=AliPayConfig.RETURN_URL,
                timeout_express=AliPayConfig.TIMEOUT_EXPRESS,
                product_code=AliPayConfig.PRODUCT_CODE['FAST_INSTANT_TRADE_PAY']
            )
            
            # 完整的支付URL
            pay_url = f"{AliPayConfig.GATEWAY}?{order_string}"
            
            return {
                'pay_url': pay_url,
                'payment_type': 'pc'
            }
        except Exception as e:
            print(f"创建PC网站支付失败: {e}")
            return {'error': str(e)}
    
    def query_order(self, order_no):
        """
        查询订单状态
        
        Args:
            order_no: 订单号
        
        Returns:
            dict: 订单状态信息
        """
        if not self.alipay:
            return None
        
        try:
            result = self.alipay.api_alipay_trade_query(out_trade_no=order_no)
            
            self._log_payment_action(order_no, 'query_order', '查询订单', result)
            
            return {
                'trade_status': result.get('trade_status', ''),
                'trade_no': result.get('trade_no', ''),
                'total_amount': result.get('total_amount', ''),
                'buyer_pay_amount': result.get('buyer_pay_amount', ''),
            }
        except Exception as e:
            print(f"查询订单失败: {e}")
            return None
    
    def close_order(self, order_no):
        """
        关闭订单
        
        Args:
            order_no: 订单号
        
        Returns:
            bool: 是否成功
        """
        if not self.alipay:
            return False
        
        try:
            result = self.alipay.api_alipay_trade_close(out_trade_no=order_no)
            
            # 更新数据库订单状态
            order = PaymentOrder.query.filter_by(order_no=order_no).first()
            if order:
                order.status = 2  # 已取消
                order.cancelled_at = datetime.utcnow()
                db.session.commit()
            
            self._log_payment_action(order_no, 'close_order', '关闭订单', result)
            
            return True
        except Exception as e:
            print(f"关闭订单失败: {e}")
            return False
    
    def handle_callback(self, request_data):
        """
        处理支付回调
        
        Args:
            request_data: 回调请求数据
        
        Returns:
            bool: 处理是否成功
        """
        try:
            # 验证签名
            signature = request_data.pop('sign', None)
            if not self._verify_callback_signature(request_data, signature):
                print("回调签名验证失败")
                return False
            
            # 解析回调数据
            order_no = request_data.get('out_trade_no', '')
            trade_no = request_data.get('trade_no', '')
            trade_status = request_data.get('trade_status', '')
            
            # 更新订单状态
            order = PaymentOrder.query.filter_by(order_no=order_no).first()
            if not order:
                print(f"订单不存在: {order_no}")
                return False
            
            if trade_status == 'TRADE_SUCCESS' or trade_status == 'TRADE_FINISHED':
                order.status = 1  # 已支付
                order.trade_no = trade_no
                order.paid_at = datetime.utcnow()
                # 支付宝金额是元，转换为分
                total_amount = float(request_data.get('total_amount', 0)) * 100
                order.paid_amount = int(total_amount)
                order.callback_data = json.dumps(request_data)
                
                # 处理业务逻辑（开通VIP、增加金币等）
                self._process_payment_success(order)
                
                db.session.commit()
                
                self._log_payment_action(order_no, 'callback_success', '支付成功回调', request_data)
                
                return True
            else:
                print(f"支付状态异常: {trade_status}")
                return False
                
        except Exception as e:
            print(f"处理回调失败: {e}")
            db.session.rollback()
            return False
    
    def _verify_callback_signature(self, data, signature):
        """验证回调签名"""
        if not self.alipay or not signature:
            return False
        
        try:
            return self.alipay.verify(data, signature)
        except Exception as e:
            print(f"验证签名失败: {e}")
            return False
    
    def _process_payment_success(self, order):
        """处理支付成功后的业务逻辑"""
        from models.payment import VIPMembership, UserCoins
        
        try:
            # 根据支付场景处理
            if order.payment_scene.startswith('vip_'):
                # 开通VIP
                self._activate_vip(order.user_id, order.payment_scene)
            elif order.payment_scene.startswith('coins_'):
                # 增加金币
                coins_amount = int(order.payment_scene.split('_')[1])
                self._add_coins(order.user_id, coins_amount)
                
        except Exception as e:
            print(f"处理支付成功业务失败: {e}")
    
    def _activate_vip(self, user_id, vip_type):
        """激活VIP会员"""
        from models.payment import VIPMembership
        
        # 计算会员时长
        duration_map = {
            'vip_month': 30,
            'vip_season': 90,
            'vip_year': 365,
        }
        days = duration_map.get(vip_type, 30)
        
        # 查找或创建会员记录
        membership = VIPMembership.query.filter_by(user_id=user_id).first()
        if not membership:
            membership = VIPMembership(user_id=user_id)
            db.session.add(membership)
        
        # 更新会员信息
        now = datetime.utcnow()
        if membership.is_valid():
            # 如果还在有效期内，延长时间
            membership.end_date = membership.end_date + timedelta(days=days)
        else:
            # 否则从现在开始
            membership.start_date = now
            membership.end_date = now + timedelta(days=days)
        
        membership.vip_type = vip_type.replace('vip_', '')
        membership.is_active = True
        
        db.session.commit()
    
    def _add_coins(self, user_id, amount):
        """增加用户金币"""
        from models.payment import UserCoins
        
        coins = UserCoins.query.filter_by(user_id=user_id).first()
        if not coins:
            coins = UserCoins(user_id=user_id)
            db.session.add(coins)
        
        coins.total_coins += amount
        coins.available_coins += amount
        
        db.session.commit()
    
    def _generate_order_no(self):
        """生成订单号"""
        timestamp = int(time.time() * 1000)
        return f"{PaymentConfig.ORDER_PREFIX}ALI{timestamp}"
    
    def _log_payment_action(self, order_no, action, message, data):
        """记录支付日志"""
        try:
            log = PaymentLog(
                order_no=order_no,
                action=action,
                message=message,
                response_data=json.dumps(data) if data else None
            )
            db.session.add(log)
            db.session.commit()
        except Exception as e:
            print(f"记录日志失败: {e}")


# 创建全局实例
alipay_service = AliPayService()
