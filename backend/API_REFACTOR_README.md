# 狮子英语 API 重构说明

## 📋 重构概述

本次重构将原有基于模拟数据和SQLite的API改造为使用MySQL数据库的真实数据接口，主要完成以下工作：

### ✅ 已完成的工作

1. **数据库模型层重构**
   - 创建完整的SQLAlchemy ORM模型
   - 支持MySQL数据库
   - 包含用户、单词、学习记录、会员等所有表

2. **服务层创建**
   - `WordService`: 单词数据服务
   - `UserService`: 用户数据服务
   - 封装数据库操作逻辑

3. **API接口重构**
   - ✅ 教材相关API (`textbook.py`)
   - ✅ 单词相关API (`word.py`)
   - ✅ 用户认证API (`auth.py`)
   - ✅ 用户中心API (`user.py`)

---

## 🗄️ 数据库结构

### 核心表

#### 1. 单词相关表
- `word_books`: 词书表（对应dict词库的81个词书）
- `words`: 单词表（153,009个单词）
- `word_translations`: 单词释义表
- `word_sentences`: 例句表
- `word_phrases`: 短语表
- `word_synonyms`: 近义词表
- `word_related`: 同根词表

#### 2. 用户相关表
- `users`: 用户表
- `user_words`: 用户单词学习记录
- `user_achievements`: 用户成就表
- `parent_child`: 家长-孩子关联表
- `checkin_records`: 签到记录表

#### 3. 学习记录表
- `study_logs`: 学习日志
- `wrong_records`: 错题记录
- `pronunciation_records`: 发音评测记录

#### 4. 会员和订单表
- `memberships`: 会员表
- `orders`: 订单表

#### 5. 教材和单元表
- `textbooks`: 教材表
- `units`: 单元表

---

## 🚀 启动指南

### 1. 环境准备

```bash
# 1. 安装依赖
pip install -r requirements.txt

# 2. 配置环境变量（.env文件）
DB_HOST=localhost
DB_PORT=3306
DB_USER=root
DB_PASSWORD=your_password
DB_NAME=xuebadict

JWT_SECRET_KEY=your-jwt-secret-key
SECRET_KEY=your-app-secret-key
```

### 2. 数据库初始化

```bash
# 1. 创建数据库
mysql -u root -p
CREATE DATABASE xuebadict DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

# 2. 导入数据库结构
mysql -u root -p xuebadict < xuebadict.sql

# 3. 导入dict词库数据（如果还没导入）
python import_db.py
```

### 3. 初始化Flask应用

```python
# 在Python环境中运行
from app import create_app
from extensions import db

app = create_app()
with app.app_context():
    db.create_all()  # 创建表结构
```

### 4. 启动服务

```bash
# 开发环境
python app.py

# 或使用Flask命令
flask run --host=0.0.0.0 --port=5000
```

访问API文档: http://localhost:5000/api/docs

---

## 📡 API接口变化

### 1. 教材相关 (`/api/v1/textbooks`)

#### 获取教材列表
```http
GET /api/v1/textbooks?category=小学
```

**变化**: 
- ✅ 从MySQL数据库的`word_books`表读取
- ✅ 自动解析tags字段获取分类、年级等信息
- ✅ 实时统计词书数量和单词总数

#### 获取词书列表
```http
GET /api/v1/books?category=小学&grade=3
```

**变化**:
- ✅ 支持多种筛选条件
- ✅ 返回真实的词书数据

#### 获取单词列表
```http
GET /api/v1/books/PEPXiaoXue3_1/words?page=1&page_size=20
```

**变化**:
- ✅ 从`words`表分页查询
- ✅ 关联查询首个翻译作为简要释义
- ✅ 支持真实的分页

### 2. 单词相关 (`/api/v1/words`)

#### 获取单词详情
```http
GET /api/v1/words/PEPXiaoXue3_1/1
```

**变化**:
- ✅ 从多个表关联查询完整单词数据
- ✅ 包含翻译、例句、短语、近义词、同根词
- ✅ 支持用户学习记录（需登录）

#### 更新学习记录
```http
POST /api/v1/words/PEPXiaoXue3_1/1/learn
Authorization: Bearer {token}
{
  "action": "practice",
  "duration": 30,
  "is_correct": true,
  "score": 95
}
```

**变化**:
- ✅ 真实保存到`user_words`表
- ✅ 自动计算掌握程度和下次复习时间
- ✅ 支持艾宾浩斯遗忘曲线算法

#### 搜索单词
```http
GET /api/v1/words/search?keyword=hello&category=小学&limit=10
```

**变化**:
- ✅ 使用MySQL LIKE查询
- ✅ 支持跨词书搜索
- ✅ 返回搜索耗时统计

### 3. 用户认证 (`/api/v1/auth`)

#### 用户注册
```http
POST /api/v1/auth/register
{
  "phone": "13800138000",
  "code": "123456",
  "password": "password123",
  "role": "student"
}
```

**变化**:
- ✅ 真实保存到`users`表
- ✅ 使用SHA256加密密码
- ✅ 返回JWT token
- ✅ 自动生成邀请码

