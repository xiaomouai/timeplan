# 词书数据导入工具

## 📚 简介

本工具用于将有道背单词的81个词书数据（约20万单词）导入到MySQL数据库。

## 🚀 快速开始

### 1. 安装依赖

```bash
cd ../..  # 回到项目根目录
pip install mysql-connector-python python-dotenv
```

### 2. 配置数据库

编辑项目根目录的 `.env.dict_import` 文件：

```ini
DB_HOST=localhost
DB_USER=root
DB_PASSWORD=你的密码
DB_NAME=xuebadict
```

### 3. 运行导入

在项目根目录运行：

**Windows:**
```bash
import_dict_to_mysql.bat
```

**Linux/Mac:**
```bash
python import_dict_to_mysql.py
```

### 4. 验证导入

```bash
verify_dict_import.bat  # Windows
python verify_dict_import.py  # Linux/Mac
```

## 📁 目录结构

```
dict/
├── book/                  # 词书数据目录
│   ├── *.zip             # ZIP格式的词书文件
│   ├── */                # 解压后的词书目录
│   │   └── *.json       # JSON格式的词书数据
│   └── *.json            # 直接的JSON文件
├── bookLists.txt         # 词书元数据列表
├── download.py           # 词书下载脚本
├── export.py             # 导出脚本
└── README.md             # 本文件
```

## 📊 数据概览

### 词书分类

| 分类 | 数量 | 示例 |
|------|------|------|
| 大学英语 | 20+ | 四级、六级、考研、专四、专八 |
| 留学考试 | 15+ | 雅思、托福、GRE、SAT、GMAT |
| 中小学 | 40+ | 人教版、北师大版、外研社版 |
| 其他 | 6+ | BEC、中考、高考 |

### 数据规模

- **词书总数**: 81个
- **单词总数**: ~200,000
- **例句总数**: ~600,000+
- **数据库大小**: ~1-2GB

## 🗄️ 数据库表

导入后会创建以下7个表：

1. **word_books** - 词书信息表
2. **words** - 单词基本信息表
3. **word_translations** - 单词释义表
4. **word_sentences** - 例句表
5. **word_phrases** - 短语表
6. **word_synonyms** - 近义词表
7. **word_related** - 同根词表

## 📖 详细文档

- [快速开始指南](../../DICT_IMPORT_QUICKSTART.md)
- [详细使用指南](../../DICT_IMPORT_GUIDE.md)
- [项目总结](../../DICT_IMPORT_SUMMARY.md)

## ⚡ 导入时间

- 小型词书（<1000词）：1-2分钟
- 大型词书（>10000词）：5-10分钟  
- **全部81个词书：20-30分钟**

## 💡 使用建议

1. 首次导入建议在网络空闲时进行
2. 导入过程中不要关闭命令行窗口
3. 如果中断可以重新运行，会自动继续
4. 导入完成后运行验证脚本确认数据完整性

## 🔧 故障排除

### 导入失败？

1. 检查MySQL是否启动
2. 检查数据库配置是否正确
3. 确认Python依赖已安装
4. 查看错误日志定位问题

### 数据不完整？

运行验证脚本检查：
```bash
python ../../verify_dict_import.py
```

### 需要重新导入？

可以直接重新运行导入脚本，或先删除数据库：

```sql
DROP DATABASE xuebadict;
CREATE DATABASE xuebadict CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

## 📝 数据来源

- **来源**: 有道背单词 App
- **版权**: 仅供学习研究使用
- **致谢**: 感谢有道团队和考神团队

## 🎯 后续使用

导入完成后，可以在应用中：

1. 展示词书列表
2. 实现单词学习功能
3. 开发单词搜索功能
4. 统计学习进度

---

**需要帮助?** 查看详细文档或提issue
