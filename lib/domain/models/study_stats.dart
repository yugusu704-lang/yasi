class TodayListeningStats {
  final int listeningMinutes;
  final int repeatCount;
  final double masteryRate;

  const TodayListeningStats({
    required this.listeningMinutes,
    required this.repeatCount,
    required this.masteryRate,
  });

  String get formattedMasteryRate => '${(masteryRate * 100).round()}%';
}

class OverallPrepStats {
  final double totalListeningHours;
  final int fsrsMasteredWords;
  final int streakDays;
  final String retentionPrediction;

  const OverallPrepStats({
    required this.totalListeningHours,
    required this.fsrsMasteredWords,
    required this.streakDays,
    required this.retentionPrediction,
  });
}
