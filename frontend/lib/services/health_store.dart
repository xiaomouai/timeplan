import 'package:flutter/foundation.dart';

import 'health_api.dart';

/// 健康打卡持久化（后端驱动版）。
///
/// 用户数据真实落库于 xuebaApi 后端；本地只保留稳定 client_id / JWT。
/// 对外仍暴露页面所需的 `Map<日期, Map<习惯 id, 数值>>` 形态，便于 HealthPlanService 复用。
class HealthStore {
  static String dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// 拉取今日打卡，转换为页面所需的 logs 形态（仅含今天）。
  /// 后端不可达 / 鉴权失败 / 数据异常时降级为当天空记录，绝不向上抛错。
  static Future<Map<String, Map<String, double>>> loadLogs() async {
    try {
      final d = await HealthApi.dashboard();
      final todayKey = d['date'] as String? ?? dayKey(DateTime.now());
      final items = (d['items'] as List?) ?? [];
      final Map<String, double> day = {};
      for (final it in items) {
        final m = it as Map<String, dynamic>;
        final key = m['key'] as String?;
        if (key == null) continue;
        final logged = m['logged'];
        double v = 0;
        if (logged != null && logged['value'] != null) {
          v = (logged['value'] as num).toDouble();
        } else if (logged != null && logged['done'] == true) {
          v = 1;
        }
        day[key] = v;
      }
      return {todayKey: day};
    } catch (e) {
      debugPrint('[health] loadLogs 失败，降级为空：$e');
      return {dayKey(DateTime.now()): {}};
    }
  }

  static Future<int> loadPhase() async {
    try {
      final d = await HealthApi.dashboard();
      return (d['phase'] as int?) ?? 0;
    } catch (e) {
      debugPrint('[health] loadPhase 失败，降级为 0：$e');
      return 0;
    }
  }

  static Future<DateTime> loadStartDate() async {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static Future<Map<String, Map<String, double>>> setValue(
    DateTime day,
    String habitId,
    double value,
  ) async {
    final key = dayKey(day);
    final done = value >= 1;
    await HealthApi.checkin(key, [
      {'habit_key': habitId, 'value': value, 'done': done}
    ]);
    return loadLogs();
  }

  static Future<void> savePhase(int phase) async {
    try {
      await HealthApi.setPhase(phase);
    } catch (_) {
      // 后端阶段为权威；本地写失败不影响 UI
    }
  }

  static Future<Map<String, Map<String, double>>> toggle(
    DateTime day,
    String habitId,
  ) async {
    final logs = await loadLogs();
    final key = dayKey(day);
    final cur = logs[key]?[habitId] ?? 0;
    return setValue(day, habitId, cur >= 1 ? 0 : 1);
  }

  static Future<Map<String, Map<String, double>>> clearValue(
    DateTime day,
    String habitId,
  ) async {
    return setValue(day, habitId, 0);
  }
}
