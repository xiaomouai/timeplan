class PronunciationResult {
  final String word;
  final String recognizedText;
  final double overallScore;
  final String level;
  final double accuracyScore;
  final double fluencyScore;
  final List<SyllableScore> syllableScores;
  final String feedback;
  final List<String> suggestions;
  final bool isCorrect;

  PronunciationResult({
    required this.word,
    required this.recognizedText,
    required this.overallScore,
    required this.level,
    required this.accuracyScore,
    required this.fluencyScore,
    required this.syllableScores,
    required this.feedback,
    required this.suggestions,
    required this.isCorrect,
  });

  factory PronunciationResult.fromJson(Map<String, dynamic> json) {
    return PronunciationResult(
      word: json['word'] ?? '',
      recognizedText: json['recognized_text'] ?? '',
      overallScore: (json['overall_score'] ?? 0).toDouble(),
      level: json['level'] ?? 'poor',
      accuracyScore: (json['accuracy_score'] ?? 0).toDouble(),
      fluencyScore: (json['fluency_score'] ?? 0).toDouble(),
      syllableScores: (json['syllable_scores'] as List? ?? [])
          .map((item) => SyllableScore.fromJson(item))
          .toList(),
      feedback: json['feedback'] ?? '',
      suggestions: List<String>.from(json['suggestions'] ?? []),
      isCorrect: json['is_correct'] ?? false,
    );
  }
}

class SyllableScore {
  final int syllableIndex;
  final String syllableText;
  final String expectedPhoneme;
  final String recognizedPhoneme;
  final double score;
  final bool isCorrect;
  final String feedback;

  SyllableScore({
    required this.syllableIndex,
    required this.syllableText,
    required this.expectedPhoneme,
    required this.recognizedPhoneme,
    required this.score,
    required this.isCorrect,
    required this.feedback,
  });

  factory SyllableScore.fromJson(Map<String, dynamic> json) {
    return SyllableScore(
      syllableIndex: json['syllable_index'] ?? 0,
      syllableText: json['syllable_text'] ?? '',
      expectedPhoneme: json['expected_phoneme'] ?? '',
      recognizedPhoneme: json['recognized_phoneme'] ?? '',
      score: (json['score'] ?? 0).toDouble(),
      isCorrect: json['is_correct'] ?? false,
      feedback: json['feedback'] ?? '',
    );
  }
}
