import 'package:flutter_test/flutter_test.dart';
import 'package:xueba_app/models/learning_plan.dart';

void main() {
  group('LearningPlan.compute', () {
    test('computes ETA based on daily goal', () {
      final plan = LearningPlan.compute(
        bookName: 'TestBook',
        totalWords: 100,
        studiedWords: 10,
        masteredWords: 0,
        dailyGoalWords: 30,
      );
      expect(plan.progress, closeTo(0.1, 0.0001));
      expect(plan.formattedEstimatedDate.isNotEmpty, true);
    });

    test('handles zero total words', () {
      final plan = LearningPlan.compute(
        bookName: 'Empty',
        totalWords: 0,
        studiedWords: 0,
        masteredWords: 0,
        dailyGoalWords: 20,
      );
      expect(plan.progress, 0);
      expect(plan.formattedEstimatedDate, '--');
    });

    test('no ETA when goal is zero', () {
      final plan = LearningPlan.compute(
        bookName: 'NoGoal',
        totalWords: 100,
        studiedWords: 50,
        masteredWords: 0,
        dailyGoalWords: 0,
      );
      expect(plan.formattedEstimatedDate, '--');
    });
  });
}
