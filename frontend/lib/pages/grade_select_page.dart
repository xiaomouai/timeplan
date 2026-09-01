import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/app_theme.dart';
import '../utils/responsive_helper.dart';
import '../services/backend_api_service.dart';
import '../utils/cache_service.dart';
import 'unit_word_list_page.dart';
import 'library_page.dart';
import 'home/controllers/word_learning_controller.dart';

class GradeSelectPage extends StatefulWidget {
  const GradeSelectPage({super.key});

  @override
  State<GradeSelectPage> createState() => _GradeSelectPageState();
}

class _GradeSelectPageState extends State<GradeSelectPage> {
  String? _selectedGrade;
  bool _loading = false;

  final Map<String, List<String>> _gradeKeywords = {
    '幼小衔接': ['幼小', '幼儿园', '启蒙'],
    '一年级': ['一年级', '一年', '小学一'],
    '二年级': ['二年级', '二年', '小学二'],
    '三年级': ['三年级', '三年', '小学三'],
    '四年级': ['四年级', '四年', '小学四'],
    '五年级': ['五年级', '五年', '小学五'],
    '六年级': ['六年级', '六年', '小学六'],
    '七年级': ['七年级', '七年', '初一'],
    '八年级': ['八年级', '八年', '初二'],
    '九年级': ['九年级', '九年', '初三'],
    '高一': ['高一', '高一上', '高一下'],
    '高二': ['高二', '高二上', '高二下'],
    '高三': ['高三', '高三上', '高三下'],
  };

  @override
  Widget build(BuildContext context) {
    final s = (double size) => ResponsiveHelper.s(context, size);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackgroundColor : const Color(0xFFF8FEFD),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          '选择年级',
          style: TextStyle(
            color: const Color(0xFF333333),
            fontSize: s(18),
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF333333)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton(
            onPressed: _skipToLibrary,
            child: Text(
              '跳过',
              style: TextStyle(
                color: Colors.grey,
                fontSize: s(14),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(s(20), s(10), s(20), s(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '请选择您的年级',
                  style: TextStyle(
                    fontSize: s(24),
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF333333),
                  ),
                ),
                SizedBox(height: s(8)),
                Text(
                  '为了更便捷，我们将根据年级自动为您匹配对应教材',
                  style: TextStyle(
                    fontSize: s(13),
                    color: const Color(0xFF999999),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(horizontal: s(20)),
              children: [
                _buildGroup('幼儿园', ['幼小衔接']),
                SizedBox(height: s(25)),
                _buildGroup('小学', ['一年级', '二年级', '三年级', '四年级', '五年级', '六年级']),
                SizedBox(height: s(25)),
                _buildGroup('初中', ['七年级', '八年级', '九年级']),
                SizedBox(height: s(25)),
                _buildGroup('高中', ['高一', '高二', '高三']),
                SizedBox(height: s(40)),
              ],
            ),
          ),
          _buildBottomAction(),
        ],
      ),
    );
  }

  Widget _buildGroup(String title, List<String> grades) {
    final s = (double size) => ResponsiveHelper.s(context, size);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: s(4),
              height: s(16),
              decoration: BoxDecoration(
                color: const Color(0xFF00D191),
                borderRadius: BorderRadius.circular(s(2)),
              ),
            ),
            SizedBox(width: s(8)),
            Text(
              title,
              style: TextStyle(
                fontSize: s(16),
                fontWeight: FontWeight.bold,
                color: const Color(0xFF333333),
              ),
            ),
          ],
        ),
        SizedBox(height: s(15)),
        Wrap(
          spacing: s(12),
          runSpacing: s(12),
          children: grades.map((g) => _buildGradeChip(g)).toList(),
        ),
      ],
    );
  }

  Widget _buildGradeChip(String label) {
    final s = (double size) => ResponsiveHelper.s(context, size);
    final selected = _selectedGrade == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedGrade = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: s(18), vertical: s(10)),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE6FFF3) : Colors.white,
          borderRadius: BorderRadius.circular(s(12)),
          border: Border.all(
            color: selected ? const Color(0xFF00D191) : const Color(0xFFF0F0F0),
            width: selected ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: selected 
                  ? const Color(0xFF00D191).withOpacity(0.1) 
                  : Colors.black.withOpacity(0.02),
              blurRadius: s(10),
              offset: Offset(0, s(4)),
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFF00D191) : const Color(0xFF666666),
            fontSize: s(14),
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomAction() {
    final s = (double size) => ResponsiveHelper.s(context, size);
    return Container(
      padding: EdgeInsets.all(s(20)),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: s(20),
            offset: Offset(0, s(-5)),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: s(50),
          child: ElevatedButton(
            onPressed: _selectedGrade == null || _loading ? null : _confirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00D191),
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFFCCF6E9),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(s(25))),
            ),
            child: _loading
                ? SizedBox(
                    width: s(20), 
                    height: s(20), 
                    child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(
                    '立即开启学习之旅',
                    style: TextStyle(
                      fontSize: s(16),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirm() async {
    if (_selectedGrade == null || _loading) return;
    setState(() => _loading = true);
    try {
      final booksData = await BackendApiService.getBooks();
      if (booksData.isEmpty) {
        _goLibraryWithToast('未获取到教材库列表，请手动选择');
        return;
      }
      final keywords = _gradeKeywords[_selectedGrade!] ?? [_selectedGrade!];
      Map<String, dynamic>? matched;
      for (final b in booksData) {
        final name = (b['name'] ?? '').toString();
        if (keywords.any((k) => name.contains(k))) {
          matched = b;
          break;
        }
      }
      matched ??= booksData.first; // 兜底：选择第一本

      final bookId = (matched['id'] ?? '').toString();
      final bookName = (matched['name'] ?? '').toString();
      if (bookId.isEmpty || bookName.isEmpty) {
        _goLibraryWithToast('匹配教材失败，请手动选择');
        return;
      }

      final words = await BackendApiService.getBookWords(bookId);
      if (words.isEmpty) {
        _goLibraryWithToast('该教材无单词数据，请更换教材');
        return;
      }

      await CacheService.cacheWordData(bookName, words);
      await CacheService.saveSelectedWordBook(bookName, bookId);

      if (!mounted) return;
      final controller = Provider.of<WordLearningController>(context, listen: false);
      await controller.loadWordsFromSelectedWordBook();

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const UnitWordListPage()),
        (route) => false,
      );
    } catch (e) {
      _goLibraryWithToast('自动匹配失败：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _skipToLibrary() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LibraryPage()),
    );
  }

  void _goLibraryWithToast(String message) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
    _skipToLibrary();
  }
}

