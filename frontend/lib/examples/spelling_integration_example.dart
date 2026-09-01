import 'package:flutter/material.dart';
import '../services/word_spelling_service.dart';
import '../widgets/word_spelling_dialog.dart';

/// 单词拼读集成示例
/// 
/// 这个文件展示了如何在你的应用中集成单词拼读 API
class SpellingIntegrationExample extends StatelessWidget {
  const SpellingIntegrationExample({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('单词拼读示例'),
        backgroundColor: const Color(0xFF00C897),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection(
            '示例 1: 显示拼读对话框',
            '点击按钮显示单词的所有拼读模式',
            ElevatedButton(
              onPressed: () {
                // 显示拼读对话框
                WordSpellingDialog.show(context, 'computer');
              },
              child: const Text('显示 "computer" 的拼读'),
            ),
          ),
          const SizedBox(height: 20),
          _buildSection(
            '示例 2: 获取单个拼读模式',
            '获取单词的音节拼读',
            ElevatedButton(
              onPressed: () async {
                try {
                  final result = await WordSpellingService.spellWord(
                    'beautiful',
                    mode: SpellingMode.syllable,
                  );
                  
                  if (context.mounted) {
                    _showResultDialog(
                      context,
                      '音节拼读',
                      result.display,
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    _showErrorDialog(context, e.toString());
                  }
                }
              },
              child: const Text('获取 "beautiful" 的音节'),
            ),
          ),
          const SizedBox(height: 20),
          _buildSection(
            '示例 3: 获取发音信息',
            '获取单词的 IPA 音标和音素',
            ElevatedButton(
              onPressed: () async {
                try {
                  final result = await WordSpellingService.getPronunciation('python');
                  
                  if (context.mounted) {
                    _showResultDialog(
                      context,
                      '发音信息',
                      'IPA: ${result.ipa}\n音素: ${result.phonemes.join(" ")}',
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    _showErrorDialog(context, e.toString());
                  }
                }
              },
              child: const Text('获取 "python" 的发音'),
            ),
          ),
          const SizedBox(height: 20),
          _buildSection(
            '示例 4: 批量拼读',
            '一次拼读多个单词',
            ElevatedButton(
              onPressed: () async {
                try {
                  final results = await WordSpellingService.spellBatch(
                    ['cat', 'dog', 'bird'],
                    mode: SpellingMode.phoneme,
                  );
                  
                  final text = results
                      .map((r) => '${r.word}: ${r.display}')
                      .join('\n');
                  
                  if (context.mounted) {
                    _showResultDialog(context, '批量拼读结果', text);
                  }
                } catch (e) {
                  if (context.mounted) {
                    _showErrorDialog(context, e.toString());
                  }
                }
              },
              child: const Text('批量拼读 3 个单词'),
            ),
          ),
          const SizedBox(height: 30),
          _buildCodeExample(),
        ],
      ),
    );
  }

  Widget _buildSection(String title, String description, Widget button) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 12),
            button,
          ],
        ),
      ),
    );
  }

  Widget _buildCodeExample() {
    return Card(
      elevation: 2,
      color: Colors.grey.shade100,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '代码示例',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '''// 在你的代码中使用：

// 1. 显示拼读对话框
WordSpellingDialog.show(context, 'hello');

// 2. 获取单个拼读模式
final result = await WordSpellingService.spellWord(
  'computer',
  mode: SpellingMode.syllable,
);
print(result.display); // "com - put - er"

// 3. 获取所有拼读模式
final all = await WordSpellingService.spellAllModes('cat');
print(all.spellings['letter']?.display); // "C - A - T"

// 4. 获取发音信息
final pronunciation = await WordSpellingService.getPronunciation('python');
print(pronunciation.ipa); // "/paɪθɑn/"

// 5. 批量拼读
final results = await WordSpellingService.spellBatch(
  ['cat', 'dog', 'bird'],
  mode: SpellingMode.phoneme,
);''',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showResultDialog(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(BuildContext context, String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('错误'),
        content: Text(error),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}
''',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showResultDialog(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(BuildContext context, String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('错误'),
        content: Text(error),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}
