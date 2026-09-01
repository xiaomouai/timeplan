import 'package:flutter/material.dart';
import '../services/word_spelling_service.dart';

/// 单词拼读对话框
class WordSpellingDialog extends StatefulWidget {
  final String word;

  const WordSpellingDialog({
    Key? key,
    required this.word,
  }) : super(key: key);

  @override
  State<WordSpellingDialog> createState() => _WordSpellingDialogState();

  /// 显示拼读对话框
  static Future<void> show(BuildContext context, String word) {
    return showDialog(
      context: context,
      builder: (context) => WordSpellingDialog(word: word),
    );
  }
}

class _WordSpellingDialogState extends State<WordSpellingDialog> {
  AllSpellingsResult? _spellings;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSpellings();
  }

  Future<void> _loadSpellings() async {
    try {
      final result = await WordSpellingService.spellAllModes(widget.word);
      setState(() {
        _spellings = result;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            Row(
              children: [
                const Icon(Icons.spellcheck, color: Color(0xFF00C897)),
                const SizedBox(width: 8),
                Text(
                  '单词拼读',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 10),

            // 单词
            Center(
              child: Text(
                widget.word,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF00C897),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 内容
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_error != null)
              Center(
                child: Column(
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 10),
                    Text(
                      '加载失败',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _error!,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else if (_spellings != null)
              _buildSpellingsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSpellingsList() {
    final spellings = _spellings!.spellings;

    return Column(
      children: [
        _buildSpellingItem(
          '字母拼读',
          Icons.abc,
          spellings['letter']?.display ?? '',
          Colors.blue,
        ),
        const SizedBox(height: 12),
        _buildSpellingItem(
          '音节拼读',
          Icons.segment,
          spellings['syllable']?.display ?? '',
          Colors.green,
        ),
        const SizedBox(height: 12),
        _buildSpellingItem(
          '音素拼读',
          Icons.music_note,
          spellings['phoneme']?.display ?? '',
          Colors.orange,
          ipa: spellings['phoneme']?.ipa,
        ),
        const SizedBox(height: 12),
        _buildSpellingItem(
          '自然拼读',
          Icons.nature,
          spellings['phonics']?.display ?? '',
          Colors.purple,
          ipa: spellings['phonics']?.ipa,
        ),
      ],
    );
  }

  Widget _buildSpellingItem(
    String title,
    IconData icon,
    String content,
    Color color, {
    String? ipa,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade800,
            ),
          ),
          if (ipa != null) ...[
            const SizedBox(height: 4),
            Text(
              'IPA: $ipa',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
