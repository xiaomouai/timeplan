import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'auth_service.dart';
import 'simulated_work_english_service.dart';

/// 统一的AI服务 - 调用后端API
/// 支持千问和DeepSeek，后端自动降级
class AIService {
  static String get _baseUrl => ApiConfig.apiPath;
  static const Duration _timeout = Duration(seconds: 30);

  /// 获取请求头
  static Map<String, String> _getHeaders() {
    final headers = {
      'Content-Type': 'application/json',
    };
    headers.addAll(AuthService.instance.getAuthHeaders());
    return headers;
  }

  /// AI聊天接口
  /// 
  /// [message] 用户消息
  /// [chatType] 聊天场景（可选：grammar/speaking等），后端自动注入提示词
  /// [provider] AI提供商（可选：qwen/deepseek），不指定则自动选择
  /// [systemPrompt] 系统提示词（可选）
  /// [conversationHistory] 对话历史（可选）
  /// [temperature] 温度参数（0-1），默认0.7
  /// [maxTokens] 最大token数，默认2000
  /// 
  /// 返回AI的回复内容
  static Future<AIChatResponse> chat({
    required String message,
    String? chatType,
    String? provider,
    String? systemPrompt,
    List<Map<String, String>>? conversationHistory,
    double? temperature,
    int? maxTokens,
  }) async {
    if (ApiConfig.useSimulatedData &&
        SimulatedWorkEnglishService.isKnowledgeRequest(chatType, systemPrompt)) {
      return AIChatResponse(
        success: true,
        content: SimulatedWorkEnglishService.knowledgeResponse(message),
        provider: 'demo-qwen',
        model: 'work-english-demo-v1',
      );
    }
    if (ApiConfig.useSimulatedData &&
        SimulatedWorkEnglishService.isSpeakingRequest(chatType, systemPrompt)) {
      return AIChatResponse(
        success: true,
        content: SimulatedWorkEnglishService.feedback(
          retry: systemPrompt?.contains('retry after feedback') == true,
        ),
        provider: 'demo-deepseek',
        model: 'work-english-demo-v1',
      );
    }

    try {
      final url = Uri.parse('$_baseUrl/ai/chat');
      
      final Map<String, dynamic> body = {
        'message': message,
      };

      // 添加可选参数
      if (chatType != null && chatType.isNotEmpty) {
        body['chat_type'] = chatType;
      }
      if (provider != null && provider.isNotEmpty) {
        body['provider'] = provider;
      }
      if (systemPrompt != null && systemPrompt.isNotEmpty) {
        body['system_prompt'] = systemPrompt;
      }
      if (conversationHistory != null && conversationHistory.isNotEmpty) {
        body['conversation_history'] = conversationHistory;
      }
      if (temperature != null) {
        body['temperature'] = temperature;
      }
      if (maxTokens != null) {
        body['max_tokens'] = maxTokens;
      }

      final response = await http.post(
        url,
        headers: _getHeaders(),
        body: jsonEncode(body),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(utf8.decode(response.bodyBytes));
        if (jsonData['code'] == 200 && jsonData['data'] != null) {
          final data = jsonData['data'];
          return AIChatResponse(
            success: true,
            content: data['content'] ?? '',
            provider: data['provider'] ?? 'unknown',
            model: data['model'] ?? 'unknown',
          );
        } else {
          return AIChatResponse(
            success: false,
            error: jsonData['message'] ?? '未知错误',
          );
        }
      } else {
        final errorData = jsonDecode(utf8.decode(response.bodyBytes));
        return AIChatResponse(
          success: false,
          error: errorData['message'] ?? '请求失败',
        );
      }
    } catch (e) {
      return AIChatResponse(
        success: false,
        error: '网络请求失败: $e',
      );
    }
  }

