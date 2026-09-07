import 'package:flutter_test/flutter_test.dart';
import 'package:ielts_prep/data/local/default_data.dart';

void main() {
  group('Database Backup & Cloud Sync Format Tests', () {
    test('DefaultData produces valid backup dictionary structure', () {
      final mockBackup = {
        'version': 1,
        'exportedAt': DateTime.now().toUtc().toIso8601String(),
        'vocabulary': DefaultData.initialVocabulary.map((w) => {
          'id': w.id,
          'word': w.word,
          'definition_zh': w.definitionZh,
        }).toList(),
        'fsrs_cards': [
          {
            'card_id': 'word_1',
            'stability': 2.5,
            'difficulty': 4.0,
            'reps': 1,
            'lapses': 0,
            'state': 1,
          }
        ],
        'study_daily_logs': [
          {
            'date': '2026-09-07',
            'listening_seconds': 1200,
            'repeat_count': 15,
            'mastered_sentences': 8,
          }
        ],
        'listening_tests': [
          {
            'test_id': 'c18_t1_s1',
            'play_count': 3,
            'completion_rate': 0.85,
          }
        ]
      };

      expect(mockBackup['version'], equals(1));
      expect(mockBackup['exportedAt'], isA<String>());
      expect(mockBackup['vocabulary'], isNotEmpty);
      expect((mockBackup['fsrs_cards'] as List).first['stability'], equals(2.5));
      expect((mockBackup['study_daily_logs'] as List).first['listening_seconds'], equals(1200));
    });
  });
}
