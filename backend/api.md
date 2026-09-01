# 狮子英语 API 重构总结

## 📋 重构概述

本次重构将Dict词库数据（81个词书，153,009个单词）完整集成到狮子英语App的API接口中，实现了教材同步和单词数据的无缝对接。

---

## ✅ 已完成的重构内容

### 1. 教材体系重构

#### Dict词库资源
- **81个词书**: 覆盖小学、初中、高中全学段
- **153,009个单词**: 完整的单词数据
- **3大教材版本**: 人教版、北师大版、外研社版

#### 人教版小学（6-12岁核心用户）
```
PEPXiaoXue3_1  三年级上册  64词
PEPXiaoXue3_2  三年级下册  72词
PEPXiaoXue4_1  四年级上册  84词
PEPXiaoXue4_2  四年级下册  104词
PEPXiaoXue5_1  五年级上册  131词
PEPXiaoXue5_2  五年级下册  156词
PEPXiaoXue6_1  六年级上册  130词
PEPXiaoXue6_2  六年级下册  108词
总计: 849个单词
```

#### 人教版初中
```
PEPChuZhong7_1  七年级上册  392词
PEPChuZhong7_2  七年级下册  492词
PEPChuZhong8_1  八年级上册  419词
PEPChuZhong8_2  八年级下册  466词
PEPChuZhong9_1  九年级全册  551词
总计: 2,320个单词
```

#### 人教版高中
```
PEPGaoZhong_1   必修一  311词
PEPGaoZhong_2   必修二  319词
PEPGaoZhong_3   必修三  366词
PEPGaoZhong_4   必修四  307词
PEPGaoZhong_5   必修五  357词
PEPGaoZhong_6   选修六  391词
PEPGaoZhong_7   选修七  384词
PEPGaoZhong_8   选修八  420词
PEPGaoZhong_9   选修九  352词
PEPGaoZhong_10  选修十  361词
PEPGaoZhong_11  选修十一 309词
总计: 3,977个单词
```

### 2. Dict数据结构映射

#### 原始Dict JSON格式
```json
{
  "wordRank": 1,
  "headWord": "cancel",
  "bookId": "CET4_3",
  "content": {
    "word": {
      "wordId": "CET4_3_1",
      "content": {
        "usphone": "'kænsl",
        "ukphone": "'kænsl",
        "trans": [...],
        "sentence": {...},
        "phrase": {...},
        "syno": {...},
        "relWord": {...},
        "exam": [...]
      }
    }
  }
}
```

#### 重构后的API响应格式
```json
{
  "bookId": "PEPXiaoXue3_1",
  "wordRank": 1,
  "word": "hello",
  "ukphone": "həˈləʊ",
  "usphone": "həˈloʊ",
  "ukspeech": "https://dict.youdao.com/dictvoice?audio=hello&type=1",
  "usspeech": "https://dict.youdao.com/dictvoice?audio=hello&type=2",
  "translations": [...],
  "sentences": [...],
  "phrases": [...],
  "synonyms": [...],
  "relWords": [...],
  "exams": [...],
  "userLearning": {...}
}
```

### 3. 核心API接口重构

#### 教材和单词接口（18个）
1. `GET /api/v1/textbooks` - 获取教材版本列表
2. `GET /api/v1/textbooks/{textbook_id}/books` - 获取词书列表
3. `GET /api/v1/books/{book_id}/words` - 获取单词列表（分页）
4. `GET /api/v1/words/{book_id}/{word_rank}` - 获取单词详情
5. `POST /api/v1/words/{book_id}/{word_rank}/learn` - 更新学习状态
6. `POST /api/v1/words/batch` - 批量获取单词
7. `GET /api/v1/words/search` - 搜索单词
8. `GET /api/v1/words/daily-recommend` - 今日推荐
9. `POST /api/v1/books/{book_id}/units` - 创建单元
10. `GET /api/v1/books/{book_id}/units` - 获取单元列表
11. `GET /api/v1/units/{unit_id}/words` - 获取单元单词

#### 闯关练习接口（3个）
12. `GET /api/v1/units/{unit_id}/challenges` - 获取闯关题目
13. `POST /api/v1/challenges/{challenge_id}/submit` - 提交闯关结果
14. `GET /api/v1/challenges/history` - 闯关历史

#### 听写练习接口（4个）
15. `POST /api/v1/units/{unit_id}/dictation/start` - 开始听写
16. `POST /api/v1/dictations/{dictation_id}/submit` - 提交听写
17. `GET /api/v1/dictations/history` - 听写历史
18. `POST /api/v1/units/{unit_id}/dictation/phrases/start` - 短语听写

### 4. Dict数据特性利用

#### 音频资源
- **有道发音API**: `https://dict.youdao.com/dictvoice?audio={word}&type={1|2}`
- **type=1**: 英音
- **type=2**: 美音
- **免费使用**: 无需额外配置

#### 例句资源
```json
"sentences": [
  {
    "sContent": "Hello, how are you?",
    "sCn": "你好，你好吗？"
  }
]
```

#### 短语资源
```json
"phrases": [
  {
    "pContent": "say hello",
    "pCn": "打招呼；问好"
  }
]
```

