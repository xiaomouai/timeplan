# 快速集成：在 home_page.dart 第 2220 行调用拼读 API

## 最简单的方式

在 `home_page.dart` 第 2220 行的 `onTap` 中添加：

```dart
onTap: () async {
  SoundService.playTapSound();
  
  // 🎯 添加这一行显示拼读对话框
  await WordSpellingDialog.show(context, 'hello');
  
  // ... 原有代码保持不变
}
```

## 完整代码示例

```dart
GestureDetector(
  onTap: () async {  // 注意：改为 async
    SoundService.playTapSound();
    
    const firstWord = 'hello';
    const firstMeaning = 'int. 你好；喂；哈喽\nn. "喂"的招呼声或问候声';
    
    // 🎯 显示拼读对话框
    await WordSpellingDialog.show(context, firstWord);
    
    // 原有逻辑
    WordData wordData;
    try {
      wordData = _words.firstWhere((w) => w.word.toLowerCase() == firstWord.toLowerCase());
    } catch (_) {
      wordData = const WordData(word: firstWord, translation: firstMeaning);
    }
    
    ExtendedWordData.fromWordData(wordData, PronunciationType.uk).then((extended) {
      setState(() {
        _currentWord = extended;
        _isLearningMode = true;
        _isUnitListMode = false;
        _learningStep = 0;
        _initLearningStepData();
      });
    });
  },
  child: Container(
    // ... 按钮样式
  ),
),
```

## 已完成的准备工作

✅ 已添加导入语句（第 20-21 行）
✅ 已创建 `WordSpellingService` 服务
✅ 已创建 `WordSpellingDialog` 对话框组件
✅ API 服务器可用（运行 `python xuebaApi/api/word_spelling.py`）

## 启动 API 服务器

```bash
cd xuebaApi
python api/word_spelling.py
```

服务器将在 http://localhost:5000 运行
