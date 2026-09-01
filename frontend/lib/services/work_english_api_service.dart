import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import 'api_service.dart';
import 'auth_service.dart';

/// 工作英语训练记录接口。
/// AI 生成和语音识别继续复用 AIService；本服务只同步训练快照。
class WorkEnglishApiService {
  static const String _sessionsPath = '/api/v1/work-english/sessions';
  static const String _demoHistoryKey = 'work_english_demo_remote_sessions_v1';
  static String? lastErrorMessage;
  static bool lastRequiresPro = false;
  static bool lastUsedSimulation = false;

  static void _captureError(dynamic response) {
    lastErrorMessage = response is Map ? response['message']?.toString() : null;
    final data = response is Map ? response['data'] : null;
    lastRequiresPro = data is Map && data['requires_pro'] == true;
  }

  static Future<Map<String, dynamic>?> saveSession(
    Map<String, dynamic> snapshot,
  ) async {
    lastErrorMessage = null;
    lastRequiresPro = false;
    lastUsedSimulation = false;

    if (ApiConfig.useSimulatedData) {
      lastUsedSimulation = true;
      return _saveSimulatedSession(snapshot);
    }
    if (!AuthService.instance.isLoggedIn) return null;

    final response = await ApiService.instance.post(
      _sessionsPath,
      body: snapshot,
      headers: AuthService.instance.getAuthHeaders(),
    );
    if (response is! Map || response['success'] != true) {
      _captureError(response);
      return null;
    }
    final data = response['data'];
    return data is Map ? Map<String, dynamic>.from(data) : null;
  }

  static Future<List<Map<String, dynamic>>?> listSessions({
    int limit = 20,
  }) async {
    lastErrorMessage = null;
    lastRequiresPro = false;
    lastUsedSimulation = false;

    if (ApiConfig.useSimulatedData) {
      lastUsedSimulation = true;
      final items = await _readSimulatedSessions();
      return items
          .where((item) => item['completed'] == true)
          .take(limit)
          .toList(growable: false);
    }
    if (!AuthService.instance.isLoggedIn) return null;

    final response = await ApiService.instance.get(
      _sessionsPath,
      queryParameters: {'limit': limit},
      headers: AuthService.instance.getAuthHeaders(),
    );
    if (response is! Map || response['success'] != true) {
      _captureError(response);
      return null;
    }
    final data = response['data'];
    if (data is! Map || data['items'] is! List) return null;
    return (data['items'] as List)
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  static Future<bool> deleteSession(String sessionId) async {
    if (ApiConfig.useSimulatedData) {
      final items = await _readSimulatedSessions();
      final before = items.length;
      items.removeWhere((item) => item['session_id']?.toString() == sessionId);
      if (items.length == before) return false;
      await _writeSimulatedSessions(items);
      return true;
    }
    if (!AuthService.instance.isLoggedIn) return false;

    final response = await ApiService.instance.delete(
      '$_sessionsPath/$sessionId',
      headers: AuthService.instance.getAuthHeaders(),
    );
    return response is Map && response['success'] == true;
  }

  static Future<Map<String, dynamic>?> _saveSimulatedSession(
    Map<String, dynamic> snapshot,
  ) async {
    final error = _validateSimulatedState(snapshot);
    if (error != null) {
      lastErrorMessage = error;
      return null;
    }

    final completed = snapshot['completed'] == true;
    if (completed && !ApiConfig.demoProEnabled) {
      lastRequiresPro = true;
      lastErrorMessage = '工作英语完成历史和跨设备复习属于 Pro 权益，请先升级会员';
      return null;
    }

    final sessions = await _readSimulatedSessions();
    final sessionId = _validSessionId(snapshot['session_id'])
        ? snapshot['session_id'].toString()
        : _newSessionId();
    final stored = <String, dynamic>{
      ...snapshot,
      'session_id': sessionId,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'server_mode': 'simulation',
      'membership_type': ApiConfig.demoProEnabled ? 'pro' : 'free',
    };
    sessions.removeWhere((item) => item['session_id']?.toString() == sessionId);
    sessions.insert(0, stored);
    if (sessions.length > 50) sessions.removeRange(50, sessions.length);
    await _writeSimulatedSessions(sessions);
    return stored;
  }

  static String? _validateSimulatedState(Map<String, dynamic> snapshot) {
    final sceneIndex = snapshot['scene_index'];
    final completed = snapshot['completed'];
    final turns = snapshot['turns'];
    if (sceneIndex is! int || sceneIndex < 0 || sceneIndex > 2) {
      return '训练状态不能跳过场景或回退';
    }
    if (completed is! bool || turns is! List || turns.length > 12) {
      return '训练快照格式不正确';
    }

    final expectedScene = (turns.length ~/ 2).clamp(0, 2) as int;
    if (sceneIndex != expectedScene) return '训练状态不能跳过场景或回退';
    for (var index = 0; index < turns.length; index++) {
      final turn = turns[index];
      if (turn is! Map ||
          turn['scene_index'] != index ~/ 2 + 1 ||
          turn['phase'] != (index.isEven ? 'first_attempt' : 'retry')) {
        return '训练回答顺序不正确';
      }
    }
    if (completed && turns.length != 6) {
      return '完成训练前必须完成三个场景的首次表达和重说';
    }
    if (!completed && turns.length == 6) {
      return '三个场景已完成，completed 必须为 true';
    }
    return null;
  }

  static bool _validSessionId(dynamic value) {
    if (value is! String || value.length != 32) return false;
    return RegExp(r'^[0-9a-fA-F]{32}$').hasMatch(value);
  }

  static String _newSessionId() {
    return DateTime.now().microsecondsSinceEpoch.toRadixString(16).padLeft(32, '0');
  }

  static Future<List<Map<String, dynamic>>> _readSimulatedSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_demoHistoryKey) ?? const <String>[];
    final result = <Map<String, dynamic>>[];
    for (final item in raw) {
      try {
        final decoded = jsonDecode(item);
        if (decoded is Map) result.add(Map<String, dynamic>.from(decoded));
      } catch (_) {
        // 忽略损坏的 Demo 记录，不影响新训练。
      }
    }
    return result;
  }

  static Future<void> _writeSimulatedSessions(
    List<Map<String, dynamic>> sessions,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _demoHistoryKey,
      sessions.map((item) => jsonEncode(item)).toList(growable: false),
    );
  }
}
