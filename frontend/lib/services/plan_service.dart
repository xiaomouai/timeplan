import '../models/learning_plan.dart';
import '../utils/learning_data_service.dart';
import '../utils/settings_helper.dart';
import '../models/word_learning_record.dart';

class PlanService {
  static PlanService? _instance;
  static PlanService get instance => _instance ??= PlanService._();
  PlanService._();

  Future<LearningPlan> getCurrentPlan(String wordBookName, int totalWords) async {
    final records = await LearningDataService.instance.getWordBookRecords(wordBookName);
    final mastered = records.where((r) => r.memoryLevel == MemoryLevel.mastered).length;
    final dailyGoal = await SettingsHelper.getDailyGoalWords();
    return LearningPlan.compute(
      bookName: wordBookName,
      totalWords: totalWords,
      studiedWords: records.length,
      masteredWords: mastered,
      dailyGoalWords: dailyGoal,
    );
  }
}
