"""
会员系统服务
提供会员购买、续费、权限验证等功能
"""
from datetime import datetime, timedelta
from typing import Optional, Dict, List
from sqlalchemy import and_, or_
from extensions import db
from models.membership_models import (
    MembershipPlan, UserMembership, MembershipOrder, 
    MembershipBenefit, UserMembershipBenefit
)
from models.user_models import User


class MembershipService:
    """会员系统服务类"""
    
    @staticmethod
    def get_all_plans(is_active: bool = True) -> List[MembershipPlan]:
        """获取所有会员套餐"""
        query = MembershipPlan.query
        if is_active:
            query = query.filter_by(is_active=True)
        return query.order_by(MembershipPlan.sort_order).all()
    
    @staticmethod
    def get_plan_by_id(plan_id: int) -> Optional[MembershipPlan]:
        """根据ID获取会员套餐"""
        return MembershipPlan.query.filter_by(id=plan_id, is_active=True).first()
    
    @staticmethod
    def get_user_membership(user_id: str) -> Optional[UserMembership]:
        """获取用户会员信息"""
        return UserMembership.query.filter_by(user_id=user_id).first()
    
    @staticmethod
    def check_membership_valid(user_id: str) -> bool:
        """检查用户会员是否有效"""
        membership = MembershipService.get_user_membership(user_id)
        if not membership:
            return False
        
        # 检查是否过期
        if membership.expire_time and membership.expire_time < datetime.now():
            return False
        
        # 检查是否启用
        if membership.status != 'active':
            return False

        # free 会员是基础账户，不应被当作 Pro 权益
        if membership.membership_type == 'free':
            return False

        return True
    
    @staticmethod
    def get_membership_type(user_id: str) -> str:
        """获取用户会员类型 (free/month/season/year/lifetime)"""
        if not MembershipService.check_membership_valid(user_id):
            return 'free'
        
        membership = MembershipService.get_user_membership(user_id)
        return membership.membership_type if membership else 'free'
    
    @staticmethod
    def create_order(user_id: str, plan_id: int, payment_method: str = 'alipay') -> Optional[MembershipOrder]:
        """创建会员订单"""
        plan = MembershipService.get_plan_by_id(plan_id)
        if not plan:
            return None
        
        user = User.query.filter_by(id=user_id).first()
        if not user:
            return None
        
        # 生成订单号
        order_no = f"VIP{datetime.now().strftime('%Y%m%d%H%M%S')}{user_id}"
        
        # 创建订单
        order = MembershipOrder(
            order_no=order_no,
            user_id=user_id,
            plan_id=plan_id,
            original_price=plan.price,
            actual_price=plan.price,  # 可以加入优惠券逻辑
            payment_method=payment_method,
            status='pending'
        )
        
        db.session.add(order)
        db.session.commit()
        
        return order
    
    @staticmethod
    def activate_membership(order_id: int) -> bool:
        """激活会员（支付成功后调用）"""
        order = MembershipOrder.query.get(order_id)
        if not order or order.status != 'pending':
            return False
        
        plan = MembershipService.get_plan_by_id(order.plan_id)
        if not plan:
            return False
        
        # 更新订单状态
        order.status = 'paid'
        order.paid_time = datetime.now()
        
        # 获取或创建用户会员信息
        membership = UserMembership.query.filter_by(user_id=order.user_id).first()
        
        now = datetime.now()
        
        if membership:
            # 已有会员，续费
            if membership.expire_time and membership.expire_time > now:
                # 从当前过期时间延长
                new_expire_time = membership.expire_time + timedelta(days=plan.duration_days)
            else:
                # 从现在开始计算
                new_expire_time = now + timedelta(days=plan.duration_days)
            
            membership.membership_type = plan.plan_type
            membership.expire_time = new_expire_time if plan.duration_days > 0 else None
            membership.status = 'active'
            membership.updated_at = now
        else:
            # 新会员
            expire_time = now + timedelta(days=plan.duration_days) if plan.duration_days > 0 else None
            membership = UserMembership(
                user_id=order.user_id,
                membership_type=plan.plan_type,
                expire_time=expire_time,
                status='active'
            )
            db.session.add(membership)
        
        # 激活会员权益
        benefits = MembershipBenefit.query.filter_by(
            membership_type=plan.plan_type,
            is_active=True
        ).all()
        
        for benefit in benefits:
            user_benefit = UserMembershipBenefit.query.filter_by(
                user_id=order.user_id,
                benefit_id=benefit.id
            ).first()
            
            if user_benefit:
                user_benefit.is_active = True
                user_benefit.updated_at = now
            else:
                user_benefit = UserMembershipBenefit(
                    user_id=order.user_id,
                    benefit_id=benefit.id,
                    is_active=True
                )
                db.session.add(user_benefit)
        
        db.session.commit()
        return True
    
    @staticmethod
    def cancel_order(order_id: int, user_id: str)-> bool:
        """取消订单"""
        order = MembershipOrder.query.filter_by(
            id=order_id,
            user_id=user_id,
            status='pending'
        ).first()
        
        if not order:
            return False
        
        order.status = 'cancelled'
        order.updated_at = datetime.now()
        db.session.commit()
        
        return True
    
    @staticmethod
    def get_user_orders(user_id: str, page: int = 1, per_page: int = 20) -> Dict:
        """获取用户订单列表"""
        query = MembershipOrder.query.filter_by(user_id=user_id)\
            .order_by(MembershipOrder.created_at.desc())
        
        pagination = query.paginate(page=page, per_page=per_page, error_out=False)
        
        orders = []
        for order in pagination.items:
            plan = MembershipService.get_plan_by_id(order.plan_id)
            orders.append({
                'id': order.id,
                'order_no': order.order_no,
                'plan_name': plan.name if plan else '未知套餐',
                'original_price': float(order.original_price),
                'actual_price': float(order.actual_price),
                'payment_method': order.payment_method,
                'status': order.status,
                'created_at': order.created_at.isoformat(),
                'paid_time': order.paid_time.isoformat() if order.paid_time else None
            })
        
        return {
            'orders': orders,
            'total': pagination.total,
            'page': page,
            'per_page': per_page,
            'pages': pagination.pages
        }
    
    @staticmethod
    def get_user_benefits(user_id: str) -> List[Dict]:
        """获取用户会员权益"""
        user_benefits = db.session.query(
            UserMembershipBenefit, MembershipBenefit
        ).join(
            MembershipBenefit,
            UserMembershipBenefit.benefit_id == MembershipBenefit.id
        ).filter(
            UserMembershipBenefit.user_id == user_id,
            UserMembershipBenefit.is_active == True
        ).all()
        
        benefits = []
        for ub, benefit in user_benefits:
            benefits.append({
                'id': benefit.id,
                'name': benefit.name,
                'description': benefit.description,
                'icon': benefit.icon,
                'benefit_type': benefit.benefit_type,
                'benefit_value': benefit.benefit_value
            })
        
        return benefits
    
    @staticmethod
    def check_benefit_access(user_id: str, benefit_type: str) -> bool:
        """检查用户是否有某项权益"""
        if not MembershipService.check_membership_valid(user_id):
            return False

        if benefit_type == 'work_english_history':
            return True
        
        benefit = db.session.query(MembershipBenefit).join(
            UserMembershipBenefit,
            MembershipBenefit.id == UserMembershipBenefit.benefit_id
        ).filter(
            UserMembershipBenefit.user_id == user_id,
            UserMembershipBenefit.is_active == True,
            MembershipBenefit.benefit_type == benefit_type,
            MembershipBenefit.is_active == True
        ).first()
        
        return benefit is not None
    
    @staticmethod
    def get_membership_stats(user_id: str) -> Dict:
        """获取会员统计信息"""
        user = User.query.get(user_id)
        membership = MembershipService.get_user_membership(user_id)
        
        # 默认 3 天试用期
        trial_days = 3
        trial_end_date = None
        if user and user.created_at:
            trial_end_date = user.created_at + timedelta(days=trial_days)
        
        now = datetime.now()
        is_trial_expired = False
        if trial_end_date:
            is_trial_expired = now > trial_end_date
            
        is_valid = MembershipService.check_membership_valid(user_id)
        
        # 判定是否需要显示付费弹窗
        # 如果不是 VIP 且试用期已过，则显示
        should_show_payment_dialog = not is_valid and is_trial_expired
        
        # 构造返回结构以匹配 Flutter 前端模型
        stats = {
            'user_id': user_id,
            'vip_level': 'free',
            'trial_end_date': trial_end_date.isoformat() if trial_end_date else None,
            'is_trial_expired': is_trial_expired,
            'has_paid': is_valid,
            'should_show_payment_dialog': should_show_payment_dialog,
            'membership_info': None
        }
        
        if membership:
            stats['vip_level'] = membership.membership_type
            stats['membership_info'] = {
                'type': membership.membership_type,
                'start_date': membership.created_at.isoformat() if membership.created_at else None,
                'end_date': membership.expire_time.isoformat() if membership.expire_time else None,
                'is_active': is_valid
            }
            
        return stats
