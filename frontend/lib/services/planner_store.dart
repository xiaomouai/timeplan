import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/planner_models.dart';

/// timePlan 本地持久化：全部任务存 SharedPreferences 的 JSON 数组。
class PlannerStore {
  static const String _key = 'timeplan.tasks';

  static Future<List<PlannerTask>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .whereType<Map<String, dynamic>>()
          .map(PlannerTask.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveAll(List<PlannerTask> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(tasks.map((t) => t.toJson()).toList()),
    );
  }

  /// 追加一批任务（保留已有任务）
  static Future<List<PlannerTask>> appendAll(List<PlannerTask> tasks) async {
    final all = await loadAll();
    all.addAll(tasks);
    await saveAll(all);
    return all;
  }

  static Future<void> toggleDone(String id) async {
    final all = await loadAll();
    for (final t in all) {
      if (t.id == id) {
        t.done = !t.done;
        t.completedAt = t.done ? DateTime.now() : null;
      }
    }
    await saveAll(all);
  }

  /// 记一个专注番茄：进度 +1，达到预计时长自动标记完成。
  /// 返回 (任务, 是否刚刚自动完成)；任务不存在返回 null。
  static Future<(PlannerTask, bool)?> completePomodoro(String id) async {
    final all = await loadAll();
    (PlannerTask, bool)? result;
    for (final t in all) {
      if (t.id == id) {
        t.donePomodoros += 1;
        final justCompleted = !t.done && t.progress >= 1.0;
        if (justCompleted) {
          t.done = true;
          t.completedAt = DateTime.now();
        }
        result = (t, justCompleted);
      }
    }
    await saveAll(all);
    return result;
  }

  static Future<void> remove(String id) async {
    final all = await loadAll();
    all.removeWhere((t) => t.id == id);
    await saveAll(all);
  }

  static Future<void> clearDay(DateTime day) async {
    final all = await loadAll();
    all.removeWhere((t) => _sameDay(t.start, day));
    await saveAll(all);
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
