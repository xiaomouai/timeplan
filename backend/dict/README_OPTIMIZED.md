# 单词本数据源

数据来源：有道背单词 APP

## 📚 快速导航

- [数据格式说明](#数据格式说明)
- [词书列表](#词书列表)
- [使用方法](#使用方法)
- [API接口](#api接口)

## 数据格式说明

### JSON 结构示例

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
        "trans": [{"pos": "vt", "tranCn": "取消，撤销；删去"}],
        "sentence": {
          "sentences": [
            {"sContent": "Our flight was cancelled.", "sCn": "我们的航班取消了。"}
          ]
        },
        "phrase": {
          "phrases": [{"pContent": "cancel button", "pCn": "取消按钮"}]
        },
        "syno": {"synos": [{"pos": "vt", "tran": "取消", "hwds": [{"w": "recall"}]}]},
        "exam": [{"question": "...", "answer": {...}, "choices": [...]}]
      }
    }
  }
}
```

### 字段说明

| 字段 | 说明 | 示例 |
|------|------|------|
| wordRank | 单词序号 | 1 |
| headWord | 单词 | "cancel" |
| bookId | 词书ID | "CET4_3" |
| usphone | 美音音标 | "'kænsl" |
| ukphone | 英音音标 | "'kænsl" |
| trans | 翻译（含词性） | [{"pos": "vt", "tranCn": "取消"}] |
| sentence | 例句 | {"sentences": [...]} |
| phrase | 短语 | {"phrases": [...]} |
| syno | 近义词 | {"synos": [...]} |
| relWord | 同根词 | {"rels": [...]} |
| exam | 测试题 | [{"question": "...", ...}] |

## 词书列表

### 大学英语考试

| ID | 词书名称 | 单词数 | 背诵人数 | 标签 |
|----|----------|--------|----------|------|
| CET4luan_1 | 四级真题核心词（图片记忆） | 1,162 | 875,260 | 四级/有道 |
| CET4luan_2 | 四级英语词汇 | 3,739 | 215,979 | 四级/有道 |
| CET4_3 | 新东方四级词汇 | 2,607 | 3,063 | 四级/新东方 |
| CET6luan_1 | 六级真题核心词（图片记忆） | 1,228 | 218,418 | 六级/有道 |
| CET6_2 | 六级英语词汇 | 2,078 | 64,093 | 六级/有道 |
| CET6_3 | 新东方六级词汇 | 2,345 | 1,193 | 六级/新东方 |

### 考研/专业考试

| ID | 词书名称 | 单词数 | 背诵人数 | 标签 |
|----|----------|--------|----------|------|
| KaoYanluan_1 | 考研必考词汇 | 1,341 | 252,505 | 考研/有道 |
| KaoYan_2 | 考研英语词汇 | 4,533 | 147,205 | 考研/有道 |
| KaoYan_3 | 新东方考研词汇 | 3,728 | 2,644 | 考研/新东方 |
| Level4luan_1 | 专四真题高频词 | 595 | 62,169 | 专四/有道 |
| Level8_1 | 专八真题高频词 | 684 | 30,059 | 专八/有道 |

### 出国考试

| ID | 词书名称 | 单词数 | 背诵人数 | 标签 |
|----|----------|--------|----------|------|
| IELTSluan_2 | 雅思词汇 | 3,427 | 276,495 | IELTS/有道 |
| IELTS_3 | 新东方雅思词汇 | 3,575 | 1,707 | IELTS/新东方 |
| TOEFL_2 | TOEFL词汇 | 9,213 | 118,896 | TOEFL/有道 |
| TOEFL_3 | 新东方TOEFL词汇 | 4,264 | 1,294 | TOEFL/新东方 |
| GRE_2 | GRE词汇 | 7,199 | 47,072 | GRE/有道 |
| GRE_3 | 新东方GRE词汇 | 6,515 | 673 | GRE/新东方 |
| SAT_2 | SAT词汇 | 4,423 | 13,876 | SAT/有道 |
| GMATluan_2 | GMAT词汇 | 3,254 | 14,874 | GMAT/有道 |
| BEC_2 | 商务英语词汇 | 2,753 | 300,528 | BEC |

### 中小学教材

| ID | 词书名称 | 单词数 | 背诵人数 | 标签 |
|----|----------|--------|----------|------|
| ChuZhongluan_2 | 中考必备词汇 | 1,420 | 273,321 | 中考/有道 |
| GaoZhongluan_2 | 高考必备词汇（图片记忆） | 3,668 | 256,873 | 高考/有道 |
| PEPXiaoXue3_1 | 人教版小学英语-三年级上册 | 64 | 378,234 | 人教版 |
| PEPChuZhong7_1 | 人教版初中英语-七年级上册 | 392 | 126,509 | 人教版 |
| PEPGaoZhong_1 | 人教版高中英语-必修1 | 311 | 114,721 | 人教版 |

## 使用方法

### 1. 数据预处理

```python
import json
import zipfile

def load_words_from_zip(zip_path):
    """从ZIP文件加载单词数据"""
    words = []
    with zipfile.ZipFile(zip_path, 'r') as zip_ref:
        for json_file in zip_ref.namelist():
            if json_file.endswith('.json'):
                with zip_ref.open(json_file) as f:
                    word_data = json.load(f)
                    words.append(word_data)
    return words

# 使用示例
words = load_words_from_zip('./book/1521164643060_CET4_3.zip')
print(f"加载了 {len(words)} 个单词")
```

### 2. 法语字母处理

部分词典混入了法语字母，使用以下代码处理：

```python
def replace_french_chars(text):
    """替换法语字符为英语字符"""
    replacements = [
        ('é', 'e'), ('ê', 'e'), ('è', 'e'), ('ë', 'e'),
        ('à', 'a'), ('â', 'a'), ('ç', 'c'),
        ('î', 'i'), ('ï', 'i'), ('ô', 'o'),
        ('ù', 'u'), ('û', 'u'), ('ü', 'u'), ('ÿ', 'y')
    ]
    for fr, en in replacements:
        text = text.replace(fr, en)
    return text
```

### 3. 导入数据库

使用提供的脚本将数据导入SQLite数据库：

```bash
python import_to_db.py
```

## API接口

### 发音接口

有道英语发音接口：

```
https://dict.youdao.com/dictvoice?audio={word}&type={1|2}
```

- `type=1`: 英音
- `type=2`: 美音

示例：
```
https://dict.youdao.com/dictvoice?audio=cancel&type=1
```

## 版权声明

数据来源于有道背单词APP，仅供学习研究使用。

如有侵权，请联系删除。

## 致谢

感谢有道团队和考神团队为中国教育事业做出的贡献。
