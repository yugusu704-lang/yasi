class ExamQuestion {
  final int questionNumber;
  final String promptBefore;
  final String promptAfter;
  final List<String> acceptableAnswers;
  final int targetSentenceIndex;
  String userAnswer;

  ExamQuestion({
    required this.questionNumber,
    required this.promptBefore,
    this.promptAfter = '',
    required this.acceptableAnswers,
    required this.targetSentenceIndex,
    this.userAnswer = '',
  });

  bool get isAnswered => userAnswer.trim().isNotEmpty;

  bool get isCorrect {
    final cleanedUser = _clean(userAnswer);
    if (cleanedUser.isEmpty) return false;

    return acceptableAnswers.any((ans) => _clean(ans) == cleanedUser);
  }

  static String _clean(String input) {
    return input
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[.,;!?"]'), '')
        .replaceAll("'", "");
  }

  ExamQuestion copyWith({
    int? questionNumber,
    String? promptBefore,
    String? promptAfter,
    List<String>? acceptableAnswers,
    int? targetSentenceIndex,
    String? userAnswer,
  }) {
    return ExamQuestion(
      questionNumber: questionNumber ?? this.questionNumber,
      promptBefore: promptBefore ?? this.promptBefore,
      promptAfter: promptAfter ?? this.promptAfter,
      acceptableAnswers: acceptableAnswers ?? this.acceptableAnswers,
      targetSentenceIndex: targetSentenceIndex ?? this.targetSentenceIndex,
      userAnswer: userAnswer ?? this.userAnswer,
    );
  }
}
