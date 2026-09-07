import 'dart:math';

enum DiffStatus {
  correct,
  typo,
  missing,
  extra,
}

class DiffToken {
  final String text;
  final String? expected;
  final DiffStatus status;

  const DiffToken({
    required this.text,
    this.expected,
    required this.status,
  });
}

class DiffResult {
  final List<DiffToken> tokens;
  final int correctCount;
  final int typoCount;
  final int missingCount;
  final int extraCount;
  final double accuracy;

  const DiffResult({
    required this.tokens,
    required this.correctCount,
    required this.typoCount,
    required this.missingCount,
    required this.extraCount,
    required this.accuracy,
  });
}

class SentenceDiffMatcher {
  const SentenceDiffMatcher();

  DiffResult diff({
    required String original,
    required String userInput,
  }) {
    final origWords = _splitWords(original);
    final userWords = _splitWords(userInput);

    if (origWords.isEmpty && userWords.isEmpty) {
      return const DiffResult(
        tokens: [],
        correctCount: 0,
        typoCount: 0,
        missingCount: 0,
        extraCount: 0,
        accuracy: 1.0,
      );
    }

    if (origWords.isEmpty) {
      final tokens = userWords
          .map((w) => DiffToken(text: w, status: DiffStatus.extra))
          .toList();
      return DiffResult(
        tokens: tokens,
        correctCount: 0,
        typoCount: 0,
        missingCount: 0,
        extraCount: userWords.length,
        accuracy: 0.0,
      );
    }

    if (userWords.isEmpty) {
      final tokens = origWords
          .map((w) => DiffToken(text: w, status: DiffStatus.missing))
          .toList();
      return DiffResult(
        tokens: tokens,
        correctCount: 0,
        typoCount: 0,
        missingCount: origWords.length,
        extraCount: 0,
        accuracy: 0.0,
      );
    }

    // Needleman-Wunsch alignment with scoring:
    // Match: +3
    // Typo: +1
    // Indel (gap): -1
    final n = origWords.length;
    final m = userWords.length;
    final score = List.generate(n + 1, (_) => List.filled(m + 1, 0));

    for (int i = 0; i <= n; i++) {
      score[i][0] = -i;
    }
    for (int j = 0; j <= m; j++) {
      score[0][j] = -j;
    }

    for (int i = 1; i <= n; i++) {
      final w1 = origWords[i - 1];
      final c1 = _clean(w1);
      for (int j = 1; j <= m; j++) {
        final w2 = userWords[j - 1];
        final c2 = _clean(w2);

        int matchScore;
        if (c1 == c2) {
          matchScore = 3;
        } else if (_isTypo(c1, c2)) {
          matchScore = 1;
        } else {
          matchScore = -2;
        }

        final diag = score[i - 1][j - 1] + matchScore;
        final del = score[i - 1][j] - 1;
        final ins = score[i][j - 1] - 1;

        score[i][j] = max(diag, max(del, ins));
      }
    }

    // Backtrack
    final List<DiffToken> tokens = [];
    int i = n;
    int j = m;

    while (i > 0 || j > 0) {
      if (i > 0 && j > 0) {
        final w1 = origWords[i - 1];
        final w2 = userWords[j - 1];
        final c1 = _clean(w1);
        final c2 = _clean(w2);

        int matchScore;
        if (c1 == c2) {
          matchScore = 3;
        } else if (_isTypo(c1, c2)) {
          matchScore = 1;
        } else {
          matchScore = -2;
        }

        if (score[i][j] == score[i - 1][j - 1] + matchScore && matchScore > -2) {
          if (c1 == c2) {
            tokens.add(DiffToken(text: w1, status: DiffStatus.correct));
          } else {
            tokens.add(DiffToken(
              text: w2,
              expected: w1,
              status: DiffStatus.typo,
            ));
          }
          i--;
          j--;
          continue;
        }
      }

      if (i > 0 && (j == 0 || score[i][j] == score[i - 1][j] - 1)) {
        tokens.add(DiffToken(
          text: origWords[i - 1],
          status: DiffStatus.missing,
        ));
        i--;
      } else if (j > 0 && (i == 0 || score[i][j] == score[i][j - 1] - 1)) {
        tokens.add(DiffToken(
          text: userWords[j - 1],
          status: DiffStatus.extra,
        ));
        j--;
      } else {
        // Fallback to diagonal
        if (i > 0) i--;
        if (j > 0) j--;
      }
    }

    final reversedTokens = tokens.reversed.toList();

    int correct = 0;
    int typo = 0;
    int missing = 0;
    int extra = 0;

    for (final t in reversedTokens) {
      switch (t.status) {
        case DiffStatus.correct:
          correct++;
          break;
        case DiffStatus.typo:
          typo++;
          break;
        case DiffStatus.missing:
          missing++;
          break;
        case DiffStatus.extra:
          extra++;
          break;
      }
    }

    final accuracy = origWords.isNotEmpty
        ? (correct + (typo * 0.5)) / origWords.length
        : 0.0;

    return DiffResult(
      tokens: reversedTokens,
      correctCount: correct,
      typoCount: typo,
      missingCount: missing,
      extraCount: extra,
      accuracy: accuracy.clamp(0.0, 1.0),
    );
  }

  static List<String> _splitWords(String text) {
    return text
        .trim()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .toList();
  }

  static String _clean(String word) {
    return word
        .toLowerCase()
        .replaceAll(RegExp(r'[.,;!?":()\[\]]'), '')
        .replaceAll("'", "")
        .trim();
  }

  static bool _isTypo(String w1, String w2) {
    if (w1.isEmpty || w2.isEmpty) return false;
    if (w1 == w2) return false;
    if (w1.length < 3 || w2.length < 3) return false;

    final dist = _levenshtein(w1, w2);
    return dist <= 2;
  }

  static int _levenshtein(String s1, String s2) {
    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    List<int> prev = List<int>.generate(s2.length + 1, (i) => i);
    List<int> curr = List<int>.filled(s2.length + 1, 0);

    for (int i = 0; i < s1.length; i++) {
      curr[0] = i + 1;
      for (int j = 0; j < s2.length; j++) {
        final cost = (s1[i] == s2[j]) ? 0 : 1;
        curr[j + 1] = min(
          curr[j] + 1,
          min(prev[j + 1] + 1, prev[j] + cost),
        );
      }
      prev = List<int>.from(curr);
    }
    return prev[s2.length];
  }
}
