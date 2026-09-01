# 单词拼读 API 集成指南

## 概述

已成功集成单词拼读 API，支持 4 种拼读模式：
- 字母拼读 (letter)
- 音节拼读 (syllable)
- 音素拼读 (phoneme)
- 自然拼读 (phonics)

## 文件结构

```
xuebaAPP/lib/
├── services/
│   └── word_spelling_service.dart    # API 服务
├── widgets/
│   └── word_spelling_dialog.dart     # 拼读对话框组件
└── examples/
    └── spelling_integration_example.dart  # 集成示例
```

## 快速开始

### 1. 在 home_page.dart 中调用

在 `home_page.dart` 的第 2220 行附近，已添加必要的导入：

```dart
import '../services/word_spelling_service.dart';
import '../widgets/word_spelling_dialog.dart';
```

### 2. 显示拼读对话框

最简单的方式是显示拼读对话框：

```dart
// 在按钮的 onTap 中调用
onTap: () {
  SoundService.playTapSound();
  
  // 显示单词拼读对话框
  WordSpellingDialog.show(context, 'hello');
},
```

### 3. 获取单个拼读模式

```dart
// 获取音节拼读
final result = await WordSpellingService.spellWord(
  'computer',
  mode: SpellingMode.syllable,
);

print(result.display);  // "com - put - er"
print(result.parts);    // ["com", "put", "er"]
```

### 4. 获取所有拼读模式

```dart
final all = await WordSpellingService.spellAllModes('cat');

// 访问不同模式
print(all.spellings['letter']?.display);   // "C - A - T"
print(all.spellings['syllable']?.display); // "cat"
print(all.spellings['phoneme']?.display);  // "/k/ /æ/ /t/"
print(all.spellings['phoneme']?.ipa);      // "/kæt/"
```

### 5. 获取发音信息

```dart
final pronunciation = await WordSpellingService.getPronunciation('python');

print(pronunciation.ipa);      // "/paɪθɑn/"
print(pronunciation.phonemes); // ["P", "AY1", "TH", "AA0", "N"]
print(pronunciation.display);  // "/p/ /aɪ/ /θ/ /ɑ/ /n/"
```

### 6. 批量拼读

```dart
final results = await WordSpellingService.spellBatch(
  ['cat', 'dog', 'bird'],
  mode: SpellingMode.phoneme,
);

for (var result in results) {
  print('${result.word}: ${result.display}');
}
```

## 在 home_page.dart 中的具体集成位置

### 位置 1: 开始学习按钮 (第 2220 行)

```dart
GestureDetector(
  onTap: () async {
    SoundService.playTapSound();
    
    const firstWord = 'hello';
    
    // 选项 A: 显示拼读对话框
    await WordSpellingDialog.show(context, firstWord);
    
    // 选项 B: 获取拼读信息后使用
    try {
      final spelling = await WordSpellingService.spellWord(
        firstWord,
        mode: SpellingMode.syllable,
      );
      
      // 使用拼读信息...
      print('音节: ${spelling.display}');
      
    } catch (e) {
      print('获取拼读失败: $e');
    }
    
    // 原有的学习逻辑...
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

### 位置 2: 单词列表项点击 (第 2306 行附近)

```dart
Widget _buildUnitWordItem(String word, String meaning) {
  return GestureDetector(
    onTap: () async {
      SoundService.playTapSound();
      
      // 显示拼读对话框
      await WordSpellingDialog.show(context, word);
      
      // 原有的学习逻辑...
      WordData wordData;
      try {
        wordData = _words.firstWhere((w) => w.word.toLowerCase() == word.toLowerCase());
      } catch (_) {
        wordData = WordData(word: word, translation: meaning);
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
      // ... 列表项样式
    ),
  );
}
```

## API 配置

确保 API 服务器正在运行：

```bash
cd xuebaApi
python api/word_spelling.py
```

API 配置在 `lib/config/api_config.dart`：

```dart
static const String devBaseUrl = 'http://localhost:5000/api';
```

## 数据模型

### SpellingResult
```dart
class SpellingResult {
  final String word;        // 单词
  final String mode;        // 模式
  final List<String> parts; // 拼读部分
  final String display;     // 显示文本
  final String speakText;   // 朗读文本
  final String? ipa;        // IPA 音标
}
```

### AllSpellingsResult
```dart
class AllSpellingsResult {
  final String word;
  final Map<String, SpellingModeResult> spellings;
}
```

### PronunciationInfo
```dart
class PronunciationInfo {
  final String word;
  final String? ipa;
  final List<String> phonemes;
  final String display;
}
```

## 错误处理

```dart
try {
  final result = await WordSpellingService.spellWord('hello');
  // 使用结果...
} catch (e) {
  // 处理错误
  print('拼读失败: $e');
  
  // 显示错误提示
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('获取拼读失败: $e')),
    );
  }
}
```

## 测试

运行示例页面查看所有功能：

```dart
// 在你的路由中添加
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const SpellingIntegrationExample(),
  ),
);
```

## 注意事项

1. **API 服务器**: 确保后端 API 服务器正在运行
2. **网络权限**: 确保应用有网络访问权限
3. **异步处理**: 所有 API 调用都是异步的，需要使用 `await`
4. **错误处理**: 建议添加 try-catch 处理网络错误
5. **上下文检查**: 在异步操作后使用 `mounted` 检查 widget 是否还在树中

## 下一步

- 可以在学习模式中添加拼读按钮
- 在单词详情页显示拼读信息
- 添加拼读练习功能
- 集成语音朗读功能
