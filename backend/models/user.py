"""
用户模型
"""
from datetime import datetime
import hashlib
import uuid


class User:
    """用户模型"""
    
    def __init__(self, user_id=None, phone=None, email=None, password_hash=None,
                 nickname=None, avatar=None, role='student', vip_level='free',
                 vip_expire_at=None, created_at=None, updated_at=None):
        self.user_id = user_id or self._generate_user_id()
        self.phone = phone
        self.email = email
        self.password_hash = password_hash
        self.nickname = nickname or f'用户{self.user_id[:8]}'
        self.avatar = avatar or 'https://cdn.lioneng.com/avatars/default.png'
        self.role = role  # student/teacher/parent/admin
        self.vip_level = vip_level  # free/basic/premium/ultimate
        self.vip_expire_at = vip_expire_at
        self.created_at = created_at or datetime.now()
        self.updated_at = updated_at or datetime.now()
    
    @staticmethod
    def _generate_user_id():
        """生成用户ID"""
        return uuid.uuid4().hex[:24]
    
    @staticmethod
    def hash_password(password):
        """密码加密"""
        return hashlib.sha256(password.encode()).hexdigest()
    
    def verify_password(self, password):
        """验证密码"""
        return self.password_hash == self.hash_password(password)
    
    def to_dict(self, include_sensitive=False):
        """转换为字典"""
        data = {
            'user_id': self.user_id,
            'phone': self.phone,
            'email': self.email,
            'nickname': self.nickname,
            'avatar': self.avatar,
            'role': self.role,
            'vip_level': self.vip_level,
            'vip_expire_at': self.vip_expire_at.isoformat() if self.vip_expire_at else None,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None,
        }
        
        if include_sensitive:
            data['password_hash'] = self.password_hash
        
        return data
    
    @classmethod
    def from_dict(cls, data):
        """从字典创建用户对象"""
        return cls(
            user_id=data.get('user_id'),
            phone=data.get('phone'),
            email=data.get('email'),
            password_hash=data.get('password_hash'),
            nickname=data.get('nickname'),
            avatar=data.get('avatar'),
            role=data.get('role', 'student'),
            vip_level=data.get('vip_level', 'free'),
            vip_expire_at=data.get('vip_expire_at'),
            created_at=data.get('created_at'),
            updated_at=data.get('updated_at')
        )


class UserStorage:
    """用户存储（简单的内存存储，实际应使用数据库）"""
    
    _users = {}  # user_id -> User
    _phone_index = {}  # phone -> user_id
    _email_index = {}  # email -> user_id
    
    @classmethod
    def create_user(cls, user):
        """创建用户"""
        cls._users[user.user_id] = user
        if user.phone:
            cls._phone_index[user.phone] = user.user_id
        if user.email:
            cls._email_index[user.email] = user.user_id
        return user
    
    @classmethod
    def get_user_by_id(cls, user_id):
        """根据ID获取用户"""
        return cls._users.get(user_id)
    
    @classmethod
    def get_user_by_phone(cls, phone):
        """根据手机号获取用户"""
        user_id = cls._phone_index.get(phone)
        return cls._users.get(user_id) if user_id else None
    
    @classmethod
    def get_user_by_email(cls, email):
        """根据邮箱获取用户"""
        user_id = cls._email_index.get(email)
        return cls._users.get(user_id) if user_id else None
    
    @classmethod
    def update_user(cls, user):
        """更新用户"""
        user.updated_at = datetime.now()
        cls._users[user.user_id] = user
        return user
    
    @classmethod
    def delete_user(cls, user_id):
        """删除用户"""
        user = cls._users.pop(user_id, None)
        if user:
            if user.phone:
                cls._phone_index.pop(user.phone, None)
            if user.email:
                cls._email_index.pop(user.email, None)
        return user is not None
    
    @classmethod
    def phone_exists(cls, phone):
        """检查手机号是否存在"""
        return phone in cls._phone_index
    
    @classmethod
    def email_exists(cls, email):
        """检查邮箱是否存在"""
        return email in cls._email_index
