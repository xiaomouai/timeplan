import 'package:uuid/uuid.dart';

import '../models/health_models.dart';
import '../models/planner_models.dart';
import 'health_store.dart';

/// 单日健康达标情况
class HealthDayStatus {
  /// habitId → 聚合后的数值
  final Map<String, double> values;
  final int total;
  final int met;
  final List<String> missingIds;
  /// 只统计"每天"频率的条目（用于连续达标与阶段解锁）
  final int dailyTotal;
  final int dailyMet;

  const HealthDayStatus({
    required this.values,
    required this.total,
    required this.met,
    required this.missingIds,
    required this.dailyTotal,
    required this.dailyMet,
  });

  double get rate => total == 0 ? 0 : met / total;
  double get dailyRate => dailyTotal == 0 ? 0 : dailyMet / dailyTotal;
  bool get dailyAllMet => dailyTotal > 0 && dailyMet == dailyTotal;
  bool get allMet => total > 0 && met == total;
}

/// 阶段评估结果
class HealthPhaseEvaluation {
  final HealthPhase phase;
  /// 连续达标天数
  final int streak;
  /// 是否满足解锁下一阶段的条件
  final bool canAdvance;
  /// 解锁进度 0~1
  final double progress;

  const HealthPhaseEvaluation({
    required this.phase,
    required this.streak,
    required this.canAdvance,
    required this.progress,
  });
}

/// 节奏动作（周 / 月 / 季）
class AgendaItem {
  final String title;
  final String detail;
  final int minutes;

  const AgendaItem({
    required this.title,
    required this.detail,
    required this.minutes,
  });
}

/// 健康计划服务：达标判定、阶段推进、作息模板生成。
///
/// 数据全部来自 [HealthStore]，本类只做计算与排程，不持有状态。
class HealthPlanService {
  static const Uuid _uuid = Uuid();

  static String _newId() => _uuid.v4();

  static DateTime _midnight(DateTime d) => DateTime(d.year, d.month, d.day);

  // ---------------- 聚合 ----------------

  /// 按条目频率聚合数值：
  /// 每天取当天；每周取周一至周日累加；每月/每季取区间内最后一次记录。
  static double aggregate(
    Map<String, Map<String, double>> logs,
    DateTime day,
    HealthHabit habit,
  ) {
    final d = _midnight(day);
    switch (habit.cadence) {
      case HabitCadence.daily:
        return logs[HealthStore.dayKey(d)]?[habit.id] ?? 0;
      case HabitCadence.weekly:
        final monday = _midnight(d.subtract(Duration(days: d.weekday - 1)));
        var sum = 0.0;
        for (var i = 0; i < 7; i++) {
          final key = HealthStore.dayKey(
              DateTime(monday.year, monday.month, monday.day + i));
          sum += logs[key]?[habit.id] ?? 0;
        }
        return sum;
      case HabitCadence.monthly:
        final prefix =
            '${d.year}-${d.month.toString().padLeft(2, '0')}';
        return _latestIn(logs, habit.id, (k) => k.startsWith(prefix));
      case HabitCadence.quarterly:
        final q = (d.month - 1) ~/ 3;
        return _latestIn(logs, habit.id, (k) {
          final parts = k.split('-');
          if (parts.length != 3) return false;
          final y = int.tryParse(parts[0]);
          final m = int.tryParse(parts[1]);
          if (y == null || m == null) return false;
          return y == d.year && (m - 1) ~/ 3 == q;
        });
    }
  }

  static double _latestIn(
    Map<String, Map<String, double>> logs,
    String habitId,
    bool Function(String key) match,
  ) {
    final keys = logs.keys.where(match).toList()..sort();
    for (final k in keys.reversed) {
      final v = logs[k]?[habitId];
      if (v != null) return v;
    }
    return 0;
  }

  // ---------------- 达标判定 ----------------

