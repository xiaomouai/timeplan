import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

/// 英语单词API服务
/// 用于获取单词的详细信息：音标、释义、例句、发音等
class EnglishWordApiService {
  /// 通过单词名称搜索获取单词详细信息
  /// 
  /// [word] 要查询的英语单词
  /// 返回 [WordDetailResponse] 包含单词的详细信息
  static Future<WordDetailResponse?> getWordDetails(String word) async {
    try {
      // 使用本地API搜索接口
      final Uri uri = Uri.parse('${ApiConfig.wordSearchUrl}?keyword=${Uri.encodeComponent(word)}&limit=1');
      
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(ApiConfig.timeout);
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        
        // 本地API返回格式: {code: 200, msg: "success", data: {results: [...]}}
        if (jsonData['code'] == 200 && jsonData['data'] != null) {
          final results = jsonData['data']['results'] as List?;
          if (results != null && results.isNotEmpty) {
            final firstResult = results[0];
            final bookId = firstResult['bookId'] ?? '';
            final wordRank = firstResult['wordRank'] ?? 0;
            
            // 获取完整的单词详情
            if (bookId.isNotEmpty && wordRank > 0) {
              return getWordDetailByRank(bookId, wordRank);
            }
          }
        }
        return null;
      } else {
        return null;
      }
    } catch (e) {
      print('获取单词详情失败: $e');
      return null;
    }
  }
  
  /// 通过词书ID和单词序号获取单词详细信息
  /// 
  /// [bookId] 词书ID
  /// [wordRank] 单词序号
  /// 返回 [WordDetailResponse] 包含单词的详细信息
  static Future<WordDetailResponse?> getWordDetailByRank(String bookId, int wordRank) async {
    try {
      final Uri uri = Uri.parse(ApiConfig.wordDetailUrl(bookId, wordRank));
      
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(ApiConfig.timeout);
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        
        if (jsonData['code'] == 200 && jsonData['data'] != null) {
          return WordDetailResponse.fromJson(jsonData['data']);
        } else {
          return null;
        }
      } else {
        return null;
      }
    } catch (e) {
      print('获取单词详情失败: $e');
      return null;
    }
  }
}

/// 单词详情响应模型
class WordDetailResponse {
  final String word;
  final String ukPhone;      // 英音音标
  final String usPhone;      // 美音音标
  final String ukSpeech;     // 英音音频URL
  final String usSpeech;     // 美音音频URL
  final List<WordTranslation> translations;
  final List<WordSentence> sentences;
  final List<WordPhrase> phrases;
  final String bookId;
  final int wordRank;
  
  WordDetailResponse({
    required this.word,
    required this.ukPhone,
    required this.usPhone,
    required this.ukSpeech,
    required this.usSpeech,
    required this.translations,
    required this.sentences,
    required this.phrases,
    required this.bookId,
    required this.wordRank,
  });
  
  factory WordDetailResponse.fromJson(Map<String, dynamic> json) {
    // 处理 translations
    List<WordTranslation> translationsList = [];
    final transData = json['translations'];
    if (transData != null) {
      if (transData is List) {
        translationsList = transData
            .map((e) => WordTranslation.fromJson(e as Map<String, dynamic>))
            .toList();
      } else if (transData is Map) {
        // 如果是对象格式，转换为列表
        translationsList = [WordTranslation.fromJson(Map<String, dynamic>.from(transData))];
      }
    }
    
    // 处理 sentences
    List<WordSentence> sentencesList = [];
    final sentData = json['sentences'];
    if (sentData != null) {
      if (sentData is List) {
        sentencesList = sentData
            .map((e) => WordSentence.fromJson(e as Map<String, dynamic>))
            .toList();
      } else if (sentData is Map && sentData['sentences'] != null) {
        // 如果是嵌套格式 {sentences: [...]}
        final innerList = sentData['sentences'] as List?;
        if (innerList != null) {
          sentencesList = innerList
              .map((e) => WordSentence.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
    }
    
    // 处理 phrases
    List<WordPhrase> phrasesList = [];
    final phrasesData = json['phrases'];
    if (phrasesData != null) {
      if (phrasesData is List) {
        phrasesList = phrasesData
            .map((e) => WordPhrase.fromJson(e as Map<String, dynamic>))
            .toList();
      } else if (phrasesData is Map && phrasesData['phrases'] != null) {
        // 如果是嵌套格式 {phrases: [...]}
        final innerList = phrasesData['phrases'] as List?;
        if (innerList != null) {
          phrasesList = innerList
              .map((e) => WordPhrase.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
    }
    
    return WordDetailResponse(
      word: json['word'] ?? '',
      ukPhone: json['ukphone'] ?? '',
      usPhone: json['usphone'] ?? '',
      ukSpeech: json['ukspeech'] ?? '',
      usSpeech: json['usspeech'] ?? '',
      translations: translationsList,
      sentences: sentencesList,
      phrases: phrasesList,
      bookId: json['bookId'] ?? '',
      wordRank: json['wordRank'] ?? 0,
    );
  }
}

/// 单词翻译模型
class WordTranslation {
  final String pos;      // 词性
  final String tranCn;   // 中文翻译
  final String tranOther; // 英文释义
  
  WordTranslation({
    required this.pos,
    required this.tranCn,
    this.tranOther = '',
  });
  
  factory WordTranslation.fromJson(Map<String, dynamic> json) {
    return WordTranslation(
      pos: json['pos'] ?? '',
      tranCn: json['tranCn'] ?? json['tran_cn'] ?? '',
      tranOther: json['tranOther'] ?? json['tran_other'] ?? '',
    );
  }
}

/// 单词例句模型
class WordSentence {
  final String sContent;   // 英文例句
  final String sCn;        // 中文翻译
  
  WordSentence({
    required this.sContent,
    required this.sCn,
  });
  
  factory WordSentence.fromJson(Map<String, dynamic> json) {
    return WordSentence(
      sContent: json['sContent'] ?? json['s_content'] ?? '',
      sCn: json['sCn'] ?? json['s_cn'] ?? '',
    );
  }
}

/// 单词短语模型
class WordPhrase {
  final String pContent;   // 英文短语
  final String pCn;        // 中文翻译
  
  WordPhrase({
    required this.pContent,
    required this.pCn,
  });
  
  factory WordPhrase.fromJson(Map<String, dynamic> json) {
    return WordPhrase(
      pContent: json['pContent'] ?? json['p_content'] ?? '',
      pCn: json['pCn'] ?? json['p_cn'] ?? '',
    );
  }
}

/// 发音类型枚举
enum PronunciationType {
  uk,    // 英音
  us,    // 美音
}

/// 获取发音类型的显示名称
extension PronunciationTypeExtension on PronunciationType {
  String get displayName {
    switch (this) {
      case PronunciationType.uk:
        return '英音';
      case PronunciationType.us:
        return '美音';
    }
  }
  
  String get code {
    switch (this) {
      case PronunciationType.uk:
        return 'uk';
      case PronunciationType.us:
        return 'us';
    }
  }
} 