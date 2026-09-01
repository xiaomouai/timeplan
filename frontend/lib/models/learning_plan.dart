import 'package:intl/intl.dart';

class LearningPlan {
  final String? bookName;
  final int totalWords;
  final int studiedWords;
  final int masteredWords;
  final int dailyGoalWords;
  final DateTime? estimatedCompletionDate;

  const LearningPlan({
    required this.bookName,
    required this.totalWords,
    required this.studiedWords,
    required this.masteredWords,
    required this.dailyGoalWords,
    required this.estimatedCompletionDate,
  });

  double get progress => totalWords == 0 ? 0 : studiedWords / totalWords;

  String get formattedEstimatedDate {
    if (estimatedCompletionDate == null) return '--';
    return DateFormat('MM-dd').format(estimatedCompletionDate!);
  }

  static LearningPlan compute({
    String? bookName,
    required int totalWords,
    required int studiedWords,
    required int masteredWords,
    required int dailyGoalWords,
  }) {
    DateTime? eta;
    if (dailyGoalWords > 0 && totalWords > studiedWords) {
      final remaining = totalWords - studiedWords;
      final days = (remaining / dailyGoalWords).ceil();
      eta = DateTime.now().add(Duration(days: days));
    }
    return LearningPlan(
      bookName: bookName,
      totalWords: totalWords,
      studiedWords: studiedWords,
      masteredWords: masteredWords,
      dailyGoalWords: dailyGoalWords,
      estimatedCompletionDate: eta,
    );
  }
}
