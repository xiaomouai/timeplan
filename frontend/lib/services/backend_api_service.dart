import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'package:http_parser/http_parser.dart';
import '../models/word_book.dart';
import '../models/word_learning_record.dart';
import '../models/syllable_info.dart';
import '../models/pronunciation_result.dart';
import 'auth_service.dart';

import '../utils/cache_service.dart';

/// 后端 API 服务
class BackendApiService {
  // API 基础 URL - 从配置读取
  static String get _baseUrl => ApiConfig.apiPath;
  
  // 超时时间
  static Duration get _timeout => ApiConfig.timeout;

  /// 获取当前选中的词书信息
  static Future<Map<String, dynamic>?> getCurrentWordBook() async {
    final id = await CacheService.getSelectedWordBookId();
    final name = await CacheService.getSelectedWordBook();
    if (id != null && name != null) {
      return {'id': id, 'name': name};
    }
    return null;
  }

  /// 获取请求头（包含认证信息）
  static Map<String, String> _getHeaders([Map<String, String>? extra]) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    headers.addAll(AuthService.instance.getAuthHeaders());
    if (extra != null) {
      headers.addAll(extra);
    }
    return headers;
  }

  /// 通用 GET 请求
  static Future<Map<String, dynamic>> get(
    String endpoint, {
    Map<String, String>? queryParams,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl$endpoint').replace(
        queryParameters: queryParams,
      );
      
      final response = await http.get(
        uri,
        headers: _getHeaders(),
      ).timeout(_timeout);
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }
    } catch (e) {
      print('GET请求失败: $e');
      rethrow;
    }
  }

  /// 获取指定词书的单词列表
  static Future<List<WordData>> getBookWords(String bookId, {int page = 1, int pageSize = 100}) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/books/$bookId/words?page=$page&page_size=$pageSize'),
        headers: _getHeaders(),
      ).timeout(_timeout);

      if (response.statusCode != 200) {
        throw Exception('Failed to load words: ${response.statusCode}');
      }

      final data = json.decode(response.body);
      if (data['code'] != 200) {
        throw Exception(data['msg']);
      }

      List<dynamic> wordsJson = data['data']['words'];
      return wordsJson.map((json) {
        Map<String, dynamic> wordMap = Map.from(json);
        wordMap['bookId'] = bookId;
        return WordData.fromJson(wordMap);
      }).toList();
    } catch (e) {
      print('Error fetching words: $e');
      return [];
    }
  }

  /// 获取单词详细信息
  static Future<Map<String, dynamic>?> getWordDetail(String bookId, int wordRank) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/words/$bookId/$wordRank'),
        headers: _getHeaders(),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 200) {
          return data['data'];
        }
      }
      return null;
    } catch (e) {
      print('Error fetching word detail: $e');
      return null;
    }
  }

  /// 获取推荐单词列表
  static Future<List<WordData>> getRecommendedWords(String bookId, {int maxCount = 5}) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/words/daily-recommend').replace(
          queryParameters: {
            'book_id': bookId,
            'count': maxCount.toString(),
          },
        ),
        headers: _getHeaders(),
      ).timeout(_timeout);

      if (response.statusCode != 200) {
        throw Exception('Failed to load recommended words: ${response.statusCode}');
      }

      final data = json.decode(response.body);
      if (data['code'] != 200) {
        throw Exception(data['msg']);
      }

      List<dynamic> wordsJson = data['data']['words'];
      return wordsJson.map((json) {
        Map<String, dynamic> wordMap = Map.from(json);
        wordMap['bookId'] = bookId; // Ensure bookId is passed to WordData
        return WordData.fromJson(wordMap);
      }).toList();
    } catch (e) {
      print('Error fetching recommended words: $e');
      return [];
    }
  }
  
  /// 获取分类列表
  static Future<List<String>> getCategories() async {
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/categories'),
            headers: _getHeaders(),
          )
          .timeout(_timeout);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // 检查响应格式
        if (data['code'] == 200 && data['data'] != null) {
          final categories = List<String>.from(data['data']);
          
          // 确保"全部"在第一位
          if (!categories.contains('全部')) {
            categories.insert(0, '全部');
          } else {
            categories.remove('全部');
            categories.insert(0, '全部');
          }
          
          return categories;
        } else {
          throw Exception('API 返回格式错误: ${data['msg']}');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }
    } catch (e) {
      print('获取分类失败: $e');
      // 返回默认分类列表作为降级方案
      return _getDefaultCategories();
    }
  }
  
  /// 获取词书列表
  static Future<List<Map<String, dynamic>>> getBooks({
    String? category,
    String? tag,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (category != null && category != '全部') {
        queryParams['category'] = category;
      }
      if (tag != null) {
        queryParams['tag'] = tag;
      }
      
      final uri = Uri.parse('$_baseUrl/books').replace(
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );
      
      final response = await http.get(
        uri,
        headers: _getHeaders(),
      ).timeout(_timeout);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['code'] == 200 && data['data'] != null) {
          return List<Map<String, dynamic>>.from(data['data']);
        } else {
          throw Exception('API 返回格式错误: ${data['msg']}');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }
    } catch (e) {
      print('获取词书列表失败: $e');
      rethrow;
    }
  }
  
  /// 获取词书详情
  static Future<Map<String, dynamic>> getBookDetail(String bookId) async {
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/books/$bookId'),
            headers: _getHeaders(),
          )
          .timeout(_timeout);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['code'] == 200 && data['data'] != null) {
          return data['data'];
        } else {
          throw Exception('API 返回格式错误: ${data['msg']}');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }
    } catch (e) {
      print('获取词书详情失败: $e');
      rethrow;
    }
  }
  
  /// 获取单词列表（分页）
  static Future<Map<String, dynamic>> getWords(
    String bookId, {
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/books/$bookId/words').replace(
        queryParameters: {
          'page': page.toString(),
          'page_size': pageSize.toString(),
        },
      );
      
      final response = await http.get(
        uri,
        headers: _getHeaders(),
      ).timeout(_timeout);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['code'] == 200 && data['data'] != null) {
          return data['data'];
        } else {
          throw Exception('API 返回格式错误: ${data['msg']}');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }
    } catch (e) {
      print('获取单词列表失败: $e');
      rethrow;
    }
  }
  
  /// 搜索单词
  static Future<Map<String, dynamic>> searchWords(
    String keyword, {
    String? bookId,
  }) async {
    try {
      final queryParams = <String, String>{
        'keyword': keyword,
      };
      if (bookId != null) {
        queryParams['book_id'] = bookId;
      }
      
      final uri = Uri.parse('$_baseUrl/words/search').replace(
        queryParameters: queryParams,
      );
      
      final response = await http.get(
        uri,
        headers: _getHeaders(),
      ).timeout(_timeout);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['code'] == 200 && data['data'] != null) {
          return data['data'];
        } else {
          throw Exception('API 返回格式错误: ${data['msg']}');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }
    } catch (e) {
      print('搜索单词失败: $e');
      rethrow;
    }
  }
  
  /// 获取发音 URL
  static Future<String> getPronunciationUrl(
    String word, {
    String type = '1', // 1=英音, 2=美音
  }) async {
    return Uri.parse('$_baseUrl/audio/proxy').replace(
      queryParameters: {'word': word, 'type': type},
    ).toString();
  }

  /// 发音评分（上传录音文件）
  static Future<PronunciationResult?> evaluatePronunciation({
    required String word,
    required String filePath,
    String? bookId,
    int? wordRank,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/audio/evaluate');
      final request = http.MultipartRequest('POST', uri)
        ..fields['word'] = word;
      
      // 添加认证头
      request.headers.addAll(_getHeaders());
      
      if (bookId != null) request.fields['bookId'] = bookId;
      if (wordRank != null) request.fields['wordRank'] = wordRank.toString();
      request.files.add(await http.MultipartFile.fromPath(
        'audio',
        filePath,
        contentType: MediaType('audio', 'm4a'),
      ));
      final streamed = await request.send().timeout(_timeout);
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 200 && data['data'] != null) {
          return PronunciationResult.fromJson(data['data']);
        }
      }
      return null;
    } catch (e) {
      print('发音评分失败: $e');
      return null;
    }
  }

  /// 获取音节拆解信息
  static Future<SyllableInfo?> getSyllables(String word) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/audio/syllables/$word'),
        headers: _getHeaders(),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 200 && data['data'] != null) {
          return SyllableInfo.fromJson(data['data']);
        }
      }
      return null;
    } catch (e) {
      print('获取音节失败: $e');
      return null;
    }
  }
  
  /// 健康检查
  static Future<bool> healthCheck() async {
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/health'),
            headers: _getHeaders(),
          )
          .timeout(_timeout);
      
      return response.statusCode == 200;
    } catch (e) {
      print('健康检查失败: $e');
      return false;
    }
  }
  
  /// 更新单词学习状态
  static Future<Map<String, dynamic>?> updateWordLearning({
    required String bookId,
    required int wordRank,
    required String action, // view/listen/read/practice
    int duration = 0,
    bool? isCorrect,
    int? score,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/words/$bookId/$wordRank/learn'),
        headers: _getHeaders(),
        body: json.encode({
          'action': action,
          'duration': duration,
          if (isCorrect != null) 'is_correct': isCorrect,
          if (score != null) 'score': score,
        }),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 200) {
          return data['data'];
        }
      }
      return null;
    } catch (e) {
      print('更新学习状态失败: $e');
      return null;
    }
  }

  /// 获取闯关题目
  static Future<Map<String, dynamic>?> getUnitChallenges({
    required String unitId,
    String mode = 'normal',
    String difficulty = 'medium',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/challenge/create'),
        headers: _getHeaders(),
        body: json.encode({
          'word_book_id': int.tryParse(unitId) ?? unitId,
          'difficulty': difficulty,
          'question_type': mode == 'normal' ? 'choose_meaning' : mode,
        }),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 200) {
          return data['data'];
        }
      }
      return null;
    } catch (e) {
      print('获取闯关题目失败: $e');
      return null;
    }
  }

  /// 提交闯关结果
  static Future<Map<String, dynamic>?> submitChallenge({
    required String challengeId,
    required List<Map<String, dynamic>> answers,
    required int totalTime,
  }) async {
    try {
      Map<String, dynamic>? lastAnswer;
      for (final answer in answers) {
        final response = await http.post(
          Uri.parse('$_baseUrl/challenge/$challengeId/submit'),
          headers: _getHeaders(),
          body: json.encode({
            'word_id': answer['word_id'] ?? answer['wordId'],
            'user_answer': answer['user_answer'] ?? answer['userAnswer'] ?? '',
            'is_correct': answer['is_correct'] ?? answer['isCorrect'] ?? false,
            'time_spent': answer['time_spent'] ?? answer['timeSpent'] ?? 0,
          }),
        ).timeout(_timeout);
        if (response.statusCode != 200) return null;
        final data = json.decode(response.body);
        if (data['code'] != 200) return null;
        if (data['data'] is Map) lastAnswer = Map<String, dynamic>.from(data['data']);
      }

      final finishResponse = await http.post(
        Uri.parse('$_baseUrl/challenge/$challengeId/finish'),
        headers: _getHeaders(),
      ).timeout(_timeout);
      if (finishResponse.statusCode == 200) {
        final data = json.decode(finishResponse.body);
        if (data['code'] == 200 && data['data'] is Map) {
          return Map<String, dynamic>.from(data['data']);
        }
      }
      return lastAnswer ?? {'total_time': totalTime};
    } catch (e) {
      print('提交闯关结果失败: $e');
      return null;
    }
  }

  /// 开始听写练习
  static Future<Map<String, dynamic>?> startDictation({
    required String unitId,
    int wordCount = 10,
    String mode = 'random',
    bool includePhrases = false,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/dictation/create'),
        headers: _getHeaders(),
        body: json.encode({
          'word_count': wordCount,
          'mode': mode,
          'word_book_id': int.tryParse(unitId) ?? unitId,
          'include_phrases': includePhrases,
        }),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 200) {
          return data['data'];
        }
      }
      return null;
    } catch (e) {
      print('开始听写失败: $e');
      return null;
    }
  }

  /// 提交听写结果
  static Future<Map<String, dynamic>?> submitDictation({
    required String dictationId,
    required List<Map<String, dynamic>> answers,
    required int totalTime,
  }) async {
    try {
      Map<String, dynamic>? lastAnswer;
      for (final answer in answers) {
        final response = await http.post(
          Uri.parse('$_baseUrl/dictation/$dictationId/submit'),
          headers: _getHeaders(),
          body: json.encode({
            'word_id': answer['word_id'] ?? answer['wordId'],
            'user_answer': answer['user_answer'] ?? answer['userAnswer'] ?? '',
          }),
        ).timeout(_timeout);
        if (response.statusCode != 200) return null;
        final data = json.decode(response.body);
        if (data['code'] != 200) return null;
        if (data['data'] is Map) lastAnswer = Map<String, dynamic>.from(data['data']);
      }

      final finishResponse = await http.post(
        Uri.parse('$_baseUrl/dictation/$dictationId/finish'),
        headers: _getHeaders(),
      ).timeout(_timeout);
      if (finishResponse.statusCode == 200) {
        final data = json.decode(finishResponse.body);
        if (data['code'] == 200 && data['data'] is Map) {
          return Map<String, dynamic>.from(data['data']);
        }
      }
      return lastAnswer ?? {'total_time': totalTime};
    } catch (e) {
      print('提交听写结果失败: $e');
      return null;
    }
  }

  /// 获取单元列表
  static Future<List<Map<String, dynamic>>> getBookUnits(String bookId) async {
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/books/$bookId/units'),
            headers: _getHeaders(),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 200 && data['data'] != null) {
          final units = data['data']['units'] as List;
          return units.cast<Map<String, dynamic>>();
        }
      }
      return [];
    } catch (e) {
      print('获取单元列表失败: $e');
      return [];
    }
  }

  /// 获取单元单词
  static Future<List<Map<String, dynamic>>> getUnitWords(String unitId) async {
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/units/$unitId/words'),
            headers: _getHeaders(),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 200 && data['data'] != null) {
          final words = data['data']['words'] as List;
          return words.cast<Map<String, dynamic>>();
        }
      }
      return [];
    } catch (e) {
      print('获取单元单词失败: $e');
      return [];
    }
  }
  
  /// 获取默认分类列表（降级方案）
  static List<String> _getDefaultCategories() {
    return [
      '全部',
      '四级',
      '六级',
      '考研',
      '专四',
      '专八',
      'IELTS',
      'TOEFL',
      'GRE',
      'GMAT',
      'SAT',
      'BEC',
      '小学',
      '初中',
      '高中',
    ];
  }

  /// 获取单词状态（是否收藏、是否掌握）
  static Future<Map<String, bool>> getWordStatus({
    required String bookId,
    required int wordRank,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/user/word_status/$bookId/$wordRank'),
        headers: _getHeaders(),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 200 && data['data'] != null) {
          return {
            'is_favorited': data['data']['is_favorited'] ?? false,
            'is_mastered': data['data']['is_mastered'] ?? false,
          };
        }
      }
      return {'is_favorited': false, 'is_mastered': false};
    } catch (e) {
      print('获取单词状态失败: $e');
      return {'is_favorited': false, 'is_mastered': false};
    }
  }

  /// 收藏单词
  static Future<bool> addToFavorites({
    required String bookId,
    required int wordRank,
    required String word,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/user/favorites'),
        headers: _getHeaders(),
        body: json.encode({
          'book_id': bookId,
          'word_rank': wordRank,
          'word': word,
        }),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['code'] == 200;
      }
      return false;
    } catch (e) {
      print('收藏单词失败: $e');
      return false;
    }
  }

  /// 取消收藏
  static Future<bool> removeFromFavorites({
    required String bookId,
    required int wordRank,
  }) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/user/favorites/$bookId/$wordRank'),
        headers: _getHeaders(),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['code'] == 200;
      }
      return false;
    } catch (e) {
      print('取消收藏失败: $e');
      return false;
    }
  }

  /// 标记为已掌握
  static Future<bool> markAsMastered({
    required String bookId,
    required int wordRank,
    required String word,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/user/mastered'),
        headers: _getHeaders(),
        body: json.encode({
          'book_id': bookId,
          'word_rank': wordRank,
          'word': word,
        }),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['code'] == 200;
      }
      return false;
    } catch (e) {
      print('标记掌握失败: $e');
      return false;
    }
  }

  /// 取消已掌握标记
  static Future<bool> unmarkMastered({
    required String bookId,
    required int wordRank,
  }) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/user/mastered/$bookId/$wordRank'),
        headers: _getHeaders(),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['code'] == 200;
      }
      return false;
    } catch (e) {
      print('取消掌握标记失败: $e');
      return false;
    }
  }

  /// 撤销学习记录
  static Future<bool> undoLearningRecord({
    required String bookId,
    required int wordRank,
  }) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/user/learning_records/$bookId/$wordRank/undo'),
        headers: _getHeaders(),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['code'] == 200;
      }
      return false;
    } catch (e) {
      print('撤销学习记录失败: $e');
      return false;
    }
  }

  /// 同步学习记录到后端
  static Future<bool> syncLearningRecords(List<WordLearningRecord> records) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/user/learning_records/sync'),
        headers: _getHeaders(),
        body: json.encode(records.map((r) => r.toJson()).toList()),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['code'] == 200;
      }
      return false;
    } catch (e) {
      print('同步学习记录失败: $e');
      return false;
    }
  }
  
  /// 从后端获取学习记录
  static Future<List<WordLearningRecord>> fetchLearningRecords() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/user/learning_records'),
        headers: _getHeaders(),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 200 && data['data'] != null) {
          return (data['data'] as List)
              .map((json) => WordLearningRecord.fromJson(json))
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('获取学习记录失败: $e');
      return [];
    }
  }

  /// 获取会员状态
  static Future<Map<String, dynamic>> getMembershipStatus() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/membership/status'),
        headers: _getHeaders(),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      throw Exception('获取会员状态失败');
    } catch (e) {
      print('获取会员状态失败: $e');
      rethrow;
    }
  }

  /// 获取会员套餐列表
  static Future<Map<String, dynamic>> getMembershipPlans() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/membership/plans'),
        headers: _getHeaders(),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      throw Exception('获取会员套餐失败');
    } catch (e) {
      print('获取会员套餐失败: $e');
      rethrow;
    }
  }

  /// 激活会员
  static Future<Map<String, dynamic>> activateMembership(
    String activationCode, 
    String userId
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/activation/activate'),
        headers: _getHeaders(),
        body: json.encode({
          'activation_code': activationCode, // 修正为后端期望的 activation_code
          'user_id': userId,
          'device_id': 'mobile_app',
        }),
      ).timeout(_timeout);

      if (response.statusCode == 200 || response.statusCode == 400) {
        return json.decode(response.body);
      }
      throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
    } catch (e) {
      print('激活会员失败: $e');
      rethrow;
    }
  }

  /// 检查功能访问权限
  static Future<Map<String, dynamic>> checkFeatureAccess(
    String userId, 
    String feature
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/membership/check-feature'),
        headers: _getHeaders(),
        body: json.encode({
          'user_id': userId,
          'feature': feature,
        }),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      throw Exception('检查功能权限失败');
    } catch (e) {
      print('检查功能权限失败: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> createMembershipOrder(
    String planId,
    String userId, {
    String provider = 'wechat',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/membership/order/create'),
        headers: _getHeaders(),
        body: json.encode({
          'plan_id': planId,
          'user_id': userId,
          'provider': provider,
        }),
      ).timeout(_timeout);
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      throw Exception('创建订单失败');
    } catch (e) {
      print('创建订单失败: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getOrderStatus(String orderId) async {
    try {
      final uri = Uri.parse('$_baseUrl/membership/order/status')
          .replace(queryParameters: {'order_id': orderId});
      final response = await http.get(
        uri,
        headers: _getHeaders(),
      ).timeout(_timeout);
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      throw Exception('查询订单状态失败');
    } catch (e) {
      print('查询订单状态失败: $e');
      rethrow;
    }
  }

  // --- 闯关模块相关接口 ---

  /// 获取闯关题型列表
  static Future<List<Map<String, dynamic>>> getChallengeTypes() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/challenge/types'),
        headers: _getHeaders(),
      ).timeout(_timeout);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 200 && data['data'] != null) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
      }
      return [];
    } catch (e) {
      print('获取闯关题型失败: $e');
      return [];
    }
  }

  /// 获取闯关难度列表
  static Future<List<Map<String, dynamic>>> getChallengeDifficulties() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/challenge/difficulties'),
        headers: _getHeaders(),
      ).timeout(_timeout);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 200 && data['data'] != null) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
      }
      return [];
    } catch (e) {
      print('获取闯关难度失败: $e');
      return [];
    }
  }

  /// 创建闯关任务
  static Future<Map<String, dynamic>?> createChallenge({
    required String wordBookId,
    String difficulty = 'easy',
    String questionType = 'choose_meaning',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/challenge/create'),
        headers: _getHeaders(),
        body: json.encode({
          'word_book_id': int.tryParse(wordBookId) ?? wordBookId,
          'difficulty': difficulty,
          'question_type': questionType,
        }),
      ).timeout(_timeout);
      if (response.statusCode == 200 || response.statusCode == 403) {
        final data = json.decode(response.body);
        return data;
      }
      return null;
    } catch (e) {
      print('创建闯关失败: $e');
      return null;
    }
  }

  /// 提交答题记录
  static Future<bool> submitChallengeAnswer({
    required int challengeId,
    required int wordId,
    required String userAnswer,
    required bool isCorrect,
    int timeSpent = 0,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/challenge/$challengeId/submit'),
        headers: _getHeaders(),
        body: json.encode({
          'word_id': wordId,
          'user_answer': userAnswer,
          'is_correct': isCorrect,
          'time_spent': timeSpent,
        }),
      ).timeout(_timeout);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['code'] == 200;
      }
      return false;
    } catch (e) {
      print('提交闯关答案失败: $e');
      return false;
    }
  }

  /// 完成闯关
  static Future<Map<String, dynamic>?> finishChallenge(int challengeId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/challenge/$challengeId/finish'),
        headers: _getHeaders(),
      ).timeout(_timeout);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 200) {
          return data['data'];
        }
      }
      return null;
    } catch (e) {
      print('完成闯关失败: $e');
      return null;
    }
  }

  /// 获取闯关统计
  static Future<Map<String, dynamic>?> getChallengeStats() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/challenge/stats'),
        headers: _getHeaders(),
      ).timeout(_timeout);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 200) {
          return data['data'];
        }
      }
      return null;
    } catch (e) {
      print('获取闯关统计失败: $e');
      return null;
    }
  }

  /// 获取闯关历史
  static Future<Map<String, dynamic>?> getChallengeHistory({int page = 1, int perPage = 20}) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/challenge/history?page=$page&per_page=$perPage'),
        headers: _getHeaders(),
      ).timeout(_timeout);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 200) {
          return data['data'];
        }
      }
      return null;
    } catch (e) {
      print('获取闯关历史失败: $e');
      return null;
    }
  }

  /// 获取用户信息
  static Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/user/profile'),
        headers: _getHeaders(),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 200) {
          return data['data'];
        }
      }
      return null;
    } catch (e) {
      print('获取用户信息失败: $e');
      return null;
    }
  }

  /// 更新用户信息
  static Future<bool> updateUserProfile({
    String? nickname,
    String? avatar,
    String? gender,
    String? birthday,
    int? grade,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/user/profile'),
        headers: _getHeaders(),
        body: json.encode({
          if (nickname != null) 'nickname': nickname,
          if (avatar != null) 'avatar': avatar,
          if (gender != null) 'gender': gender,
          if (birthday != null) 'birthday': birthday,
          if (grade != null) 'grade': grade,
        }),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['code'] == 200;
      }
      return false;
    } catch (e) {
      print('更新用户信息失败: $e');
      return false;
    }
  }

  /// 提交用户反馈
  static Future<Map<String, dynamic>> submitFeedback({
    required String content,
    String? contact,
    String feedbackType = 'general',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/feedback'),
        headers: _getHeaders(),
        body: json.encode({
          'content': content,
          if (contact != null) 'contact': contact,
          'feedback_type': feedbackType,
        }),
      ).timeout(_timeout);

      return json.decode(response.body);
    } catch (e) {
      print('提交反馈失败: $e');
      return {'code': 500, 'msg': '网络连接失败，请稍后重试'};
    }
  }
}
