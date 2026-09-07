import 'package:flutter_test/flutter_test.dart';
import 'package:ielts_prep/domain/diff/sentence_diff_matcher.dart';

void main() {
  group('SentenceDiffMatcher Tests', () {
    late SentenceDiffMatcher matcher;

    setUp(() {
      matcher = const SentenceDiffMatcher();
    });

    test('Identical sentence produces all correct tokens', () {
      const original = 'Good morning, could you spare a few minutes?';
      const userInput = 'Good morning could you spare a few minutes';

      final result = matcher.diff(original: original, userInput: userInput);

      expect(result.accuracy, 1.0);
      expect(result.tokens.every((t) => t.status == DiffStatus.correct), isTrue);
      expect(result.correctCount, 8);
      expect(result.missingCount, 0);
      expect(result.typoCount, 0);
      expect(result.extraCount, 0);
    });

    test('Detects missing words', () {
      const original = 'could you spare a few minutes';
      const userInput = 'could you a minutes'; // missing 'spare' and 'few'

      final result = matcher.diff(original: original, userInput: userInput);

      expect(result.accuracy, lessThan(1.0));
      expect(result.missingCount, 2);
      expect(result.tokens.any((t) => t.text.toLowerCase() == 'spare' && t.status == DiffStatus.missing), isTrue);
      expect(result.tokens.any((t) => t.text.toLowerCase() == 'few' && t.status == DiffStatus.missing), isTrue);
    });

    test('Detects minor typo in spelling', () {
      const original = 'punctuality and frequency';
      const userInput = 'punctualty and frequncy'; // typos

      final result = matcher.diff(original: original, userInput: userInput);

      expect(result.typoCount, 2);
      expect(result.tokens.any((t) => t.status == DiffStatus.typo && t.expected == 'punctuality'), isTrue);
      expect(result.tokens.any((t) => t.status == DiffStatus.typo && t.expected == 'frequency'), isTrue);
    });

    test('Detects extra words entered by user', () {
      const original = 'train service';
      const userInput = 'the fast train service'; // 'the' and 'fast' are extra

      final result = matcher.diff(original: original, userInput: userInput);

      expect(result.extraCount, 2);
      expect(result.tokens.any((t) => t.status == DiffStatus.extra && t.text == 'the'), isTrue);
    });
  });
}
