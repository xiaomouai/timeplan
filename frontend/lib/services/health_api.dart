import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/api_config.dart';

/// 健康后端 API 客户端。
///
/// 所有用户数据（打卡/阶段/体检/计划）与 AI 生成均走真实后端（xuebaApi /health），
/// 不再使用本地 SharedPreferences 模拟。本地仅缓存一个稳定的 client_id 与 JWT。
class HealthApi {
  static const String _kClientId = 'timeplan.health.client_id';
  static const String _kJwt = 'timeplan.health.jwt';

  static String get _base => ApiConfig.apiPath;

  static Future<String> _clientId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_kClientId);
    if (id == null || id.isEmpty) {
      id = 'tp-${DateTime.now().microsecondsSinceEpoch}-'
          '${DateTime.now().millisecondsSinceEpoch % 100000}';
      await prefs.setString(_kClientId, id);
    }
    return id;
  }

  static Future<String?> _token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kJwt);
  }

  static Future<void> _setToken(String t) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kJwt, t);
  }

  /// 确保已引导：用稳定 client_id 换取真实 JWT。
  static Future<void> ensureBootstrap() async {
    final t = await _token();
    if (t != null && t.isNotEmpty) return;
    final clientId = await _clientId();
    final resp = await http.post(
      Uri.parse('$_base/health/bootstrap'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'client_id': clientId, 'nickname': 'timePlan 用户'}),
    );
    _assertOk(resp);
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final tk = data['data']?['token'] as String?;
    if (tk != null) await _setToken(tk);
  }

  static Map<String, dynamic> _assertOk(http.Response resp) {
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode >= 200 &&
        resp.statusCode < 300 &&
        body['success'] == true) {
      return body['data'] as Map<String, dynamic>;
    }
    throw Exception(body['message'] ?? '健康后端请求失败(${resp.statusCode})');
  }

  static Future<Map<String, dynamic>> _get(String path) async {
    await ensureBootstrap();
    final tk = await _token();
    final resp = await http.get(
      Uri.parse('$_base$path'),
      headers: {
        'Authorization': 'Bearer $tk',
        'Content-Type': 'application/json',
      },
    );
    return _assertOk(resp);
  }

  static Future<Map<String, dynamic>> _post(
      String path, Map<String, dynamic> body) async {
    await ensureBootstrap();
    final tk = await _token();
    final resp = await http.post(
      Uri.parse('$_base$path'),
      headers: {
        'Authorization': 'Bearer $tk',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );
    return _assertOk(resp);
  }

  static Future<Map<String, dynamic>> dashboard() => _get('/health/dashboard');
  static Future<Map<String, dynamic>> habits() => _get('/health/habits');
  static Future<Map<String, dynamic>> checkin(
          String date, List<Map<String, dynamic>> entries) =>
      _post('/health/checkin', {'log_date': date, 'entries': entries});
  static Future<Map<String, dynamic>> setPhase(int phase) =>
      _post('/health/phase', {'phase': phase});
  static Future<Map<String, dynamic>> generatePlan(String period) =>
      _post('/health/plan/generate', {'period': period});
  static Future<Map<String, dynamic>> coach(String message,
          [List<Map<String, String>>? history]) =>
      _post('/health/coach', {'message': message, 'history': history ?? []});
  static Future<Map<String, dynamic>> plans([String? period]) =>
      _get(period != null ? '/health/plan?period=$period' : '/health/plan');
}
