import 'dart:math' as math;
import 'fsrs_card.dart';

class FsrsAlgorithm {
  final double requestRetention;
  final double maximumInterval;
  final List<double> w;

  FsrsAlgorithm({
    this.requestRetention = 0.9,
    this.maximumInterval = 36500,
    List<double>? weights,
  }) : w = weights ??
            const [
              0.40255, 1.18385, 3.173, 15.69105, 7.1949, 0.5345, 1.4604,
              0.0046, 1.54575, 0.1192, 1.01925, 1.9395, 0.11, 0.29605, 2.2698,
              0.2315, 2.9898
            ];

  double initStability(FsrsRating rating) {
    return math.max(0.1, w[rating.value - 1]);
  }

  double initDifficulty(FsrsRating rating) {
    final d = w[4] - math.exp(w[5] * (rating.value - 1)) + 1;
    return d.clamp(1.0, 10.0);
  }

  double nextDifficulty(double d, FsrsRating rating) {
    final nextD = d - w[6] * (rating.value - 3);
    final meanReversion = w[7] * initDifficulty(FsrsRating.good) + (1 - w[7]) * nextD;
    return meanReversion.clamp(1.0, 10.0);
  }

  double retrievability(int elapsedDays, double stability) {
    if (stability <= 0) return 0.0;
    return math.pow(1 + elapsedDays / (9 * stability), -1).toDouble();
  }

  int nextInterval(double stability) {
    final factor = math.log(requestRetention) / math.log(0.9);
    final interval = (stability * factor).round();
    return interval.clamp(1, maximumInterval.toInt());
  }

  double nextRecallStability(
      double d, double s, double r, FsrsRating rating) {
    final hardPenalty = rating == FsrsRating.hard ? w[15] : 1.0;
    final easyBonus = rating == FsrsRating.easy ? w[16] : 1.0;
    final newS = s *
        (1 +
            math.exp(w[8]) *
                (11 - d) *
                math.pow(s, -w[9]) *
                (math.exp((1 - r) * w[10]) - 1) *
                hardPenalty *
                easyBonus);
    return math.max(0.1, newS);
  }

  double nextForgetStability(double d, double s, double r) {
    final newS = w[11] *
        math.pow(d, -w[12]) *
        (math.pow(s + 1, w[13]) - 1) *
        math.exp((1 - r) * w[14]);
    return math.max(0.1, newS);
  }

  FsrsCard review(FsrsCard card, FsrsRating rating, [DateTime? reviewTime]) {
    final now = reviewTime ?? DateTime.now();
    final elapsedDays = card.state == FsrsState.newCard
        ? 0
        : math.max(0, now.difference(card.lastReview).inDays);

    double newStability;
    double newDifficulty;
    FsrsState newState;
    int newLapses = card.lapses;

    if (card.state == FsrsState.newCard) {
      newStability = initStability(rating);
      newDifficulty = initDifficulty(rating);
      newState = (rating == FsrsRating.again) ? FsrsState.learning : FsrsState.review;
    } else {
      final r = retrievability(elapsedDays, card.stability);
      newDifficulty = nextDifficulty(card.difficulty, rating);

      if (rating == FsrsRating.again) {
        newStability = nextForgetStability(card.difficulty, card.stability, r);
        newState = FsrsState.relearning;
        newLapses += 1;
      } else {
        newStability = nextRecallStability(card.difficulty, card.stability, r, rating);
        newState = FsrsState.review;
      }
    }

    final interval = (rating == FsrsRating.again) ? 1 : nextInterval(newStability);
    final nextDue = now.add(Duration(days: interval));

    return card.copyWith(
      stability: newStability,
      difficulty: newDifficulty,
      elapsedDays: elapsedDays,
      scheduledDays: interval,
      reps: card.reps + 1,
      lapses: newLapses,
      state: newState,
      lastReview: now,
      nextDue: nextDue,
    );
  }
}