  /// 获取可用的AI提供商列表
  static Future<List<AIProvider>> getProviders() async {
    try {
      final url = Uri.parse('$_baseUrl/ai/providers');
      final response = await http.get(url, headers: _getHeaders()).timeout(_timeout);
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(utf8.decode(response.bodyBytes));
        if (jsonData['data'] != null && jsonData['data']['providers'] != null) {
          final List list = jsonData['data']['providers'];
          return list.map((item) => AIProvider.fromJson(item)).toList();
        }
      }
    } catch (e) {
      print('获取提供商失败: $e');
    }
    return [];
  }

  /// 获取所有可用的聊天场景
  static Future<Map<String, dynamic>> getScenes() async {
    try {
      final url = Uri.parse('$_baseUrl/ai/scenes');
      final response = await http.get(url, headers: _getHeaders()).timeout(_timeout);
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(utf8.decode(response.bodyBytes));
        return jsonData['data'] ?? {};
      }
    } catch (e) {
      print('获取场景失败: $e');
    }
    return {};
  }

  /// 获取指定场景配置
  static Future<Map<String, dynamic>?> getSceneConfig(String sceneId) async {
    try {
      final url = Uri.parse('$_baseUrl/ai/scenes/$sceneId');
      final response = await http.get(url, headers: _getHeaders()).timeout(_timeout);
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(utf8.decode(response.bodyBytes));
        return jsonData['data'];
      }
    } catch (e) {
      print('获取场景配置失败: $e');
    }
    return null;
  }

  /// 测试AI提供商连接
  static Future<AITestResult> testProvider(String provider) async {
    try {
      final url = Uri.parse('$_baseUrl/ai/test/$provider');
      
      final response = await http.get(
        url,
        headers: _getHeaders(),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(utf8.decode(response.bodyBytes));
        if (jsonData['code'] == 200 && jsonData['data'] != null) {
          final data = jsonData['data'];
          return AITestResult(
            success: true,
            provider: data['provider'],
            status: data['status'],
            responseTime: (data['response_time'] as num?)?.toDouble(),
            testResponse: data['test_response'],
          );
        } else {
          return AITestResult(
            success: false,
            error: jsonData['message'] ?? '测试失败',
          );
        }
      } else {
        return AITestResult(
          success: false,
          error: '测试失败',
        );
      }
    } catch (e) {
      return AITestResult(
        success: false,
        error: '网络请求失败: $e',
      );
    }
  }

  /// 获取预设的AI提示词
  static Future<Map<String, String>> getPrompts() async {
    try {
      final url = Uri.parse('$_baseUrl/ai/prompts');
      
      final response = await http.get(url).timeout(_timeout);

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(utf8.decode(response.bodyBytes));
        if (jsonData['code'] == 200 && jsonData['data'] != null) {
          final prompts = jsonData['data']['prompts'] as Map<String, dynamic>;
          return prompts.map((key, value) => MapEntry(key, value.toString()));
        }
      }
      return _getDefaultPrompts();
    } catch (e) {
      return _getDefaultPrompts();
    }
  }

  /// 获取默认提示词（作为后备）
  static Map<String, String> _getDefaultPrompts() {
    return {
      'general': '你是一位友好的英语老师Luna，擅长中英双语交流。你会用简单易懂的方式解答学生的问题，既可以用中文也可以用英文交流。你的回答要有耐心、鼓励性，适合各个年龄段的学习者。',
      'speaking': 'You are an English speaking tutor. Your goal is to help students practice English conversation. Speak naturally and encourage them to express themselves in English. Correct their mistakes gently and provide better alternatives.',
      'grammar': '你是一位英语语法专家。你的任务是用简单易懂的方式解释英语语法规则，帮助学生理解和掌握语法知识。对于学生的语法问题，要给出清晰的解释和实用的例子。',
      'writing': '你是一位英语写作指导老师。你可以帮助学生写作文，提供写作思路，或者修改学生的作文。要注重写作结构、用词准确性和表达流畅性。',
      'translate': '你是一位专业的中英翻译。你的任务是准确翻译中英文内容，并在必要时提供更地道的表达方式。翻译要准确、自然、符合语境。',
      'qa': '你是一位博学的百科助手。你可以回答各种问题，帮助学生探索和学习新知识。回答要准确、全面、易于理解。',
      'planning': '你是一位学习规划顾问。你可以帮助学生制定合理的学习计划，提供学习方法建议，帮助他们更高效地学习英语。',
      'vocabulary': '你是一位词汇拓展专家。你可以帮助学生扩展词汇量，讲解同义词、反义词、词组搭配等。要提供丰富的例句和用法说明。',
    };
  }

  /// 语音转文字接口
  /// 
  /// [audioPath] 录音文件路径
  /// 
  /// 返回识别后的文字内容
  static Future<String?> speechToText(String audioPath) async {
    if (ApiConfig.useSimulatedData) {
      return SimulatedWorkEnglishService.transcription;
    }
    try {
      final url = Uri.parse('$_baseUrl/ai/speech');
      
      var request = http.MultipartRequest('POST', url);
      request.headers.addAll(AuthService.instance.getAuthHeaders());
      
      request.files.add(await http.MultipartFile.fromPath(
        'file',
        audioPath,
      ));

      final streamedResponse = await request.send().timeout(_timeout);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(utf8.decode(response.bodyBytes));
        if (jsonData['code'] == 200 && jsonData['data'] != null) {
          return jsonData['data']['text']?.toString();
        }
      }
      return null;
    } catch (e) {
      print('语音识别失败: $e');
      return null;
    }
  }
}

/// AI聊天响应
class AIChatResponse {
  final bool success;
  final String? content;
  final String? provider;
  final String? model;
  final String? error;

  AIChatResponse({
    required this.success,
    this.content,
    this.provider,
    this.model,
    this.error,
  });
}

/// AI提供商信息
class AIProvider {
  final String id;
  final String name;
  final String model;
  final bool enabled;
  final int priority;

  AIProvider({
    required this.id,
    required this.name,
    required this.model,
    required this.enabled,
    required this.priority,
  });

  factory AIProvider.fromJson(Map<String, dynamic> json) {
    return AIProvider(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      model: json['model'] ?? '',
      enabled: json['enabled'] ?? false,
      priority: json['priority'] ?? 999,
    );
  }
}

/// AI测试结果
class AITestResult {
  final bool success;
  final String? provider;
  final String? status;
  final double? responseTime;
  final String? testResponse;
  final String? error;

  AITestResult({
    required this.success,
    this.provider,
    this.status,
    this.responseTime,
    this.testResponse,
    this.error,
  });
}
