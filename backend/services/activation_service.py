"""
激活码服务
"""
import secrets
import string
from datetime import datetime, timedelta
from typing import Optional, Tuple, Dict, Any, List
from extensions import db
from models.membership_models import ActivationCode, ActivationLog, UserMembership, MembershipPlan
from models.user_models import User

class ActivationService:
    @staticmethod
    def generate_code(prefix: str = "ACT", length: int = 16) -> str:
        """生成激活码"""
        chars = string.ascii_uppercase + string.digits
        # 排除容易混淆的字符
        chars = chars.replace('O', '').replace('0', '').replace('I', '').replace('1', '').replace('L', '')
        
        raw_code = ''.join(secrets.choice(chars) for _ in range(length))
        # 格式化: ACT-XXXX-XXXX-XXXX-XXXX
        formatted = '-'.join([raw_code[i:i+4] for i in range(0, len(raw_code), 4)])
        return f"{prefix}-{formatted}"

    @staticmethod
    def generate_codes(order_id: str, plan_type: str, quantity: int = 1, duration_days: int = 30) -> List[str]:
        """批量生成激活码"""
        codes = []
        for _ in range(quantity):
            code_str = ActivationService.generate_code()
            # 确保唯一
            while ActivationCode.query.filter_by(code=code_str).first():
                code_str = ActivationService.generate_code()
            
            new_code = ActivationCode(
                code=code_str,
                order_id=order_id,
                plan_type=plan_type,
                duration_days=duration_days,
                status=0,
                expired_at=datetime.now() + timedelta(days=365) # 激活码一年内有效
            )
            db.session.add(new_code)
            codes.append(code_str)
        
        db.session.commit()
        return codes

    @staticmethod
    def activate(code: str, user_id: str, device_id: str, ip_address: str = None) -> Tuple[bool, str, Optional[Dict[str, Any]]]:
        """激活激活码"""
        # 1. 查找激活码
        activation_code = ActivationCode.query.filter_by(code=code.strip().upper()).first()
        
        if not activation_code:
            ActivationService._log_activation(code, user_id, device_id, ip_address, 0, "激活码不存在")
            return False, "激活码不存在", None
        
        # 2. 检查状态
        if activation_code.status != 0:
            reasons = {1: "激活码已被使用", 2: "激活码已过期", 3: "激活码已作废"}
            reason = reasons.get(activation_code.status, "激活码无效")
            ActivationService._log_activation(code, user_id, device_id, ip_address, 0, reason)
            return False, reason, None
        
        # 3. 检查激活码本身是否过期
        if activation_code.expired_at and activation_code.expired_at < datetime.now():
            activation_code.status = 2
            db.session.commit()
            ActivationService._log_activation(code, user_id, device_id, ip_address, 0, "激活码已过期")
            return False, "激活码已过期", None

        try:
            # 4. 更新用户信息 (会员时长)
            user_membership = UserMembership.query.filter_by(user_id=user_id).first()
            if not user_membership:
                user_membership = UserMembership(user_id=user_id, membership_type='free')
                db.session.add(user_membership)
            
            # 计算新的过期时间
            now = datetime.now()
            current_expire = user_membership.expire_time if user_membership.expire_time and user_membership.expire_time > now else now
            
            # lifetime 处理
            if activation_code.plan_type == 'lifetime':
                new_expire = None # 永久
                user_membership.membership_type = 'lifetime'
            else:
                new_expire = current_expire + timedelta(days=activation_code.duration_days)
                # 如果是升级到更高级别，或者已经是更高级别，需要处理逻辑。这里简化为直接叠加时长
                # 假设 plan_type 映射到 membership_type
                user_membership.membership_type = activation_code.plan_type
            
            user_membership.expire_time = new_expire
            user_membership.status = 'active'
            user_membership.updated_at = now
            
            # 5. 标记激活码为已使用
            activation_code.status = 1
            activation_code.activated_at = now
            activation_code.activated_by = user_id
            activation_code.activated_device_id = device_id
            
            # 6. 记录日志
            ActivationService._log_activation(code, user_id, device_id, ip_address, 1, "激活成功")
            
            db.session.commit()
            
            return True, "激活成功", {
                "plan_type": activation_code.plan_type,
                "expire_time": new_expire.isoformat() if new_expire else "永久",
                "duration_days": activation_code.duration_days
            }
            
        except Exception as e:
            db.session.rollback()
            ActivationService._log_activation(code, user_id, device_id, ip_address, 0, f"系统错误: {str(e)}")
            return False, f"激活失败: {str(e)}", None

    @staticmethod
    def _log_activation(code: str, user_id: str, device_id: str, ip_address: str, result: int, reason: str):
        """记录激活日志"""
        log = ActivationLog(
            activation_code=code,
            user_id=user_id,
            device_id=device_id,
            ip_address=ip_address,
            result=result,
            failure_reason=reason if result == 0 else None
        )
        db.session.add(log)
        db.session.commit()
