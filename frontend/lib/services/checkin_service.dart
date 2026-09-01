import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'auth_service.dart';

/// 签到服务
class CheckinService {
  static final CheckinService _instance = CheckinService._internal();
  factory CheckinService() => _instance;
  CheckinService._internal();

  static CheckinService get instance => _instance;

  // API 基础 URL
  String get _baseUrl => ApiConfig.apiPath;
  
  // 超时时间
  Duration get _timeout => ApiConfig.timeout;

  /// 获取请求头（包含认证信息）
  Map<String, String> _getHeaders([Map<String, String>? extra]) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    
    // 从 AuthService 获取 token
    final token = AuthService.instance.token;
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    
    if (extra != null) {
      headers.addAll(extra);
    }
    return headers;
  }

  /// 执行签到
  Future<Map<String, dynamic>> doCheckin() async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/checkin'),
        headers: _getHeaders(),
      ).timeout(_timeout);

      final data = json.decode(response.body);
      
      // 适配后端返回格式 {code: 200, msg: "...", data: {...}}
      if (response.statusCode == 200) {
        return {
          'success': data['code'] == 200,
          'message': data['msg'],
          'data': data['data'],
        };
      } else {
        return {
          'success': false,
          'message': data['msg'] ?? '签到失败',
          'code': response.statusCode,
        };
      }
    } catch (e) {
      print('签到请求失败: $e');
      return {
        'success': false,
        'message': '网络连接失败: $e',
      };
    }
  }

  /// 获取签到页面数据
  Future<Map<String, dynamic>> getCheckinPageData({int? year, int? month}) async {
    try {
      String url = '$_baseUrl/checkin/page';
      if (year != null && month != null) {
        url += '?year=$year&month=$month';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: _getHeaders(),
      ).timeout(_timeout);

      final data = json.decode(response.body);
      
      if (response.statusCode == 200) {
        return {
          'success': data['code'] == 200,
          'message': data['msg'],
          'data': data['data'],
        };
      } else {
        return {
          'success': false,
          'message': data['msg'] ?? '获取数据失败',
        };
      }
    } catch (e) {
      print('获取签到数据失败: $e');
      return {
        'success': false,
        'message': '网络连接失败: $e',
      };
    }
  }
}
