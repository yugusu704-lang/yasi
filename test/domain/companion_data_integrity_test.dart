import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ielts_prep/domain/models/listening_test_info.dart';

void main() {
  group('Cambridge Companion Data Integrity Tests', () {
    test('cambridge_18_test1_s1.json contains valid 10 official questions and sentences', () {
      final file = File('assets/demo/cambridge_18_test1_s1.json');
      expect(file.existsSync(), isTrue);

      final jsonStr = file.readAsStringSync();
      final Map<String, dynamic> data = jsonDecode(jsonStr);
      final testInfo = ListeningTestInfo.fromJson(data);

      expect(testInfo.testId, 'c18_t1_s1');
      expect(testInfo.sentences.length, greaterThanOrEqualTo(10));
      expect(testInfo.questions.length, 10,
          reason: 'Every section must have exactly 10 official exam questions');

      for (final q in testInfo.questions) {
        expect(q.questionNumber, inInclusiveRange(1, 10));
        expect(q.acceptableAnswers, isNotEmpty);
        expect(q.targetSentenceIndex, greaterThanOrEqualTo(0));
        expect(q.targetSentenceIndex, lessThan(testInfo.sentences.length),
            reason:
                'targetSentenceIndex must point to a valid sentence in sentences list');
      }
    });

    test('cambridge_19_test1_s1.json contains valid 10 official questions and sentences', () {
      final file = File('assets/demo/cambridge_19_test1_s1.json');
      expect(file.existsSync(), isTrue);

      final jsonStr = file.readAsStringSync();
      final Map<String, dynamic> data = jsonDecode(jsonStr);
      final testInfo = ListeningTestInfo.fromJson(data);

      expect(testInfo.testId, 'c19_t1_s1');
      expect(testInfo.book, 'Cambridge 19');
      expect(testInfo.sentences.length, greaterThanOrEqualTo(10));
      expect(testInfo.questions.length, 10,
          reason: 'Every section must have exactly 10 official exam questions');

      for (int i = 0; i < testInfo.sentences.length; i++) {
        final s = testInfo.sentences[i];
        expect(s.index, i);
        expect(s.startMs, lessThanOrEqualTo(s.endMs));
        expect(s.textEn, isNotEmpty);
        expect(s.textZh, isNotEmpty);
      }

      for (final q in testInfo.questions) {
        expect(q.questionNumber, inInclusiveRange(1, 10));
        expect(q.acceptableAnswers, isNotEmpty);
        expect(q.targetSentenceIndex, greaterThanOrEqualTo(0));
        expect(q.targetSentenceIndex, lessThan(testInfo.sentences.length),
            reason:
                'targetSentenceIndex must point to a valid sentence in sentences list');
      }

      // Check official answers
      expect(testInfo.questions[0].acceptableAnswers, contains('69'));
      expect(testInfo.questions[1].acceptableAnswers, contains('stream'));
      expect(testInfo.questions[2].acceptableAnswers, contains('data'));
      expect(testInfo.questions[3].acceptableAnswers, contains('map'));
      expect(testInfo.questions[4].acceptableAnswers, contains('visitors'));
    });
  });
}
