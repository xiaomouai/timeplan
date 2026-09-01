"""
管理员服务
提供后台管理系统所需的数据查询和统计功能
"""
from datetime import datetime, timedelta, date
from sqlalchemy import func, desc
from extensions import db
from models.user_models import User
from models.membership_models import MembershipOrder, UserMembership, ActivationCode
from models.version_model import AppVersion, ApiVersion
from typing import Dict, List, Any


class AdminService:
    """管理员服务类"""

    @staticmethod
    def list_activation_codes(page: int = 1, per_page: int = 10, search: str = None) -> Dict[str, Any]:
        """获取激活码列表"""
        query = ActivationCode.query
        if search:
            query = query.filter(
                (ActivationCode.code.like(f"%{search}%")) |
                (ActivationCode.activated_by.like(f"%{search}%"))
            )
        
        pagination = query.order_by(desc(ActivationCode.created_at)).paginate(
            page=page, per_page=per_page, error_out=False
        )
        
        codes = []
        for code in pagination.items:
            user = User.query.get(code.activated_by) if code.activated_by else None
            codes.append({
                'id': code.id,
                'code': code.code,
                'plan_type': code.plan_type,
                'duration_days': code.duration_days,
                'status': code.status,
                'created_at': code.created_at.isoformat() if code.created_at else None,
                'activated_at': code.activated_at.isoformat() if code.activated_at else None,
                'activated_by_phone': user.phone if user else None,
                'activated_device_id': code.activated_device_id
            })
            
        return {
            'total': pagination.total,
            'pages': pagination.pages,
            'current_page': pagination.page,
            'codes': codes
        }

    @staticmethod
    def generate_activation_codes(data: Dict[str, Any]) -> List[str]:
        """生成激活码"""
        from services.activation_service import ActivationService
        
        plan_type = data.get('plan_type', 'month')
        duration_days = data.get('duration_days', 30)
        quantity = data.get('quantity', 1)
        order_id = data.get('order_id', f"ADMIN_{datetime.now().strftime('%Y%m%d%H%M%S')}")
        
        return ActivationService.generate_codes(order_id, plan_type, quantity, duration_days)

    @staticmethod
    def update_activation_code_status(code_id: int, status: int) -> bool:
        """更新激活码状态"""
        try:
            code = ActivationCode.query.get(code_id)
            if not code:
                return False
            code.status = status
            db.session.commit()
            return True
        except Exception as e:
            db.session.rollback()
            print(f"Update activation code status error: {e}")
            return False

    @staticmethod
    def get_dashboard_stats() -> Dict[str, Any]:
        """获取仪表盘统计数据"""
        try:
            today = date.today()
            yesterday = today - timedelta(days=1)

            # 总用户数
            total_users = User.query.count()
            # 今日新增用户
            today_users = User.query.filter(func.date(User.created_at) == today).count()
            # 昨日新增用户
            yesterday_users = User.query.filter(func.date(User.created_at) == yesterday).count()
            user_growth = today_users - yesterday_users

            # 总订单数 (已支付)
            total_orders = MembershipOrder.query.filter_by(status='paid').count()
            # 今日订单数
            today_orders = MembershipOrder.query.filter(
                func.date(MembershipOrder.paid_time) == today,
                MembershipOrder.status == 'paid'
            ).count()

            # 总营收
            total_revenue = db.session.query(func.sum(MembershipOrder.actual_price))\
                .filter_by(status='paid').scalar() or 0
            # 今日营收
            today_revenue = db.session.query(func.sum(MembershipOrder.actual_price))\
                .filter(
                    func.date(MembershipOrder.paid_time) == today,
                    MembershipOrder.status == 'paid'
                ).scalar() or 0

            return {
                'total_users': total_users,
                'today_users': today_users,
                'user_growth': user_growth,
                'total_orders': total_orders,
                'today_orders': today_orders,
                'total_revenue': float(total_revenue),
                'today_revenue': float(today_revenue)
            }
        except Exception as e:
            print(f"Dashboard stats error: {e}")
            return {}

    @staticmethod
    def list_users(page: int = 1, per_page: int = 10, search: str = None) -> Dict[str, Any]:
        """获取用户列表"""
        query = User.query
        if search:
            query = query.filter(
                (User.phone.like(f"%{search}%")) | 
                (User.nickname.like(f"%{search}%"))
            )
        
        pagination = query.order_by(desc(User.created_at)).paginate(
            page=page, per_page=per_page, error_out=False
        )
        
        return {
            'total': pagination.total,
            'pages': pagination.pages,
            'current_page': pagination.page,
            'users': [user.to_dict() for user in pagination.items]
        }

    @staticmethod
    def list_orders(page: int = 1, per_page: int = 10, status: str = None) -> Dict[str, Any]:
        """获取订单列表"""
        query = MembershipOrder.query
        if status:
            query = query.filter_by(status=status)
        
        pagination = query.order_by(desc(MembershipOrder.created_at)).paginate(
            page=page, per_page=per_page, error_out=False
        )
        
        orders = []
        for order in pagination.items:
            user = User.query.get(order.user_id)
            orders.append({
                'id': order.id,
                'order_no': order.order_no,
                'user_phone': user.phone if user else '未知',
                'actual_price': float(order.actual_price),
                'payment_method': order.payment_method,
                'status': order.status,
                'paid_time': order.paid_time.isoformat() if order.paid_time else None,
                'created_at': order.created_at.isoformat()
            })
            
        return {
            'total': pagination.total,
            'pages': pagination.pages,
            'current_page': pagination.page,
            'orders': orders
        }

    @staticmethod
    def get_user_growth_report(days: int = 7) -> List[Dict[str, Any]]:
        """获取用户增长报表数据"""
        data = []
        for i in range(days - 1, -1, -1):
            day = date.today() - timedelta(days=i)
            count = User.query.filter(func.date(User.created_at) == day).count()
            data.append({
                'date': day.strftime('%m-%d'),
                'count': count
            })
        return data

    @staticmethod
    def get_revenue_report(days: int = 7) -> List[Dict[str, Any]]:
        """获取营收报表数据"""
        data = []
        for i in range(days - 1, -1, -1):
            day = date.today() - timedelta(days=i)
            revenue = db.session.query(func.sum(MembershipOrder.actual_price))\
                .filter(
                    func.date(MembershipOrder.paid_time) == day,
                    MembershipOrder.status == 'paid'
                ).scalar() or 0
            data.append({
                'date': day.strftime('%m-%d'),
                'revenue': float(revenue)
            })
        return data

    @staticmethod
    def update_user_status(user_id: str, status: str) -> bool:
        """更新用户状态"""
        try:
            user = User.query.get(user_id)
            if not user:
                return False
            user.status = status
            db.session.commit()
            return True
        except Exception as e:
            db.session.rollback()
            print(f"Update user status error: {e}")
            return False

    @staticmethod
    def update_order_status(order_id: int, status: str) -> bool:
        """更新订单状态"""
        try:
            order = MembershipOrder.query.get(order_id)
            if not order:
                return False
            order.status = status
            db.session.commit()
            return True
        except Exception as e:
            db.session.rollback()
            print(f"Update order status error: {e}")
            return False

    @staticmethod
    def add_app_version(data: Dict[str, Any]) -> AppVersion:
        """添加新应用版本"""
        platform = data.get('platform', 'android')
        is_latest = data.get('is_latest', True)

        if is_latest:
            AppVersion.query.filter_by(platform=platform, is_latest=True).update({'is_latest': False})

        new_version = AppVersion(
            platform=platform,
            version=data.get('version'),
            build_number=data.get('build_number'),
            changelog='\n'.join(data.get('changelog', [])) if isinstance(data.get('changelog'), list) else data.get('changelog'),
            download_url=data.get('download_url'),
            force_update=data.get('force_update', False),
            file_size=data.get('file_size'),
            md5=data.get('md5'),
            is_latest=is_latest,
            release_date=datetime.now()
        )

        db.session.add(new_version)
        db.session.commit()
        return new_version

    @staticmethod
    def add_api_version(data: Dict[str, Any]) -> ApiVersion:
        """添加新 API 版本"""
        ApiVersion.query.filter_by(is_active=True).update({'is_active': False})

        new_api = ApiVersion(
            version=data.get('version'),
            build=data.get('build', int(datetime.now().strftime('%Y%m%d'))),
            min_app_version=data.get('min_app_version', '1.0.0'),
            features='\n'.join(data.get('features', [])) if isinstance(data.get('features'), list) else data.get('features'),
            release_date=datetime.now(),
            is_active=True
        )

        db.session.add(new_api)
        db.session.commit()
        return new_api
