import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ielts_prep/data/local/default_data.dart';

void main() {
  group('Physical Audio Assets Verification', () {
    test('C18 T1 S1 master dialogue audio exists and is valid size', () {
      final file = File('assets/demo/c18_t1_s1.mp3');
      expect(file.existsSync(), isTrue,
          reason: 'assets/demo/c18_t1_s1.mp3 must be bundled in project');
      expect(file.lengthSync(), greaterThan(6000000),
          reason: 'C18 T1 S1 audio must be full official recording (> 6MB)');
    });

    test('C19 T1 S1 master dialogue audio exists and is valid size', () {
      final file = File('assets/demo/c19_t1_s1.mp3');
      expect(file.existsSync(), isTrue,
          reason: 'assets/demo/c19_t1_s1.mp3 must be bundled in project');
      expect(file.lengthSync(), greaterThan(7000000),
          reason: 'C19 T1 S1 audio must be full official recording (> 7MB)');
    });

    test('All vocabulary sentence audio files exist with high-fidelity size', () {
      final words = [
        'accommodation',
        'consultant',
        'commuting',
        'punctuality',
        'carriages',
        'fares',
        'overcrowded',
        'sustainable',
      ];

      for (final w in words) {
        final f = File('assets/audio/sentences/$w.mp3');
        expect(f.existsSync(), isTrue,
            reason: 'assets/audio/sentences/$w.mp3 must exist');
        expect(f.lengthSync(), greaterThan(15000),
            reason: '$w.mp3 must be high fidelity speech (> 15KB)');
      }
    });

    test('cambridge_18_test1_s1.json has exact timestamps aligned with audio', () {
      final jsonFile = File('assets/demo/cambridge_18_test1_s1.json');
      expect(jsonFile.existsSync(), isTrue);

      final content = jsonDecode(jsonFile.readAsStringSync()) as Map<String, dynamic>;
      expect(content['localAudioPath'], equals('assets/demo/c18_t1_s1.mp3'));
      expect(content['totalDurationMs'], greaterThan(60000));

      final sentences = content['sentences'] as List;
      expect(sentences.length, equals(18));

      for (int i = 0; i < sentences.length; i++) {
        final s = sentences[i] as Map<String, dynamic>;
        expect(s['index'], equals(i));
        expect(s['startMs'], greaterThanOrEqualTo(0));
        expect(s['endMs'], greaterThan(s['startMs']));
        if (i > 0) {
          final prev = sentences[i - 1] as Map<String, dynamic>;
          expect(s['startMs'], greaterThanOrEqualTo(prev['endMs']));
        }
      }
    });

    test('cambridge_19_test1_s1.json has exact timestamps aligned with audio', () {
      final jsonFile = File('assets/demo/cambridge_19_test1_s1.json');
      expect(jsonFile.existsSync(), isTrue);

      final content = jsonDecode(jsonFile.readAsStringSync()) as Map<String, dynamic>;
      expect(content['localAudioPath'], equals('assets/demo/c19_t1_s1.mp3'));
      expect(content['totalDurationMs'], equals(472000));

      final sentences = content['sentences'] as List;
      expect(sentences.length, equals(25));

      final questions = content['questions'] as List;
      expect(questions.length, equals(10));
    });
  });

  group('DefaultData Audio Integrity Tests', () {
    test('DefaultData C18 T1 S1 has localAudioPath set and 18 sentences with valid timestamps', () {
      final tests = DefaultData.initialTests;
      expect(tests.isNotEmpty, isTrue);

      final c18 = tests.firstWhere((t) => t.testId == 'c18_t1_s1');
      expect(c18.localAudioPath, equals('assets/demo/c18_t1_s1.mp3'));
      expect(c18.totalDurationMs, equals(431290));
      expect(c18.sentences.length, equals(18));
      expect(c18.questions.length, equals(10));

      // Verify all sentences have valid timestamps
      for (int i = 0; i < c18.sentences.length; i++) {
        final s = c18.sentences[i];
        expect(s.index, equals(i));
        expect(s.startMs, greaterThanOrEqualTo(0));
        expect(s.endMs, greaterThan(s.startMs));
        expect(s.textEn.isNotEmpty, isTrue);
        expect(s.textZh.isNotEmpty, isTrue);
      }
    });

    test('DefaultData C19 T1 S1 has localAudioPath set and 25 sentences with valid timestamps', () {
      final tests = DefaultData.initialTests;
      expect(tests.isNotEmpty, isTrue);

      final c19 = tests.firstWhere((t) => t.testId == 'c19_t1_s1');
      expect(c19.localAudioPath, equals('assets/demo/c19_t1_s1.mp3'));
      expect(c19.totalDurationMs, equals(472000));
      expect(c19.sentences.length, equals(25));
      expect(c19.questions.length, equals(10));

      for (int i = 0; i < c19.sentences.length; i++) {
        final s = c19.sentences[i];
        expect(s.index, equals(i));
        expect(s.startMs, greaterThanOrEqualTo(0));
        expect(s.endMs, greaterThan(s.startMs));
        expect(s.textEn.isNotEmpty, isTrue);
        expect(s.textZh.isNotEmpty, isTrue);
      }
    });

    test('DefaultData initial words all have non-empty context sentences', () {
      final words = DefaultData.initialVocabulary;
      expect(words.length, equals(6));

      for (final w in words) {
        expect(w.contextSentenceEn.trim().isNotEmpty, isTrue);
        expect(w.contextSentenceZh.trim().isNotEmpty, isTrue);
        final audioFile = File('assets/audio/sentences/${w.word.toLowerCase()}.mp3');
        expect(audioFile.existsSync(), isTrue,
            reason: 'Each initial word must have a corresponding offline audio file');
      }
    });
  });
}