#### 考题资源（用于闯关）
```json
"exams": [
  {
    "question": "As we can no longer wait...",
    "examType": 1,
    "choices": [...],
    "answer": {
      "rightIndex": 4,
      "explain": "cancel order：取消订单..."
    }
  }
]
```

#### 同义词资源
```json
"synonyms": [
  {
    "pos": "vt",
    "tran": "[计]取消；删去",
    "hwds": [
      {"w": "recall"},
      {"w": "call it off"}
    ]
  }
]
```

---

## 🔄 数据同步方案

### 方案1: 实时ZIP解析（当前实现）
```python
# 优点：无需数据库迁移，快速启动
# 缺点：首次加载较慢，无法高效查询

@lru_cache(maxsize=10)
def load_book_words(book_id: str):
    zip_path = find_zip_file(book_id)
    return read_words_from_zip(zip_path)
```

### 方案2: 数据库导入（推荐）
```sql
-- 1. 创建词书表
CREATE TABLE dict_books (
    id VARCHAR(32) PRIMARY KEY,
    book_id VARCHAR(50) UNIQUE NOT NULL,
    title VARCHAR(100) NOT NULL,
    word_count INT,
    category VARCHAR(20),
    tag VARCHAR(20),
    grade INT,
    term INT,
    popularity INT DEFAULT 0,
    zip_file VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. 创建单词表
CREATE TABLE dict_words (
    id VARCHAR(32) PRIMARY KEY,
    book_id VARCHAR(50) NOT NULL,
    word_rank INT NOT NULL,
    head_word VARCHAR(100) NOT NULL,
    uk_phone VARCHAR(100),
    us_phone VARCHAR(100),
    content JSON,  -- 存储完整Dict数据
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_book_rank (book_id, word_rank),
    INDEX idx_head_word (head_word),
    INDEX idx_book_id (book_id)
);

-- 3. 导入脚本
python import_dict_to_db.py
```

### 方案3: 混合方案（最优）
```python
# 热门词书（小学1-6年级）-> MySQL
# 其他词书 -> ZIP实时解析 + Redis缓存

HOT_BOOKS = [
    'PEPXiaoXue3_1', 'PEPXiaoXue3_2',
    'PEPXiaoXue4_1', 'PEPXiaoXue4_2',
    'PEPXiaoXue5_1', 'PEPXiaoXue5_2',
    'PEPXiaoXue6_1', 'PEPXiaoXue6_2'
]

def get_word(book_id, word_rank):
    if book_id in HOT_BOOKS:
        return db.query(DictWord).filter_by(
            book_id=book_id, 
            word_rank=word_rank
        ).first()
    else:
        return load_from_zip_with_cache(book_id, word_rank)
```

---

## 📊 性能优化建议

### 1. 缓存策略
```python
# Redis缓存热门单词
CACHE_KEY = f"word:{book_id}:{word_rank}"
redis.setex(CACHE_KEY, 3600, json.dumps(word_data))

# LRU缓存词书数据
@lru_cache(maxsize=20)
def load_book_words(book_id: str):
    pass
```

### 2. 数据预加载
```python
# 应用启动时预加载小学词书
def preload_primary_books():
    for book_id in PRIMARY_BOOKS:
        load_book_words(book_id)
```

### 3. CDN加速
```
# 音频资源CDN
https://cdn.lioneng.com/audio/{word}.mp3

# 图片资源CDN
https://cdn.lioneng.com/images/books/{book_id}.jpg
```

---

## 🎯 下一步工作

### 1. 数据库迁移
- [ ] 编写Dict数据导入脚本
- [ ] 导入人教版小学全系列（849词）
- [ ] 导入人教版初中全系列（2,320词）
- [ ] 建立索引优化查询性能

### 2. API完善
- [ ] 实现AI发音评测接口
- [ ] 实现错题诊断接口
- [ ] 实现家长中心接口
- [ ] 实现会员和支付接口

### 3. 功能增强
- [ ] 单词收藏功能
- [ ] 学习计划功能
- [ ] 离线缓存功能
- [ ] 数据同步功能

### 4. 测试和文档
- [ ] 编写单元测试
- [ ] 编写集成测试
- [ ] 完善API文档
- [ ] 编写部署文档

---

## 📝 使用示例

### 获取三年级上册单词列表
```bash
curl -X GET "http://localhost:5000/api/v1/books/PEPXiaoXue3_1/words?page=1&page_size=20" \
  -H "Authorization: Bearer {token}"
```

### 获取单词详情
```bash
curl -X GET "http://localhost:5000/api/v1/words/PEPXiaoXue3_1/1" \
  -H "Authorization: Bearer {token}"
```

### 开始闯关练习
```bash
curl -X GET "http://localhost:5000/api/v1/units/unit_001/challenges?mode=normal" \
  -H "Authorization: Bearer {token}"
```

### 开始听写练习
```bash
curl -X POST "http://localhost:5000/api/v1/units/unit_001/dictation/start" \
  -H "Authorization: Bearer {token}" \
  -H "Content-Type: application/json" \
  -d '{
    "word_count": 10,
    "mode": "random"
  }'
```

---

## 🔗 相关文档

- [Dict词库README](./xuebaBackend/dict/README.md)
- [API接口文档](./mark市场运营策略/3.API接口)
- [数据库设计](./lioneng-api/docs/DATABASE.md)
- [部署指南](./lioneng-api/docs/DEPLOYMENT.md)


