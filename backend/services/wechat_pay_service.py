"""
微信支付服务
"""
import time
import json
import hashlib
from datetime import datetime, timedelta
from wechatpayv3 import WeChatPay, WeChatPayType
from config.payment_config import WeChatPayConfig, PaymentConfig
from models.payment import PaymentOrder, PaymentLog
from extensions import db


class WeChatPayService:
    """微信支付服务类"""
    
    def __init__(self):
        """初始化微信支付"""
        try:
            self.wxpay = WeChatPay(
                wechatpay_type=WeChatPayType.NATIVE,
                mchid=WeChatPayConfig.MCH_ID,
                private_key=self._load_private_key(),
                cert_serial_no=WeChatPayConfig.MCH_SERIAL_NO,
                apiv3_key=WeChatPayConfig.MCH_KEY,
                appid=WeChatPayConfig.APP_ID,
                notify_url=WeChatPayConfig.NOTIFY_URL
            )
        except Exception as e:
            print(f"微信支付初始化失败: {e}")
            self.wxpay = None
    
    def _load_private_key(self):
        """加载商户私钥"""
        try:
            with open(WeChatPayConfig.APICLIENT_KEY, 'r') as f:
                return f.read()
        except Exception as e:
            print(f"加载微信私钥失败: {e}")
            return ''
    
    def create_order(self, user_id, product_type, payment_scene='NATIVE', openid=None):
        """
        创建支付订单
        
        Args:
            user_id: 用户ID
            product_type: 商品类型 (vip_month, vip_year等)
            payment_scene: 支付场景 (NATIVE/JSAPI/APP/MWEB)
            openid: 用户openid (JSAPI支付必填)
        
        Returns:
            dict: 订单信息和支付参数
        """
        try:
            # 生成订单号
            order_no = self._generate_order_no()
            
            # 获取商品信息
            product_name = PaymentConfig.PRODUCT_NAME.get(product_type, '狮子英语')
            total_amount = PaymentConfig.PRODUCT_PRICE.get(product_type, 100)
            
            # 创建数据库订单
            order = PaymentOrder(
                order_no=order_no,
                user_id=user_id,
                payment_method='wechat',
                payment_scene=product_type,
                product_name=product_name,
                product_desc=f'{product_name}购买',
                total_amount=total_amount,
                status=0,
                expired_at=datetime.utcnow() + timedelta(minutes=PaymentConfig.ORDER_EXPIRE_TIME)
            )
            db.session.add(order)
            db.session.commit()
            
            # 调用微信支付API
            if payment_scene == 'NATIVE':
                # 扫码支付
                result = self._create_native_pay(order_no, product_name, total_amount)
            elif payment_scene == 'JSAPI':
                # 公众号/小程序支付
                result = self._create_jsapi_pay(order_no, product_name, total_amount, openid)
            elif payment_scene == 'APP':
                # APP支付
                result = self._create_app_pay(order_no, product_name, total_amount)
            elif payment_scene == 'MWEB':
                # H5支付
                result = self._create_h5_pay(order_no, product_name, total_amount)
            else:
                raise ValueError(f'不支持的支付场景: {payment_scene}')
            
            # 记录日志
            self._log_payment_action(order_no, 'create_order', '创建订单', result)
            
            return {
                'order_no': order_no,
                'order_id': order.id,
                'payment_method': 'wechat',
                'total_amount': total_amount,
                'expired_at': order.expired_at.isoformat(),
                'payment_data': result
            }
            
        except Exception as e:
            db.session.rollback()
            print(f"创建微信订单失败: {e}")
            return None
    
    def _create_native_pay(self, order_no, description, total_amount):
        """创建扫码支付"""
        if not self.wxpay:
            return {'error': '微信支付未初始化'}
        
        out_trade_no = order_no
        amount = {'total': total_amount, 'currency': 'CNY'}
        
        try:
            code, message = self.wxpay.pay(
                description=description,
                out_trade_no=out_trade_no,
                amount=amount
            )
            
            return {
                'code_url': message.get('code_url', ''),
                'prepay_id': message.get('prepay_id', ''),
            }
        except Exception as e:
            print(f"创建扫码支付失败: {e}")
            return {'error': str(e)}
    
    def _create_jsapi_pay(self, order_no, description, total_amount, openid):
        """创建JSAPI支付（公众号/小程序）"""
        if not self.wxpay:
            return {'error': '微信支付未初始化'}
        
        if not openid:
            return {'error': 'openid不能为空'}
        
        out_trade_no = order_no
        amount = {'total': total_amount, 'currency': 'CNY'}
        payer = {'openid': openid}
        
        try:
            code, message = self.wxpay.pay(
                description=description,
                out_trade_no=out_trade_no,
                amount=amount,
                pay_type=WeChatPayType.JSAPI,
                payer=payer
            )
            
            # 生成JSAPI支付参数
            prepay_id = message.get('prepay_id', '')
            pay_params = self.wxpay.build_pay_params(prepay_id)
            
            return {
                'prepay_id': prepay_id,
                'pay_params': pay_params,
            }
        except Exception as e:
            print(f"创建JSAPI支付失败: {e}")
            return {'error': str(e)}
    
    def _create_app_pay(self, order_no, description, total_amount):
        """创建APP支付"""
        if not self.wxpay:
            return {'error': '微信支付未初始化'}
        
        out_trade_no = order_no
        amount = {'total': total_amount, 'currency': 'CNY'}
        
        try:
            code, message = self.wxpay.pay(
                description=description,
                out_trade_no=out_trade_no,
                amount=amount,
                pay_type=WeChatPayType.APP
            )
            
            prepay_id = message.get('prepay_id', '')
            pay_params = self.wxpay.build_pay_params(prepay_id)
            
            return {
                'prepay_id': prepay_id,
                'pay_params': pay_params,
            }
        except Exception as e:
            print(f"创建APP支付失败: {e}")
            return {'error': str(e)}
    
    def _create_h5_pay(self, order_no, description, total_amount):
        """创建H5支付"""
        if not self.wxpay:
            return {'error': '微信支付未初始化'}
        
        out_trade_no = order_no
        amount = {'total': total_amount, 'currency': 'CNY'}
        scene_info = {
            'payer_client_ip': '127.0.0.1',
            'h5_info': {
                'type': 'Wap'
            }
        }
        
        try:
            code, message = self.wxpay.pay(
                description=description,
                out_trade_no=out_trade_no,
                amount=amount,
                pay_type=WeChatPayType.H5,
                scene_info=scene_info
            )
            
            return {
                'h5_url': message.get('h5_url', ''),
            }
        except Exception as e:
            print(f"创建H5支付失败: {e}")
            return {'error': str(e)}
    
    def query_order(self, order_no):
        """
        查询订单状态
        
        Args:
            order_no: 订单号
        
        Returns:
            dict: 订单状态信息
        """
        if not self.wxpay:
            return None
        
        try:
            code, message = self.wxpay.query(out_trade_no=order_no)
            
            self._log_payment_action(order_no, 'query_order', '查询订单', message)
            
            return {
                'trade_state': message.get('trade_state', ''),
                'trade_state_desc': message.get('trade_state_desc', ''),
                'transaction_id': message.get('transaction_id', ''),
                'amount': message.get('amount', {}),
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
        if not self.wxpay:
            return False
        
        try:
            code, message = self.wxpay.close(out_trade_no=order_no)
            
            # 更新数据库订单状态
            order = PaymentOrder.query.filter_by(order_no=order_no).first()
            if order:
                order.status = 2  # 已取消
                order.cancelled_at = datetime.utcnow()
                db.session.commit()
            
            self._log_payment_action(order_no, 'close_order', '关闭订单', message)
            
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
            if not self._verify_callback_signature(request_data):
                print("回调签名验证失败")
                return False
            
            # 解析回调数据
            callback_data = json.loads(request_data.get('resource', {}).get('ciphertext', '{}'))
            
            order_no = callback_data.get('out_trade_no', '')
            trade_no = callback_data.get('transaction_id', '')
            trade_state = callback_data.get('trade_state', '')
            
            # 更新订单状态
            order = PaymentOrder.query.filter_by(order_no=order_no).first()
            if not order:
                print(f"订单不存在: {order_no}")
                return False
            
            if trade_state == 'SUCCESS':
                order.status = 1  # 已支付
                order.trade_no = trade_no
                order.paid_at = datetime.utcnow()
                order.paid_amount = callback_data.get('amount', {}).get('total', 0)
                order.callback_data = json.dumps(callback_data)
                
                # 处理业务逻辑（开通VIP、增加金币等）
                self._process_payment_success(order)
                
                db.session.commit()
                
                self._log_payment_action(order_no, 'callback_success', '支付成功回调', callback_data)
                
                return True
            else:
                print(f"支付状态异常: {trade_state}")
                return False
                
        except Exception as e:
            print(f"处理回调失败: {e}")
            db.session.rollback()
            return False
    
    def _verify_callback_signature(self, request_data):
        """验证回调签名"""
        # 实际项目中需要验证微信支付回调签名
        # 这里简化处理
        return True
    
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
        return f"{PaymentConfig.ORDER_PREFIX}WX{timestamp}"
    
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
wechat_pay_service = WeChatPayService()