#### 用户登录
```http
POST /api/v1/auth/login
{
  "phone": "13800138000",
  "password": "password123"
}
```

**变化**:
- ✅ 从数据库验证用户凭证
- ✅ 使用JWT认证机制
- ✅ 返回完整用户信息

### 4. 用户中心 (`/api/v1/user`)

#### 获取用户信息
```http
GET /api/v1/user/profile
Authorization: Bearer {token}
```

**变化**:
- ✅ 从数据库获取真实用户数据
- ✅ 包含学习统计信息
- ✅ 支持JWT认证

#### 用户签到
```http
POST /api/v1/user/checkin
Authorization: Bearer {token}
```

**变化**:
- ✅ 真实记录到`checkin_records`表
- ✅ 自动计算连续签到天数
- ✅ 计算积分奖励

---

## 🔧 配置说明

### 数据库配置 (config.py)

```python
class Config:
    # 数据库配置
    DB_HOST = os.getenv('DB_HOST', 'localhost')
    DB_PORT = int(os.getenv('DB_PORT', 3306))
    DB_USER = os.getenv('DB_USER', 'root')
    DB_PASSWORD = os.getenv('DB_PASSWORD', '')
    DB_NAME = os.getenv('DB_NAME', 'xuebadict')
    
    SQLALCHEMY_DATABASE_URI = f"mysql+pymysql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}?charset=utf8mb4"
    
    # JWT配置
    JWT_SECRET_KEY = os.getenv('JWT_SECRET_KEY', 'dev-jwt-secret-key')
    JWT_ACCESS_TOKEN_EXPIRES = timedelta(days=7)
    JWT_REFRESH_TOKEN_EXPIRES = timedelta(days=30)
```

### Flask扩展初始化 (app.py)

```python
from extensions import db, migrate, jwt

def create_app(config_name=None):
    app = Flask(__name__)
    app.config.from_object(config.get(config_name))
    
    # 初始化扩展
    db.init_app(app)
    migrate.init_app(app, db)
    jwt.init_app(app)
    
    return app
```

---

## 📊 性能优化

### 1. 数据库索引
- 已为常用查询字段添加索引
- `book_id`, `word_rank`, `user_id`等高频字段
- 复合索引优化关联查询

### 2. 查询优化
- 使用分页避免大量数据加载
- 延迟加载关联数据
- 选择性加载字段

### 3. 缓存策略（待实现）
- Redis缓存热门词书数据
- 用户session缓存
- API响应缓存

---

## 🔐 安全特性

### 1. 密码安全
- SHA256加密存储
- 不返回密码hash

### 2. JWT认证
- 访问token 7天有效期
- 刷新token 30天有效期
- 支持token刷新机制

### 3. 数据验证
- 输入参数校验
- SQL注入防护（ORM自动处理）
- XSS防护

---

## 🧪 测试API

### 使用Swagger UI
访问 http://localhost:5000/api/docs 查看交互式API文档

### 使用curl测试

```bash
# 1. 注册用户
curl -X POST http://localhost:5000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "phone": "13800138000",
    "code": "123456",
    "password": "test123",
    "role": "student"
  }'

# 2. 登录获取token
curl -X POST http://localhost:5000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "phone": "13800138000",
    "password": "test123"
  }'

# 3. 获取教材列表
curl http://localhost:5000/api/v1/textbooks

# 4. 获取单词详情
curl http://localhost:5000/api/v1/words/PEPXiaoXue3_1/1

# 5. 搜索单词
curl "http://localhost:5000/api/v1/words/search?keyword=hello&limit=10"

# 6. 获取用户信息（需要token）
curl http://localhost:5000/api/v1/user/profile \
  -H "Authorization: Bearer YOUR_TOKEN_HERE"
```

---

## 📝 TODO列表

### 高优先级
- [ ] 完善闯关和听写API的数据库对接
- [ ] 实现会员系统的真实逻辑
- [ ] 添加Redis缓存
- [ ] 完善单元管理功能

### 中优先级
- [ ] 添加AI推荐算法
- [ ] 实现家长中心功能
- [ ] 完善成就系统
- [ ] 添加排行榜功能

### 低优先级
- [ ] 性能监控和日志
- [ ] API限流
- [ ] 数据备份策略
- [ ] 监控告警

---

## 🐛 常见问题

### 1. 数据库连接失败
**问题**: `OperationalError: (2003, "Can't connect to MySQL server")`
**解决**: 
- 检查MySQL服务是否启动
- 确认.env文件中的数据库配置
- 检查防火墙设置

### 2. JWT token无效
**问题**: `"msg": "Token has expired"`
**解决**:
- 使用refresh token刷新access token
- 重新登录获取新token

### 3. 数据为空
**问题**: API返回空数据
**解决**:
- 确认已运行`import_db.py`导入dict词库数据
- 检查数据库表是否有数据: `SELECT COUNT(*) FROM word_books;`

---

## 📞 联系方式

如有问题，请联系开发团队或查看项目文档。

---

**最后更新**: 2026-02-05
**版本**: V2.0.0
**状态**: ✅ 核心功能已完成，可用于开发测试
