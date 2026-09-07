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
  });
}
