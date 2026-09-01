"""
支付配置文件
包含微信支付和支付宝支付的配置
"""
import os
from dotenv import load_dotenv

load_dotenv()


class WeChatPayConfig:
    """微信支付配置"""
    
    # 微信公众号/小程序配置
    APP_ID = os.getenv('WECHAT_APP_ID', '')
    APP_SECRET = os.getenv('WECHAT_APP_SECRET', '')
    
    # 微信商户配置
    MCH_ID = os.getenv('WECHAT_MCH_ID', '')  # 商户号
    MCH_KEY = os.getenv('WECHAT_MCH_KEY', '')  # API密钥
    MCH_SERIAL_NO = os.getenv('WECHAT_MCH_SERIAL_NO', '')  # 商户证书序列号
    
    # 证书路径
    APICLIENT_CERT = os.getenv('WECHAT_CERT_PATH', './certs/apiclient_cert.pem')
    APICLIENT_KEY = os.getenv('WECHAT_KEY_PATH', './certs/apiclient_key.pem')
    
    # 回调地址
    NOTIFY_URL = os.getenv('WECHAT_NOTIFY_URL', 'https://yourdomain.com/api/v1/payment/wechat/notify')
    
    # API版本
    API_VERSION = 'v3'
    
    # 支付类型
    TRADE_TYPE = {
        'JSAPI': 'JSAPI',  # 公众号/小程序支付
        'NATIVE': 'NATIVE',  # 扫码支付
        'APP': 'APP',  # APP支付
        'MWEB': 'MWEB',  # H5支付
    }


class AliPayConfig:
    """支付宝配置"""
    
    # 应用配置
    APP_ID = os.getenv('ALIPAY_APP_ID', '')
    
    # 签名方式
    SIGN_TYPE = 'RSA2'
    
    # 网关地址（正式环境和沙箱环境）
    GATEWAY = os.getenv('ALIPAY_GATEWAY', 'https://openapi.alipay.com/gateway.do')
    # 沙箱网关: https://openapi.alipaydev.com/gateway.do
    
    # 应用私钥（需要自己生成）
    APP_PRIVATE_KEY = os.getenv('ALIPAY_APP_PRIVATE_KEY', '')
    
    # 支付宝公钥（从支付宝后台获取）
    ALIPAY_PUBLIC_KEY = os.getenv('ALIPAY_PUBLIC_KEY', '')
    
    # 回调地址
    NOTIFY_URL = os.getenv('ALIPAY_NOTIFY_URL', 'https://yourdomain.com/api/v1/payment/alipay/notify')
    RETURN_URL = os.getenv('ALIPAY_RETURN_URL', 'https://yourdomain.com/payment/success')
    
    # 支付超时时间
    TIMEOUT_EXPRESS = '30m'
    
    # 产品码
    PRODUCT_CODE = {
        'QUICK_MSECURITY_PAY': 'QUICK_MSECURITY_PAY',  # APP支付
        'QUICK_WAP_WAY': 'QUICK_WAP_WAY',  # 手机网站支付
        'FAST_INSTANT_TRADE_PAY': 'FAST_INSTANT_TRADE_PAY',  # PC网站支付
    }


class PaymentConfig:
    """通用支付配置"""
    
    # 支付方式
    PAYMENT_METHOD = {
        'WECHAT': 'wechat',
        'ALIPAY': 'alipay',
    }
    
    # 订单状态
    ORDER_STATUS = {
        'PENDING': 0,  # 待支付
        'PAID': 1,  # 已支付
        'CANCELLED': 2,  # 已取消
        'REFUNDING': 3,  # 退款中
        'REFUNDED': 4,  # 已退款
        'FAILED': 5,  # 支付失败
    }
    
    # 支付场景
    PAYMENT_SCENE = {
        'VIP_MONTH': 'vip_month',  # VIP月卡
        'VIP_SEASON': 'vip_season',  # VIP季卡
        'VIP_YEAR': 'vip_year',  # VIP年卡
        'COINS': 'coins',  # 购买金币
        'COURSE': 'course',  # 课程购买
    }
    
    # 商品价格（单位：分）
    PRODUCT_PRICE = {
        'vip_month': 1900,  # 19元/月
        'vip_season': 4900,  # 49元/季
        'vip_year': 9900,  # 99元/年
        'coins_100': 100,  # 1元=100金币
        'coins_500': 500,
        'coins_1000': 1000,
    }
    
    # 商品名称
    PRODUCT_NAME = {
        'vip_month': '狮子英语VIP月卡',
        'vip_season': '狮子英语VIP季卡',
        'vip_year': '狮子英语VIP年卡',
        'coins_100': '100金币',
        'coins_500': '500金币',
        'coins_1000': '1000金币',
    }
    
    # 订单号前缀
    ORDER_PREFIX = 'LE'  # LionEnglish
    
    # 订单有效期（分钟）
    ORDER_EXPIRE_TIME = 30
