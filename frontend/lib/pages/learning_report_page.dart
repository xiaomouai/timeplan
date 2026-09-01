import 'package:flutter/material.dart';
import '../utils/learning_data_service.dart';
import '../models/word_learning_record.dart';
import '../models/detailed_learning_record.dart';
import '../utils/chart_helper.dart';
import '../utils/app_theme.dart';
import '../utils/spaced_repetition_service.dart';

class LearningReportPage extends StatefulWidget {
  final String wordBookName;
  const LearningReportPage({super.key, required this.wordBookName});
  @override
  State<LearningReportPage> createState() => _LearningReportPageState();
}

class _LearningReportPageState extends State<LearningReportPage> {
  bool _loading = true;
  List<EnhancedWordLearningRecord> _records = [];
  LearningStats? _stats;
  int _masteredCount = 0;
  double _estimatedHours = 0.0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final records = await LearningDataService.instance.getWordBookRecords(widget.wordBookName);
    final enhanced = records.map((r) => EnhancedWordLearningRecord.fromWordLearningRecord(r)).toList();
    final stats = await LearningDataService.instance.getLearningStats(widget.wordBookName);
    final mastered = records.where((r) => r.memoryLevel == MemoryLevel.mastered).length;
    final totalReviewSessions = records.fold<int>(0, (sum, r) => sum + r.reviewHistory.length);
    final estimatedSeconds = totalReviewSessions * 10;
    setState(() {
      _records = enhanced;
      _stats = stats;
      _masteredCount = mastered;
      _estimatedHours = estimatedSeconds / 3600.0;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('学情详情'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatsHeader(),
                  const SizedBox(height: 16),
                  _sectionTitle('学习进度'),
                  ChartHelper.buildProgressChart(_records),
                  const SizedBox(height: 16),
                  _sectionTitle('记忆程度分布'),
                  ChartHelper.buildMemoryLevelChart(_records),
                  const SizedBox(height: 16),
                  _sectionTitle('学习模式分布'),
                  ChartHelper.buildLearningModeChart(_records),
                  const SizedBox(height: 16),
                  _sectionTitle('成绩趋势'),
                  ChartHelper.buildScoreTrendChart(_records),
                ],
              ),
            ),
    );
  }

  Widget _buildStatsHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardColor : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem('总词数', (_stats?.totalWords ?? 0).toString(), Icons.library_books_outlined),
          _statItem('掌握单词', _masteredCount.toString(), Icons.check_circle_outline),
          _statItem('待复习', (_stats?.dueWords ?? 0).toString(), Icons.repeat_rounded),
          _statItem('累计时长', '${_estimatedHours.toStringAsFixed(1)}h', Icons.timer_outlined),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.grey.shade500, size: 22),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold));
  }
}
