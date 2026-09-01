import '../models/planner_models.dart';

/// 单日执行统计
class DayStats {
  final int totalTasks;
  final int doneTasks;
  final int overdueTasks;
  final int inProgressTasks;
  final int pomodoros;
  final int plannedMinutes;
  final int focusMinutes;

  const DayStats({
    required this.totalTasks,
    required this.doneTasks,
    required this.overdueTasks,
    required this.inProgressTasks,
    required this.pomodoros,
    required this.plannedMinutes,
    required this.focusMinutes,
  });

  double get completionRate =>
      totalTasks == 0 ? 0 : doneTasks / totalTasks;

  /// 计划完成度：实际专注分钟 / 计划分钟（可超过 100%，反映多投入）
  double get effortRate =>
      plannedMinutes == 0 ? 0 : focusMinutes / plannedMinutes;

  /// 自动反馈评语
  String get comment {
    if (totalTasks == 0) return '先添加一个计划，从一个番茄开始这一天的高效节奏。';
    final pct = (completionRate * 100).toStringAsFixed(0);
    if (completionRate >= 1.0) {
      return '太棒了！$totalTasks 项计划全部完成，累计专注 $focusMinutes 分钟，继续保持！';
    }
    if (overdueTasks > 0) {
      return '有 $overdueTasks 项已过计划时间还没完成（完成 $pct%），建议先集中清掉逾期项。';
    }
    if (inProgressTasks > 0) {
      return '$inProgressTasks 项正在推进（完成 $pct%），已专注 $focusMinutes 分钟，再来一个番茄！';
    }
    if (doneTasks > 0) {
      return '进展不错（完成 $pct%），趁状态好把剩下的收个尾。';
    }
    return '还没开始执行哦，选一项任务按下 ▶，先跑一个 25 分钟番茄。';
  }

  static DayStats of(List<PlannerTask> dayTasks, DateTime now) {
    return DayStats(
      totalTasks: dayTasks.length,
      doneTasks: dayTasks.where((t) => t.done).length,
      overdueTasks: dayTasks
          .where((t) => t.statusAt(now) == TaskExecStatus.overdue)
          .length,
      inProgressTasks: dayTasks
          .where((t) => t.statusAt(now) == TaskExecStatus.inProgress)
          .length,
      pomodoros:
          dayTasks.fold<int>(0, (s, t) => s + t.donePomodoros),
      plannedMinutes:
          dayTasks.fold<int>(0, (s, t) => s + t.estimateMinutes),
      focusMinutes: dayTasks.fold<int>(0, (s, t) => s + t.focusMinutes),
    );
  }
}

/// 近 7 天趋势点（用于柱状图）
class WeekPoint {
  final DateTime day;
  final int totalTasks;
  final int doneTasks;
  final int focusMinutes;

  const WeekPoint(this.day, this.totalTasks, this.doneTasks, this.focusMinutes);

  double get rate => totalTasks == 0 ? 0 : doneTasks / totalTasks;
  bool get hasData => totalTasks > 0;
}

/// 统计服务：从全部任务汇总单日与近 7 天数据
class PlannerStats {
  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static List<PlannerTask> tasksOf(List<PlannerTask> all, DateTime day) =>
      all.where((t) => _sameDay(t.start, day)).toList();

  static DayStats dayStats(List<PlannerTask> all, DateTime day) =>
      DayStats.of(tasksOf(all, day), DateTime.now());

  /// 今天往前 7 天（含今天），按日期升序
  static List<WeekPoint> last7Days(List<PlannerTask> all) {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day - 6);
    return [
      for (int i = 0; i < 7; i++)
        () {
          final d = DateTime(start.year, start.month, start.day + i);
          final ts = tasksOf(all, d);
          return WeekPoint(
            d,
            ts.length,
            ts.where((t) => t.done).length,
            ts.fold<int>(0, (s, t) => s + t.focusMinutes),
          );
        }(),
    ];
  }
}
