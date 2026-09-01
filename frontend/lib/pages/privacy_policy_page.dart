import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../utils/app_theme.dart';

class PrivacyPolicyPage extends StatefulWidget {
  const PrivacyPolicyPage({super.key});

  @override
  State<PrivacyPolicyPage> createState() => _PrivacyPolicyPageState();
}

class _PrivacyPolicyPageState extends State<PrivacyPolicyPage> {
  String? _markdown;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMarkdown();
  }

  Future<void> _loadMarkdown() async {
    try {
      // 优先从ASCII路径加载（Web兼容更好），失败则回退到根目录中文文件名
      String content;
      try {
        content = await rootBundle.loadString('assets/privacy/privacy.md');
      } catch (_) {
        content = await rootBundle.loadString('assets/privacy/privacy.md');
      }
      if (mounted) {
        setState(() {
          _markdown = content;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '加载隐私政策失败：$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackgroundColor : AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('隐私政策'),
        elevation: 0,
      ),
      body: _buildBody(isDark),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            _error!,
            style: TextStyle(
              color: isDark ? AppTheme.darkPrimaryTextColor : AppTheme.darkGray,
            ),
          ),
        ),
      );
    }
    if (_markdown == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Scrollbar(
      child: Markdown(
        data: _markdown!,
        styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
          p: TextStyle(
            fontSize: 14,
            height: 1.6,
            color: isDark ? AppTheme.darkPrimaryTextColor : AppTheme.darkGray,
          ),
          h1: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
          h2: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
          blockquote: TextStyle(
            color: isDark ? AppTheme.mediumGray : AppTheme.coolGray700,
          ),
        ),
        selectable: true,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}
