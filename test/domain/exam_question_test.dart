import 'package:flutter_test/flutter_test.dart';
import 'package:ielts_prep/domain/models/exam_question.dart';

void main() {
  group('ExamQuestion Grading Tests', () {
    test('Accurate answer matching case-insensitive', () {
      final q = ExamQuestion(
        questionNumber: 1,
        promptBefore: 'Name: Luisa',
        acceptableAnswers: ['Gould'],
        targetSentenceIndex: 3,
        userAnswer: 'gould',
      );

      expect(q.isCorrect, isTrue);
    });

    test('Answers with whitespace and punctuation trim correctly', () {
      final q = ExamQuestion(
        questionNumber: 2,
        promptBefore: 'Occupation: Environmental',
        acceptableAnswers: ['consultant'],
        targetSentenceIndex: 3,
        userAnswer: '  Consultant.  ',
      );

      expect(q.isCorrect, isTrue);
    });

    test('Incorrect or empty answers return false', () {
      final q = ExamQuestion(
        questionNumber: 3,
        promptBefore: 'Main purpose of journey:',
        acceptableAnswers: ['commuting'],
        targetSentenceIndex: 4,
        userAnswer: 'holiday',
      );

      expect(q.isCorrect, isFalse);

      q.userAnswer = '';
      expect(q.isCorrect, isFalse);
    });

    test('Multiple alternative acceptable answers are supported', () {
      final q = ExamQuestion(
        questionNumber: 4,
        promptBefore: 'Railway line days a week:',
        acceptableAnswers: ['5', 'five'],
        targetSentenceIndex: 5,
        userAnswer: '5',
      );

      expect(q.isCorrect, isTrue);

      q.userAnswer = 'five';
      expect(q.isCorrect, isTrue);
    });
  });
}
