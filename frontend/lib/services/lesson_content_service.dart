/// 课文内容服务
/// 负责从 API 获取课文、句子、单词数据
import 'package:flutter/foundation.dart';
import '../pages/lesson_study_page.dart';
import 'backend_api_service.dart';

class LessonContentService {
  static final LessonContentService _instance = LessonContentService._internal();

  factory LessonContentService() {
    return _instance;
  }

  LessonContentService._internal();

  final _apiService = BackendApiService();

  /// 获取单元内容
  /// course_id: 课程ID（如人教版PEP）
  /// unit_number: 单元号（如1表示Unit 1）
  Future<LessonUnit?> getLessonUnit({
    required String courseId,
    required int unitNumber,
  }) async {
    try {
      final response = await _apiService.get(
        '/api/lesson/units',
        queryParameters: {
          'course_id': courseId,
          'unit_number': unitNumber,
        },
      );

      if (response != null && response['success'] == true) {
        return LessonUnit.fromJson(response['data'] as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching lesson unit: $e');
      return null;
    }
  }

  /// 获取单元中的所有句子
  /// unit_id: 单元ID
  Future<List<SentenceContent>> getLessonSentences({
    required int unitId,
  }) async {
    try {
      final response = await _apiService.get(
        '/api/lesson/sentences',
        queryParameters: {
          'unit_id': unitId,
        },
      );

      if (response != null && response['success'] == true) {
        final List<dynamic> data = response['data'] as List<dynamic>;
        return data
            .map((item) =>
                SentenceContent.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching lesson sentences: $e');
      return [];
    }
  }

  /// 获取句子的详细信息（包括音频）
  /// sentence_id: 句子ID
  Future<SentenceDetail?> getSentenceDetail({
    required int sentenceId,
  }) async {
    try {
      final response = await _apiService.get(
        '/api/lesson/sentences/$sentenceId',
      );

      if (response != null && response['success'] == true) {
        return SentenceDetail.fromJson(
            response['data'] as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching sentence detail: $e');
      return null;
    }
  }

  /// 上传学习进度
  /// unit_id: 单元ID
  /// completed_sentences: 已完成的句子ID列表
  /// pronunciation_scores: 发音评分列表
  Future<bool> uploadLearningProgress({
    required int unitId,
    required List<int> completedSentences,
    Map<int, int>? pronunciationScores,
  }) async {
    try {
      final response = await _apiService.post(
        '/api/learning/progress',
        body: {
          'unit_id': unitId,
          'completed_sentences': completedSentences,
          'pronunciation_scores': pronunciationScores ?? {},
          'completed_at': DateTime.now().toIso8601String(),
        },
      );

      return response != null && response['success'] == true;
    } catch (e) {
      debugPrint('Error uploading learning progress: $e');
      return false;
    }
  }

  /// 获取用户的学习记录
  /// unit_id: 单元ID
  Future<UserLessonProgress?> getUserProgress({
    required int unitId,
  }) async {
    try {
      final response = await _apiService.get(
        '/api/learning/progress',
        queryParameters: {
          'unit_id': unitId,
        },
      );

      if (response != null && response['success'] == true) {
        return UserLessonProgress.fromJson(
            response['data'] as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching user progress: $e');
      return null;
    }
  }
}

/// 课文单元数据模型
class LessonUnit {
  final int id;
  final String title;          // "Unit 1 Hello!"
  final String description;    // 单元描述
  final int courseId;          // 所属课程
  final int unitNumber;        // 单元号
  final int sentenceCount;     // 句子数量
  final String imageUrl;       // 单元封面

  LessonUnit({
    required this.id,
    required this.title,
    required this.description,
    required this.courseId,
    required this.unitNumber,
    required this.sentenceCount,
    required this.imageUrl,
  });

  factory LessonUnit.fromJson(Map<String, dynamic> json) {
    return LessonUnit(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      courseId: json['course_id'] as int? ?? 0,
      unitNumber: json['unit_number'] as int? ?? 0,
      sentenceCount: json['sentence_count'] as int? ?? 0,
      imageUrl: json['image_url'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'course_id': courseId,
    'unit_number': unitNumber,
    'sentence_count': sentenceCount,
    'image_url': imageUrl,
  };
}

/// 句子详细信息
class SentenceDetail {
  final int id;
  final String english;
  final String chinese;
  final String? audioUrlUs;    // 美音URL
  final String? audioUrlUk;    // 英音URL
  final String? phonetic;      // 音标
  final List<WordInfo> words;  // 单词列表

  SentenceDetail({
    required this.id,
    required this.english,
    required this.chinese,
    this.audioUrlUs,
    this.audioUrlUk,
    this.phonetic,
    required this.words,
  });

  factory SentenceDetail.fromJson(Map<String, dynamic> json) {
    final wordsData = json['words'] as List<dynamic>? ?? [];
    return SentenceDetail(
      id: json['id'] as int,
      english: json['english'] as String? ?? '',
      chinese: json['chinese'] as String? ?? '',
      audioUrlUs: json['audio_url_us'] as String?,
      audioUrlUk: json['audio_url_uk'] as String?,
      phonetic: json['phonetic'] as String?,
      words: wordsData
          .map((w) => WordInfo.fromJson(w as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'english': english,
    'chinese': chinese,
    'audio_url_us': audioUrlUs,
    'audio_url_uk': audioUrlUk,
    'phonetic': phonetic,
    'words': words.map((w) => w.toJson()).toList(),
  };
}

/// 单词信息
class WordInfo {
  final String word;
  final String? pronunciation;
  final String meaning;

  WordInfo({
    required this.word,
    this.pronunciation,
    required this.meaning,
  });

  factory WordInfo.fromJson(Map<String, dynamic> json) {
    return WordInfo(
      word: json['word'] as String? ?? '',
      pronunciation: json['pronunciation'] as String?,
      meaning: json['meaning'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'word': word,
    'pronunciation': pronunciation,
    'meaning': meaning,
  };
}

/// 用户学习进度
class UserLessonProgress {
  final int unitId;
  final List<int> completedSentences;  // 已完成的句子ID
  final Map<int, int> pronunciationScores;  // 发音评分
  final DateTime lastLearnedAt;
  final int totalLearnTime;  // 总学习时间（秒）

  UserLessonProgress({
    required this.unitId,
    required this.completedSentences,
    required this.pronunciationScores,
    required this.lastLearnedAt,
    required this.totalLearnTime,
  });

  factory UserLessonProgress.fromJson(Map<String, dynamic> json) {
    final scoresData = json['pronunciation_scores'] as Map<String, dynamic>? ?? {};
    final scores = <int, int>{};
    
    scoresData.forEach((key, value) {
      scores[int.parse(key)] = value as int;
    });

    return UserLessonProgress(
      unitId: json['unit_id'] as int,
      completedSentences:
          List<int>.from(json['completed_sentences'] as List<dynamic>? ?? []),
      pronunciationScores: scores,
      lastLearnedAt: DateTime.tryParse(
            json['last_learned_at'] as String? ?? '',
          ) ??
          DateTime.now(),
      totalLearnTime: json['total_learn_time'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'unit_id': unitId,
    'completed_sentences': completedSentences,
    'pronunciation_scores': pronunciationScores.map(
      (k, v) => MapEntry(k.toString(), v),
    ),
    'last_learned_at': lastLearnedAt.toIso8601String(),
    'total_learn_time': totalLearnTime,
  };

  /// 获取学习进度百分比
  double getProgressPercentage(int totalSentences) {
    if (totalSentences == 0) return 0;
    return completedSentences.length / totalSentences;
  }

  /// 获取平均发音评分
  double getAveragePronunciationScore() {
    if (pronunciationScores.isEmpty) return 0;
    final total =
        pronunciationScores.values.reduce((a, b) => a + b);
    return total / pronunciationScores.length;
  }
}
