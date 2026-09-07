import 'package:flutter_test/flutter_test.dart';
import 'package:ielts_prep/domain/fsrs/fsrs_algorithm.dart';
import 'package:ielts_prep/domain/fsrs/fsrs_card.dart';

void main() {
  group('FSRS Algorithm Tests', () {
    late FsrsAlgorithm fsrs;

    setUp(() {
      fsrs = FsrsAlgorithm();
    });

    test('Initial rating GOOD creates learning/review card with valid stability', () {
      final card = FsrsCard.newCard('vocab_1');
      final updated = fsrs.review(card, FsrsRating.good);

      expect(updated.state, FsrsState.review);
      expect(updated.reps, 1);
      expect(updated.stability, greaterThan(1.0));
      expect(updated.scheduledDays, greaterThanOrEqualTo(1));
      expect(updated.nextDue.isAfter(updated.lastReview), isTrue);
    });

    test('Initial rating AGAIN places card in learning with 1 day interval', () {
      final card = FsrsCard.newCard('vocab_2');
      final updated = fsrs.review(card, FsrsRating.again);

      expect(updated.state, FsrsState.learning);
      expect(updated.scheduledDays, 1);
      expect(updated.reps, 1);
    });

    test('Subsequent reviews increase stability on EASY rating', () {
      final card = FsrsCard.newCard('vocab_3');
      final day1 = fsrs.review(card, FsrsRating.good);
      final day2Time = day1.lastReview.add(const Duration(days: 3));
      final day2 = fsrs.review(day1, FsrsRating.easy, day2Time);

      expect(day2.stability, greaterThan(day1.stability));
      expect(day2.scheduledDays, greaterThan(day1.scheduledDays));
    });
  });
}
