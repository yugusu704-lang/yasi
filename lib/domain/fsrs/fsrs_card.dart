enum FsrsRating {
  again(1, '忘记'),
  hard(2, '困难'),
  good(3, '良好'),
  easy(4, '简单');

  final int value;
  final String label;
  const FsrsRating(this.value, this.label);
}

enum FsrsState {
  newCard(0),
  learning(1),
  review(2),
  relearning(3);

  final int value;
  const FsrsState(this.value);
}

class FsrsCard {
  final String cardId;
  final double stability;
  final double difficulty;
  final int elapsedDays;
  final int scheduledDays;
  final int reps;
  final int lapses;
  final FsrsState state;
  final DateTime lastReview;
  final DateTime nextDue;

  const FsrsCard({
    required this.cardId,
    this.stability = 0.0,
    this.difficulty = 0.0,
    this.elapsedDays = 0,
    this.scheduledDays = 0,
    this.reps = 0,
    this.lapses = 0,
    this.state = FsrsState.newCard,
    required this.lastReview,
    required this.nextDue,
  });

  factory FsrsCard.newCard(String cardId) {
    final now = DateTime.now();
    return FsrsCard(
      cardId: cardId,
      stability: 0.0,
      difficulty: 0.0,
      elapsedDays: 0,
      scheduledDays: 0,
      reps: 0,
      lapses: 0,
      state: FsrsState.newCard,
      lastReview: now,
      nextDue: now,
    );
  }

  FsrsCard copyWith({
    String? cardId,
    double? stability,
    double? difficulty,
    int? elapsedDays,
    int? scheduledDays,
    int? reps,
    int? lapses,
    FsrsState? state,
    DateTime? lastReview,
    DateTime? nextDue,
  }) {
    return FsrsCard(
      cardId: cardId ?? this.cardId,
      stability: stability ?? this.stability,
      difficulty: difficulty ?? this.difficulty,
      elapsedDays: elapsedDays ?? this.elapsedDays,
      scheduledDays: scheduledDays ?? this.scheduledDays,
      reps: reps ?? this.reps,
      lapses: lapses ?? this.lapses,
      state: state ?? this.state,
      lastReview: lastReview ?? this.lastReview,
      nextDue: nextDue ?? this.nextDue,
    );
  }
}
