import 'package:flutter_test/flutter_test.dart';
import 'package:ielts_prep/domain/models/study_stats.dart';
import 'package:ielts_prep/domain/audio/audio_player_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TodayListeningStats Model Tests', () {
    test('Calculates formattedMasteryRate accurately', () {
      const stats1 = TodayListeningStats(
        listeningMinutes: 25,
        repeatCount: 14,
        masteryRate: 0.854,
      );
      expect(stats1.listeningMinutes, 25);
      expect(stats1.repeatCount, 14);
      expect(stats1.formattedMasteryRate, '85%');

      const stats2 = TodayListeningStats(
        listeningMinutes: 0,
        repeatCount: 0,
        masteryRate: 0.0,
      );
      expect(stats2.formattedMasteryRate, '0%');

      const stats3 = TodayListeningStats(
        listeningMinutes: 60,
        repeatCount: 50,
        masteryRate: 1.0,
      );
      expect(stats3.formattedMasteryRate, '100%');
    });
  });

  group('OverallPrepStats Model Tests', () {
    test('Holds overall metrics accurately', () {
      const overall = OverallPrepStats(
        totalListeningHours: 12.5,
        fsrsMasteredWords: 150,
        streakDays: 5,
        retentionPrediction: 'Section 1/4 准确率预计 93%',
      );

      expect(overall.totalListeningHours, 12.5);
      expect(overall.fsrsMasteredWords, 150);
      expect(overall.streakDays, 5);
      expect(overall.retentionPrediction, contains('93%'));
    });
  });

  group('AudioPlayerService Tracking Hook Tests', () {
    test('Callbacks can be assigned and invoked without crash', () {
      final service = AudioPlayerService();
      int accumulatedSeconds = 0;
      int repeatedCount = 0;

      service.onListeningTimeAccumulated = (sec) {
        accumulatedSeconds += sec;
      };

      service.onSentenceRepeated = () {
        repeatedCount += 1;
      };

      service.onListeningTimeAccumulated?.call(5);
      service.onSentenceRepeated?.call();

      expect(accumulatedSeconds, 5);
      expect(repeatedCount, 1);
    });
  });
}
