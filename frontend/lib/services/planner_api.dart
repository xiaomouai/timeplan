import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../config/api_config.dart';
import '../models/planner_models.dart';

/// 计划分解后端 API：调用真实 LLM 把自然语言待办拆为结构化任务。
///
/// 对应后端 `/planner/decompose`（ProviderManager 真实 LLM，qwen/deepseek 自动降级）。
/// 失败抛异常，由 [PlannerAgentService] 降级本地规则引擎（仅后端不可用时）。
class PlannerApi {
  static const Uuid _uuid = Uuid();

  static String get _base => ApiConfig.apiPath;

  /// 调用后端分解接口，返回结构化任务列表（真实 LLM 生成）。
  /// 抛出异常表示后端不可用或返回错误，调用方应捕获并降级。
  static Future<List<PlannerTask>> decompose(String input) async {
    final resp = await http
        .post(
          Uri.parse('$_base/planner/decompose'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'text': input}),
        )
        .timeout(const Duration(seconds: 30));
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    if (body['success'] != true) {
      throw Exception(body['message'] ?? '计划分解失败(${resp.statusCode})');
    }
    final data = body['data'] as Map<String, dynamic>? ?? {};
    final list = data['tasks'] as List? ?? [];
    final tasks = <PlannerTask>[];
    for (final item in list) {
      final m = item as Map<String, dynamic>;
      final title = (m['title'] as String? ?? '').trim();
      if (title.isEmpty) continue;
      var minutes = (m['minutes'] as num? ?? 30).toInt();
      if (minutes < 10) minutes = 10;
      if (minutes > 120) minutes = 120;
      tasks.add(PlannerTask(
        id: _uuid.v4(),
        title: title,
        estimateMinutes: minutes,
        priority: TaskPriorityX.fromName(m['priority'] as String?),
        start: DateTime.now(),
      ));
    }
    return tasks;
  }
}
