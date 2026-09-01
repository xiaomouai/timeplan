import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

/// 通用 API 服务
/// 处理 HTTP 请求的基础封装
class ApiService {
  // 单例模式
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  static ApiService get instance => _instance;

  // 获取基础 URL
  String get _baseUrl => ApiConfig.baseUrl;

  // 获取默认 headers
  Map<String, String> _getHeaders({Map<String, String>? extraHeaders}) {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    
    if (extraHeaders != null) {
      headers.addAll(extraHeaders);
    }
    
    return headers;
  }

  /// GET 请求
  Future<dynamic> get(String path, {Map<String, dynamic>? queryParameters, Map<String, String>? headers}) async {
    try {
      final uri = _buildUri(path, queryParameters);
      final response = await http.get(
        uri, 
        headers: _getHeaders(extraHeaders: headers),
      ).timeout(ApiConfig.timeout);
      
      return _processResponse(response);
    } catch (e) {
      print('GET request failed: $e');
      // 返回一个表示错误的 Map，避免调用端崩溃
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// POST 请求
  Future<dynamic> post(String path, {Map<String, dynamic>? body, Map<String, String>? headers}) async {
    try {
      final uri = _buildUri(path);
      final response = await http.post(
        uri,
        headers: _getHeaders(extraHeaders: headers),
        body: body != null ? json.encode(body) : null,
      ).timeout(ApiConfig.timeout);

      return _processResponse(response);
    } catch (e) {
      print('POST request failed: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// PUT 请求
  Future<dynamic> put(String path, {Map<String, dynamic>? body, Map<String, String>? headers}) async {
    try {
      final uri = _buildUri(path);
      final response = await http.put(
        uri,
        headers: _getHeaders(extraHeaders: headers),
        body: body != null ? json.encode(body) : null,
      ).timeout(ApiConfig.timeout);

      return _processResponse(response);
    } catch (e) {
      print('PUT request failed: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// DELETE 请求
  Future<dynamic> delete(String path, {Map<String, String>? headers}) async {
    try {
      final uri = _buildUri(path);
      final response = await http.delete(
        uri,
        headers: _getHeaders(extraHeaders: headers),
      ).timeout(ApiConfig.timeout);

      return _processResponse(response);
    } catch (e) {
      print('DELETE request failed: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // 构建 URI
  Uri _buildUri(String path, [Map<String, dynamic>? queryParameters]) {
    // 如果 path 包含完整 URL，直接解析
    if (path.startsWith('http')) {
      return Uri.parse(path).replace(queryParameters: queryParameters?.map((k, v) => MapEntry(k, v.toString())));
    }
    
    // 否则拼接 baseUrl
    String url = _baseUrl;
    
    // 确保 url 不以 / 结尾，path 以 / 开头
    if (url.endsWith('/')) url = url.substring(0, url.length - 1);
    if (!path.startsWith('/')) path = '/$path';
    
    url += path;
    
    return Uri.parse(url).replace(queryParameters: queryParameters?.map((k, v) => MapEntry(k, v.toString())));
  }

  // 处理响应
  dynamic _processResponse(http.Response response) {
    try {
      // 尝试解析 JSON
      final body = json.decode(response.body);
      
      // 如果后端返回的是标准的 success_response 格式
      // {code: 200, msg: 'success', data: ...}
      // AuthService 期望 {success: true, ...}
      // 这里做一个转换适配
      if (body is Map<String, dynamic>) {
        if (!body.containsKey('success')) {
          body['success'] = body['code'] == 200;
        }
        // 确保 message 字段存在
        if (!body.containsKey('message') && body.containsKey('msg')) {
          body['message'] = body['msg'];
        }
      }
      
      return body;
    } catch (e) {
      print('Response parse failed: $e');
      return {'success': false, 'message': 'Invalid response format'};
    }
  }
}