  /// 计算某天的达标情况（只统计 [phase] 激活的条目）
  static HealthDayStatus dayStatus({
    required DateTime day,
    required Map<String, Map<String, double>> logs,
    required HealthPhase phase,
  }) {
    final values = <String, double>{};
    final missing = <String>[];
    var total = 0;
    var met = 0;
    var dailyTotal = 0;
    var dailyMet = 0;

    for (final habit in phase.habits) {
      final v = aggregate(logs, day, habit);
      values[habit.id] = v;
      final ok = habit.isMet(v);
      total++;
      if (ok) {
        met++;
      } else {
        missing.add(habit.id);
      }
      if (habit.cadence == HabitCadence.daily) {
        dailyTotal++;
        if (ok) dailyMet++;
      }
    }
    return HealthDayStatus(
      values: values,
      total: total,
      met: met,
      missingIds: missing,
      dailyTotal: dailyTotal,
      dailyMet: dailyMet,
    );
  }

  /// 连续达标天数：从 [today] 往回数，"每天"条目全达标才算一天。
  /// 今天还没达标时不算断，从昨天开始数（避免白天打开就显示 0）。
  static int streak({
    required DateTime today,
    required Map<String, Map<String, double>> logs,
    required HealthPhase phase,
  }) {
    var count = 0;
    var cursor = _midnight(today);
    // 今天未达标 → 从昨天起算
    if (!dayStatus(day: cursor, logs: logs, phase: phase).dailyAllMet) {
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    }
    while (dayStatus(day: cursor, logs: logs, phase: phase).dailyAllMet) {
      count++;
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
      if (count > 400) break; // 安全阀
    }
    return count;
  }

  /// 阶段评估：当前阶段 + 连续天数 + 是否可解锁下一阶段
  static HealthPhaseEvaluation evaluate({
    required DateTime today,
    required Map<String, Map<String, double>> logs,
    required int unlockedPhase,
  }) {
    final phase = HealthPhases.at(unlockedPhase);
    final s = streak(today: today, logs: logs, phase: phase);
    final canAdvance =
        phase.unlockDays > 0 && s >= phase.unlockDays && unlockedPhase < 3;
    return HealthPhaseEvaluation(
      phase: phase,
      streak: s,
      canAdvance: canAdvance,
      progress: phase.unlockDays == 0 ? 1.0 : (s / phase.unlockDays).clamp(0.0, 1.0),
    );
  }

  // ---------------- 每日作息模板 ----------------

  /// 生成一天的作息任务表。
  ///
  /// 上午认知峰值锁死 2×90 分钟深度工作；下午放协作、会议、交付；
  /// 傍晚运动；晚上学习与纸质书（替代刷手机，同时护眼助眠）；22:30 断屏。
  /// 运动与学习块按当前阶段自动出现或隐藏。
  static List<PlannerTask> buildDayTemplate(
    DateTime day, {
    required HealthPhase phase,
    TaskPriority focusPriority = TaskPriority.high,
  }) {
    final d = DateTime(day.year, day.month, day.day);
    final has = phase.habitIds.contains;
    final rows = <(int, int, String, int, TaskPriority)>[
      (8, 0, '深度工作Ⅰ · 架构/核心编码/关键决策', 90, focusPriority),
      (9, 35, '起身活动 3 分钟', 3, TaskPriority.low),
      (9, 40, '深度工作Ⅱ · 继续最难的活', 90, focusPriority),
      (12, 0, '午餐 + 午休（断屏）', 50, TaskPriority.low),
      (14, 0, '协作 · 会议 · 交付', 90, TaskPriority.medium),
      (15, 35, '起身活动 3 分钟', 3, TaskPriority.low),
      (15, 40, '协作 · 会议 · 交付', 90, TaskPriority.medium),
      if (has('exercise')) (18, 0, '中高强度运动 42 分钟（微喘）', 42, TaskPriority.medium),
      if (has('cognition')) (19, 30, '学习 · 新技能/课程 45 分钟', 45, TaskPriority.medium),
      if (has('cognition')) (20, 20, '起身活动 3 分钟', 3, TaskPriority.low),
      if (has('cognition')) (20, 30, '纸质书阅读 30 分钟（替代刷手机）', 30, TaskPriority.low),
      (21, 30, '收尾 · 明日三件事', 15, TaskPriority.medium),
      (22, 30, '断屏 · 准备入睡（23:00 熄灯）', 15, TaskPriority.low),
    ];

    return [
      for (final r in rows)
        PlannerTask(
          id: _newId(),
          title: r.$3,
          estimateMinutes: r.$4,
          priority: r.$5,
          start: DateTime(d.year, d.month, d.day, r.$1, r.$2),
        ),
    ];
  }

