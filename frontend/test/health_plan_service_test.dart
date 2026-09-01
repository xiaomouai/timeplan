import 'package:flutter_test/flutter_test.dart';

import 'package:timeplan/models/health_models.dart';
import 'package:timeplan/services/health_plan_service.dart';

void main() {
  final d = DateTime(2026, 8, 31); // 周一

  Map<String, Map<String, double>> logsWith(Map<String, double> day1) =>
      {'2026-08-31': day1};

  test('A 级阈值判定', () {
    expect(HealthItems.sleep.isMet(7.5), isTrue);
    expect(HealthItems.sleep.isMet(6.5), isFalse);
    expect(HealthItems.sleep.isMet(9.0), isFalse); // U 型，睡太多也不达标
    expect(HealthItems.exercise.isMet(42), isTrue);
    expect(HealthItems.exercise.isMet(20), isFalse);
    expect(HealthItems.diet.isMet(60), isTrue);
    expect(HealthItems.diet.isMet(40), isFalse);
    expect(HealthItems.alcohol.isMet(20), isTrue);
    expect(HealthItems.alcohol.isMet(21), isFalse); // 严格小于 21
  });

  test('一键达标值落在区间内', () {
    for (final h in HealthItems.all) {
      if (h.kind == HabitValueKind.boolean) continue;
      expect(h.isMet(h.passValue), isTrue, reason: h.id);
    }
  });

  test('周累计聚合', () {
    final logs = <String, Map<String, double>>{
      '2026-08-31': {'alcohol': 3},
      '2026-09-02': {'alcohol': 4},
      '2026-09-07': {'alcohol': 100}, // 下一周，不计入
    };
    expect(
      HealthPlanService.aggregate(logs, d, HealthItems.alcohol),
      closeTo(7, 0.001),
    );
  });

  test('季度聚合取最后一次记录', () {
    final logs = <String, Map<String, double>>{
      '2026-07-02': {'bp': 138},
      '2026-08-10': {'bp': 124},
    };
    expect(HealthPlanService.aggregate(logs, d, HealthItems.bp), 124);
  });

  test('阶段一：三项全达标才算一天', () {
    final logs = logsWith({'sleep': 7.5, 'break': 6});
    final st = HealthPlanService.dayStatus(
        day: d, logs: logs, phase: HealthPhases.base);
    expect(st.total, 3);
    expect(st.met, 2);
    expect(st.dailyAllMet, isFalse);

    final full = logsWith({'sleep': 7.5, 'break': 6, 'diet': 60});
    final st2 = HealthPlanService.dayStatus(
        day: d, logs: full, phase: HealthPhases.base);
    expect(st2.dailyAllMet, isTrue);
  });

  test('连续达标与阶段解锁', () {
    final logs = <String, Map<String, double>>{};
    for (var i = 0; i < 10; i++) {
      final day = DateTime(2026, 8, 31).subtract(Duration(days: i));
      final key =
          '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      logs[key] = {'sleep': 7.5, 'break': 6, 'diet': 60};
    }
    final ev = HealthPlanService.evaluate(
      today: d,
      logs: logs,
      unlockedPhase: 0,
    );
    expect(ev.streak, 10);
    expect(ev.canAdvance, isTrue);
    expect(ev.progress, 1.0);
  });

  test('作息模板随阶段增减任务', () {
    final base = HealthPlanService.buildDayTemplate(d, phase: HealthPhases.base);
    final full = HealthPlanService.buildDayTemplate(d, phase: HealthPhases.full);
    expect(base.any((t) => t.title.contains('运动')), isFalse);
    expect(base.any((t) => t.title.contains('学习')), isFalse);
    expect(full.any((t) => t.title.contains('运动')), isTrue);
    expect(full.any((t) => t.title.contains('纸质书')), isTrue);
    expect(full.length, greaterThan(base.length));
    // 任务按时间升序，且都在同一天
    for (var i = 1; i < full.length; i++) {
      expect(full[i].start.isAfter(full[i - 1].start), isTrue);
    }
    expect(full.first.start.hour, 8);
    expect(full.last.title.contains('断屏'), isTrue);
  });

  test('周节奏覆盖周一到周日', () {
    for (var w = 1; w <= 7; w++) {
      expect(HealthPlanService.weekdayAgenda(w), isNotNull);
    }
  });
}
