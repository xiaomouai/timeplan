import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

/// 单词拼读模式
enum SpellingMode {
  letter,   // 字母拼读
  syllable, // 音节拼读
  phoneme,  // 音素拼读
  phonics,  // 自然拼读
}

/// 拼读结果
class SpellingResult {
  final String word;
  final String mode;
  final List<String> parts;
  final String display;
  final String speakText;
  final String? ipa;

  SpellingResult({
    required this.word,
    required this.mode,
    required this.parts,
    required this.display,
    required this.speakText,
    this.ipa,
  });

  factory SpellingResult.fromJson(Map<String, dynamic> json) {
    return SpellingResult(
      word: json['word'] ?? '',
      mode: json['mode'] ?? '',
      parts: List<String>.from(json['parts'] ?? []),
      display: json['display'] ?? '',
      speakText: json['speak_text'] ?? '',
      ipa: json['ipa'],
    );
  }
}

/// 所有拼读模式结果
class AllSpellingsResult {
  final String word;
  final Map<String, SpellingModeResult> spellings;

  AllSpellingsResult({
    required this.word,
    required this.spellings,
  });

  factory AllSpellingsResult.fromJson(Map<String, dynamic> json) {
    final spellingsMap = <String, SpellingModeResult>{};
    final spellings = json['spellings'] as Map<String, dynamic>;
    
    spellings.forEach((key, value) {
      spellingsMap[key] = SpellingModeResult.fromJson(value);
    });

    return AllSpellingsResult(
      word: json['word'] ?? '',
      spellings: spellingsMap,
    );
  }
}

/// 单个拼读模式结果
class SpellingModeResult {
  final List<String> parts;
  final String display;
  final String? ipa;

  SpellingModeResult({
    required this.parts,
    required this.display,
    this.ipa,
  });

  factory SpellingModeResult.fromJson(Map<String, dynamic> json) {
    return SpellingModeResult(
      parts: List<String>.from(json['parts'] ?? []),
      display: json['display'] ?? '',
      ipa: json['ipa'],
    );
  }
}

/// 发音信息
class PronunciationInfo {
  final String word;
  final String? ipa;
  final List<String> phonemes;
  final String display;

  PronunciationInfo({
    required this.word,
    this.ipa,
    required this.phonemes,
    required this.display,
  });

  factory PronunciationInfo.fromJson(Map<String, dynamic> json) {
    return PronunciationInfo(
      word: json['word'] ?? '',
      ipa: json['ipa'],
      phonemes: List<String>.from(json['phonemes'] ?? []),
      display: json['display'] ?? '',
    );
  }
}

/// 单词拼读服务
class WordSpellingService {
  static String get _baseUrl => ApiConfig.apiPath;
  static Duration get _timeout => ApiConfig.timeout;

  static Map<String, dynamic> _data(dynamic payload) {
    if (payload is! Map || payload['success'] != true || payload['data'] is! Map) {
      throw Exception(payload is Map ? (payload['error'] ?? payload['message'] ?? '拼读服务失败') : '拼读服务失败');
    }
    return Map<String, dynamic>.from(payload['data'] as Map);
  }

  /// 拼读单词
  /// 
  /// [word] 要拼读的单词
  /// [mode] 拼读模式
  static Future<SpellingResult> spellWord(
    String word, {
    SpellingMode mode = SpellingMode.letter,
  }) async {
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/spell').replace(queryParameters: {
              'word': word,
              'mode': mode.name,
            }),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        return SpellingResult.fromJson(_data(json.decode(utf8.decode(response.bodyBytes))));
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }
    } catch (e) {
      print('拼读单词失败: $e');
      rethrow;
    }
  }

  /// 获取所有拼读模式
  /// 
  /// [word] 要拼读的单词
  static Future<AllSpellingsResult> spellAllModes(String word) async {
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/spell/all').replace(queryParameters: {
              'word': word,
            }),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        return AllSpellingsResult.fromJson(_data(json.decode(utf8.decode(response.bodyBytes))));
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }
    } catch (e) {
      print('获取所有拼读模式失败: $e');
      rethrow;
    }
  }

  /// 批量拼读
  /// 
  /// [words] 单词列表
  /// [mode] 拼读模式
  static Future<List<SpellingResult>> spellBatch(
    List<String> words, {
    SpellingMode mode = SpellingMode.letter,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/spell/batch'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'words': words,
              'mode': mode.name,
            }),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = _data(json.decode(utf8.decode(response.bodyBytes)));
        final results = data['results'] as List;
        return results.map((r) => SpellingResult.fromJson(r)).toList();
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }
    } catch (e) {
      print('批量拼读失败: $e');
      rethrow;
    }
  }

  /// 获取发音信息
  /// 
  /// [word] 要查询的单词
  static Future<PronunciationInfo> getPronunciation(String word) async {
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/pronunciation').replace(queryParameters: {
              'word': word,
            }),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        return PronunciationInfo.fromJson(_data(json.decode(utf8.decode(response.bodyBytes))));
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }
    } catch (e) {
      print('获取发音信息失败: $e');
      rethrow;
    }
  }
}
