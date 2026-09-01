"""
用户服务
"""
from models import db, User, UserWord, CheckinRecord
from datetime import datetime, date
import hashlib
import uuid
import random
import string
from typing import Optional, Dict, Any


class UserService:
    """用户服务类"""
    
    @staticmethod
    def generate_user_id() -> str:
        """生成用户ID"""
        return uuid.uuid4().hex[:24]
    
    @staticmethod
    def generate_invite_code() -> str:
        """生成邀请码"""
        return ''.join(random.choices(string.ascii_uppercase + string.digits, k=6))
    
    @staticmethod
    def hash_password(password: str) -> str:
        """密码加密"""
        return hashlib.sha256(password.encode()).hexdigest()
    
    @staticmethod
    def verify_password(password_hash: str, password: str) -> bool:
        """验证密码"""
        return password_hash == UserService.hash_password(password)
    
    @staticmethod
    def create_user(phone: str, password: str, role: str = 'student', **kwargs) -> Optional[User]:
        """
        创建用户
        
        Args:
            phone: 手机号
            password: 密码
            role: 角色（student/parent）
            **kwargs: 其他用户信息
            
        Returns:
            用户对象或None
        """
        try:
            # 检查手机号是否已存在
            if User.query.filter_by(phone=phone).first():
                return None
            
            # 创建用户
            user = User(
                id=UserService.generate_user_id(),
                phone=phone,
                password_hash=UserService.hash_password(password),
                nickname=kwargs.get('nickname', f'用户{phone[-4:]}'),
                avatar=kwargs.get('avatar', 'https://cdn.lioneng.com/avatars/default.png'),
                role=role,
                grade=kwargs.get('grade'),
                gender=kwargs.get('gender', 'unknown'),
                birthday=kwargs.get('birthday'),
                invite_code=UserService.generate_invite_code(),
                invited_by=kwargs.get('invited_by'),
                level=1,
                exp=0,
                points=0,
                streak_days=0,
                status='active'
            )
            
            db.session.add(user)
            db.session.commit()
            
            return user
        except Exception as e:
            db.session.rollback()
            print(f"Create user error: {e}")
            return None
    
    @staticmethod
    def get_user_by_phone(phone: str) -> Optional[User]:
        """根据手机号获取用户"""
        return User.query.filter_by(phone=phone).first()
    
    @staticmethod
    def get_user_by_id(user_id: str) -> Optional[User]:
        """根据ID获取用户"""
        return User.query.filter_by(id=user_id).first()
    
    @staticmethod
    def update_user(user_id: str, **kwargs) -> Optional[User]:
        """
        更新用户信息
        
        Args:
            user_id: 用户ID
            **kwargs: 要更新的字段
            
        Returns:
            更新后的用户对象或None
        """
        try:
            user = User.query.filter_by(id=user_id).first()
            if not user:
                return None
            
            # 更新允许的字段
            allowed_fields = ['nickname', 'avatar', 'gender', 'birthday', 'grade']
            for field in allowed_fields:
                if field in kwargs:
                    setattr(user, field, kwargs[field])
            
            user.updated_at = datetime.utcnow()
            db.session.commit()
            
            return user
        except Exception as e:
            db.session.rollback()
            print(f"Update user error: {e}")
            return None
    
    @staticmethod
    def checkin(user_id: str) -> Dict[str, Any]:
        """
        用户签到
        
        Args:
            user_id: 用户ID
            
        Returns:
            签到结果
        """
        try:
            user = User.query.filter_by(id=user_id).first()
            if not user:
                return {'success': False, 'message': '用户不存在'}
            
            today = date.today()
            
            # 检查今天是否已签到
            existing_checkin = CheckinRecord.query.filter_by(
                user_id=user_id,
                date=today
            ).first()
            
            if existing_checkin:
                return {
                    'success': False,
                    'message': '今日已签到',
                    'streak_days': user.streak_days
                }
            
            # 检查连续签到天数
            yesterday = date.today().replace(day=date.today().day - 1)
            yesterday_checkin = CheckinRecord.query.filter_by(
                user_id=user_id,
                date=yesterday
            ).first()
            
            if yesterday_checkin:
                user.streak_days += 1
            else:
                user.streak_days = 1
            
            # 计算奖励
            base_points = 10
            bonus_points = min(user.streak_days - 1, 10)  # 连续签到奖励，最多+10
            total_points = base_points + bonus_points
            
            # 创建签到记录
            checkin = CheckinRecord(
                id=uuid.uuid4().hex,
                user_id=user_id,
                date=today,
                streak_days=user.streak_days,
                points_earned=total_points
            )
            
            # 更新用户积分
            user.points += total_points
            
            db.session.add(checkin)
            db.session.commit()
            
            return {
                'success': True,
                'date': today.isoformat(),
                'streak_days': user.streak_days,
                'points_earned': base_points,
                'bonus_points': bonus_points,
                'total_points': total_points,
                'next_milestone': {
                    'days': ((user.streak_days // 7) + 1) * 7,
                    'reward': '神秘宝箱'
                }
            }
        except Exception as e:
            db.session.rollback()
            print(f"Checkin error: {e}")
            return {'success': False, 'message': f'签到失败: {str(e)}'}
    
    @staticmethod
    def get_user_statistics(user_id: str) -> Dict[str, Any]:
        """
        获取用户统计信息
        
        Args:
            user_id: 用户ID
            
        Returns:
            统计信息
        """
        user = User.query.filter_by(id=user_id).first()
        if not user:
            return {}
        
        # 统计学习单词数
        total_words = UserWord.query.filter_by(user_id=user_id).count()
        mastered_words = UserWord.query.filter_by(
            user_id=user_id
        ).filter(UserWord.mastery_level >= 4).count()
        
        # 统计签到天数
        total_checkin_days = CheckinRecord.query.filter_by(user_id=user_id).count()
        
        return {
            'user_id': user_id,
            'level': user.level,
            'exp': user.exp,
            'points': user.points,
            'streak_days': user.streak_days,
            'total_words': total_words,
            'mastered_words': mastered_words,
            'total_checkin_days': total_checkin_days
        }
