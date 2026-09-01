import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../utils/sound_service.dart';
import '../../../utils/cache_service.dart';
import '../../../utils/learning_data_service.dart';
import '../../../utils/settings_helper.dart';
import '../../../utils/spaced_repetition_service.dart';
import '../../phonetics_practice_page.dart';

/// 首页“计划”标签页
/// 展示用户的每日学习目标、任务清单以及学习统计
class PlanTab extends StatefulWidget {
  const PlanTab({super.key});

  @override
  State<PlanTab> createState() => _PlanTabState();
}

class _PlanTabState extends State<PlanTab> {
  LearningStats? _stats;
  LearningProgress? _progress;
  int _dailyGoal = 30;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLearningData();
  }

  Future<void> _loadLearningData() async {
    try {
      final wordBookName = await CacheService.getSelectedWordBook() ?? 'default';
      final results = await Future.wait([
        LearningDataService.instance.getLearningStats(wordBookName),
        LearningDataService.instance.getStudyProgress(wordBookName),
        SettingsHelper.getDailyGoalWords(),
      ]);
      if (!mounted) return;
      setState(() {
        _stats = results[0] as LearningStats;
        _progress = results[1] as LearningProgress;
        _dailyGoal = results[2] as int;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '学习计划',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1A535C)),
              ),
              const SizedBox(height: 20),
              
              // 1. 今日目标卡片
              _buildPlanCard(context),
              const SizedBox(height: 24),
              
              // 2. 今日任务列表
              _buildTaskSection(context),
              const SizedBox(height: 24),
              
              // 3. 学习统计概览
              _buildStatsOverview(),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建今日目标卡片
  Widget _buildPlanCard(BuildContext context) {
    final progress = _progress;
    final stats = _stats;
    final todayStudied = progress?.todayStudied ?? 0;
    final dueWords = progress?.dueWords ?? stats?.dueWords ?? 0;
    final completedWords = math.min(todayStudied, _dailyGoal) +
        math.min(stats?.todayReviews ?? 0, dueWords);
    final targetWords = _dailyGoal + dueWords;
    final completion = targetWords == 0 ? 0.0 : (completedWords / targetWords).clamp(0.0, 1.0).toDouble();
    final remainingNew = math.max(0, _dailyGoal - todayStudied);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Theme.of(context).primaryColor, const Color(0xFF88D8C0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).primaryColor.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('今日目标', style: TextStyle(color: Colors.white70, fontSize: 14)),
          SizedBox(height: 8),
          Text('新词 ${remainingNew} / 复习 ${dueWords}', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          SizedBox(height: 20),
          Row(
            children: [
              Icon(Icons.timer_outlined, color: Colors.white70, size: 16),
              SizedBox(width: 4),
              Text('预计耗时 ${math.max(1, ((remainingNew + dueWords) * 0.5).ceil())} 分钟', style: TextStyle(color: Colors.white70, fontSize: 12)),
              Spacer(),
              Text('已完成 ${(completion * 100).round()}%', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          SizedBox(height: 8),
          LinearProgressIndicator(
            value: completion,
            backgroundColor: Colors.white24,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            minHeight: 6,
          ),
        ],
      ),
    );
  }

  /// 构建今日任务板块
  Widget _buildTaskSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '今日任务',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A535C)),
        ),
        const SizedBox(height: 16),
        _buildTaskItem(context, '基础词汇练习', '完成 $_dailyGoal 个新词的学习', (_progress?.todayStudied ?? 0) >= _dailyGoal, () {
          // 跳转到词库选择或单词学习
          Navigator.pushNamed(context, '/library');
        }),
        _buildTaskItem(context, '听力强化训练', '完成 5 分钟的听力磨耳朵', false, () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('听力强化训练功能开发中')),
          );
        }),
        _buildTaskItem(context, '口语测评', '完成 Unit 1 的单词跟读', (_stats?.todayReviews ?? 0) > 0, () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const PhoneticsPracticePage()),
          );
        }),
      ],
    );
  }

  /// 构建单个任务项
  Widget _buildTaskItem(BuildContext context, String title, String subtitle, bool isCompleted, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        SoundService.playTapSound();
        onTap();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted ? const Color(0xFF00C897) : Colors.grey.shade100,
                border: isCompleted ? null : Border.all(color: Colors.grey.shade300),
              ),
              child: isCompleted 
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isCompleted ? Colors.grey : const Color(0xFF1A535C),
                      decoration: isCompleted ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey.shade300),
          ],
        ),
      ),
    );
  }

  /// 构建学习统计概览
  Widget _buildStatsOverview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '学习统计',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A535C)),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildStatCard('坚持天数', _loading ? '—' : '${_stats?.learningDays ?? 0}', '天', Colors.orange),
            const SizedBox(width: 12),
            _buildStatCard('累计词量', _loading ? '—' : '${_stats?.totalWords ?? 0}', '词', Colors.blue),
          ],
        ),
      ],
    );
  }

  /// 构建单个统计卡片
  Widget _buildStatCard(String label, String value, String unit, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: color)),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
                ),
                const SizedBox(width: 4),
                Text(unit, style: TextStyle(fontSize: 12, color: color.withOpacity(0.7))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
