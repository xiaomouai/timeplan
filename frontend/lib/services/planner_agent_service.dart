import 'package:uuid/uuid.dart';

import '../models/planner_models.dart';
import 'planner_api.dart';

/// timePlan 计划 Agent：把一段文本/语音转写输入分解为结构化计划表。
///
/// 真实数据来源：优先调用后端 `/planner/decompose`（真实 LLM，qwen/deepseek 经
/// ProviderManager 自动降级），仅在后端不可达时降级为本地规则引擎（离线兜底），
/// 不产出任何模拟数据。
class PlannerAgentService {
  static const String _kNoteBackendDown = '后端 AI 暂不可用，已用本地规则引擎生成';

  /// 分解入口。返回 [PlannerPlan]，内部完成排程（从 [dayStart] 起连续排布）。
  static Future<PlannerPlan> decompose({
    required String input,
    required DateTime dayStart,
  }) async {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return const PlannerPlan(tasks: [], source: 'local', note: '输入为空');
    }

    // 优先调用真实后端 LLM
    try {
      final tasks = await PlannerApi.decompose(trimmed);
      if (tasks.isNotEmpty) {
        return PlannerPlan(
          tasks: schedule(tasks, dayStart),
          source: 'ai',
          note: '',
        );
      }
    } catch (e) {
      // 后端不可用：记录后降级本地规则（非模拟，是基于真实输入的兜底拆解）
      // ignore: avoid_print
      print('[PlannerAgent] 后端分解失败，降级本地规则: $e');
    }

    // 兜底：本地规则引擎（仅后端不可用时）
    return _decomposeLocally(trimmed, dayStart, note: _kNoteBackendDown);
  }

  // ---------------- 本地规则分解（离线兜底） ----------------

  static PlannerPlan _decomposeLocally(String input, DateTime dayStart,
      {String note = ''}) {
    final segments = input
        .replaceAll(RegExp(r'[，,；;。！!？?\n\r]+'), '；')
        .replaceAll(RegExp(r'然后|接着|再|之后|另外|还有'), '；')
        .split('；')
        .map((s) => s.trim())
        .where((s) => s.length >= 2)
        .take(8)
        .toList();

    final tasks = <PlannerTask>[];
    for (final seg in segments) {
      tasks.add(PlannerTask(
        id: _newId(),
        title: seg,
        estimateMinutes: _estimateMinutes(seg),
        priority: _estimatePriority(seg),
        start: dayStart,
      ));
    }
    return PlannerPlan(
        tasks: schedule(tasks, dayStart), source: 'local', note: note);
  }

  static int _estimateMinutes(String text) {
    if (RegExp(r'背|单词|复习|听写|默写|打卡').hasMatch(text)) return 25;
    if (RegExp(r'写|作文|报告|论文|作业|总结|复盘|周记').hasMatch(text)) return 60;
    if (RegExp(r'运动|跑步|健身|游泳|锻炼|球').hasMatch(text)) return 45;
    if (RegExp(r'读|阅读|听|看').hasMatch(text)) return 30;
    if (RegExp(r'整理|打扫|收拾|洗').hasMatch(text)) return 20;
    return 30;
  }

  static TaskPriority _estimatePriority(String text) {
    if (RegExp(r'今天必须|必须|紧急|截止|deadline|交|考试|面试|重要')
        .hasMatch(text)) {
      return TaskPriority.high;
    }
    if (RegExp(r'顺便|有空|可选|如果想|无所谓').hasMatch(text)) {
      return TaskPriority.low;
    }
    return TaskPriority.medium;
  }

  // ---------------- 排程 ----------------

  /// 从 [dayStart] 起把任务连续排布；任务间插 5 分钟休息，跳过 12:00-13:00 午休，
  /// 超过 22:00 顺延到次日 08:00。
  static List<PlannerTask> schedule(List<PlannerTask> tasks, DateTime dayStart) {
    var cursor = _roundToNext5(
      DateTime.now().isAfter(dayStart) ? DateTime.now() : dayStart,
    );
    for (final t in tasks) {
      // 午休跳过
      if (cursor.hour < 13 && cursor.hour >= 12) {
        cursor = DateTime(cursor.year, cursor.month, cursor.day, 13, 0);
      }
      // 深夜顺延
      if (cursor.hour >= 22) {
        final next = cursor.add(const Duration(days: 1));
        cursor = DateTime(next.year, next.month, next.day, 8, 0);
      }
      t.start = cursor;
      cursor = t.end.add(const Duration(minutes: 5));
    }
    return tasks;
  }

  static DateTime _roundToNext5(DateTime t) {
    final minus = t.minute % 5;
    return minus == 0
        ? DateTime(t.year, t.month, t.day, t.hour, t.minute)
        : DateTime(t.year, t.month, t.day, t.hour, t.minute + (5 - minus));
  }

  static const Uuid _uuid = Uuid();

  static String _newId() => _uuid.v4();
}