  // ---------------- 周 / 月 / 季节奏 ----------------

  /// 星期几对应的周节奏动作（DateTime.weekday：周一=1 … 周日=7）
  static AgendaItem? weekdayAgenda(int weekday) {
    return switch (weekday) {
      1 => const AgendaItem(
          title: '周一 · 锁定本周 3 个可交付成果',
          detail: '要的是"可交付成果"，不是任务清单。三个必须是这周能交出去的东西。',
          minutes: 30,
        ),
      2 => const AgendaItem(
          title: '周二 · 力量训练',
          detail: '三大项或自重循环，45 分钟。力量是老年期独立生活的保险。',
          minutes: 45,
        ),
      3 => const AgendaItem(
          title: '周三 · 线下社交 ≥1 小时',
          detail: '线上不算。面对面，最好带点身体活动（走路、吃饭、打球）。',
          minutes: 60,
        ),
      4 => const AgendaItem(
          title: '周四 · 力量训练',
          detail: '与周二不同部位，留出恢复时间。',
          minutes: 45,
        ),
      5 => const AgendaItem(
          title: '周五 · 三栏复盘',
          detail: '第一栏：这周交付了什么；第二栏：钱进来了吗；'
              '第三栏：健康达标率。三栏都要写，缺一栏就是在自欺。',
          minutes: 30,
        ),
      6 => const AgendaItem(
          title: '周六 · 力量训练',
          detail: '一周三次力量，是 12 条里时间成本最低的一条。',
          minutes: 45,
        ),
      7 => const AgendaItem(
          title: '周日 · 备餐 90 分钟',
          detail: '一次性备好一周的蛋白、主食和切好的蔬菜，换整周膳食达标。',
          minutes: 90,
        ),
      _ => null,
    };
  }

  static const List<AgendaItem> monthlyAgenda = [
    AgendaItem(
      title: '财务结算 + 产能审计',
      detail: '产能审计看的是深度工作小时数，不是坐了几小时。'
          '这两条放一起，是因为它们决定同一件事：你卖的时间值不值。',
      minutes: 60,
    ),
    AgendaItem(
      title: '至少一件有复利的增长动作',
      detail: '能沉淀、能复用、下次不用从头做的东西。'
          '一件都没有，这个月就是纯重复。',
      minutes: 120,
    ),
    AgendaItem(
      title: '身体数据采集',
      detail: '体重、腰围、静息心率。静息心率是恢复能力最便宜的指标。',
      minutes: 15,
    ),
    AgendaItem(
      title: '读完 1–2 本书并输出笔记',
      detail: '不输出等于没读。笔记可以是一页，但要有你自己的判断。',
      minutes: 0,
    ),
  ];

  static const List<AgendaItem> quarterlyAgenda = [
    AgendaItem(
      title: '体检兜底',
      detail: '血压、血脂四项（重点看 LDL）、HbA1c、视力、听力。'
          '感觉良好不能替代数值——这是唯一不能糊弄的一条。',
      minutes: 120,
    ),
    AgendaItem(
      title: '收入结构审计',
      detail: '本月收入里，多少是"卖时间"，多少是"可复用资产"。'
          '可复用那一栏一件都没有，就是纯打工，哪怕是高薪打工。',
      minutes: 90,
    ),
    AgendaItem(
      title: '完成 1 个能放进作品集的东西',
      detail: '能被别人看到的、完整的、说清楚你解决了什么问题的东西。',
      minutes: 0,
    ),
  ];

  /// 当前所处的季度标签，如 2026-Q3
  static String quarterLabel(DateTime d) => '${d.year}-Q${(d.month - 1) ~/ 3 + 1}';
}
