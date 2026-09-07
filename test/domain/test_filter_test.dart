import 'package:flutter_test/flutter_test.dart';
import 'package:ielts_prep/domain/models/listening_test_info.dart';

void main() {
  group('IELTS Book Filtering & Sorting Tests', () {
    final mockTests = [
      ListeningTestInfo(
        testId: 'c19_t1_s1',
        book: 'Cambridge 19',
        testNumber: 1,
        section: 1,
        title: 'C19 T1 S1',
        audioUrl: '',
        localAudioPath: '',
        totalDurationMs: 60000,
        sentences: const [],
      ),
      ListeningTestInfo(
        testId: 'c18_t1_s1',
        book: 'Cambridge 18',
        testNumber: 1,
        section: 1,
        title: 'C18 T1 S1',
        audioUrl: '',
        localAudioPath: '',
        totalDurationMs: 60000,
        sentences: const [],
      ),
      ListeningTestInfo(
        testId: 'c4_t1_s1',
        book: 'Cambridge 4',
        testNumber: 1,
        section: 1,
        title: 'C4 T1 S1',
        audioUrl: '',
        localAudioPath: '',
        totalDurationMs: 60000,
        sentences: const [],
      ),
    ];

    test('Book sorting sorts descending from C19 to C4', () {
      final bookSet = mockTests.map((t) => t.book).toSet().toList();
      bookSet.sort((a, b) {
        final numA =
            int.tryParse(RegExp(r'\d+').firstMatch(a)?.group(0) ?? '') ?? 0;
        final numB =
            int.tryParse(RegExp(r'\d+').firstMatch(b)?.group(0) ?? '') ?? 0;
        return numB.compareTo(numA);
      });

      expect(bookSet, ['Cambridge 19', 'Cambridge 18', 'Cambridge 4']);
    });

    test('Filter logic accurately filters by book number or prefix', () {
      List<ListeningTestInfo> filterTests(String filter) {
        if (filter == '全部') return mockTests;
        final filterNum = RegExp(r'\d+').firstMatch(filter)?.group(0);
        if (filterNum != null) {
          return mockTests.where((t) {
            final tNum = RegExp(r'\d+').firstMatch(t.book)?.group(0);
            return tNum == filterNum || t.testId.startsWith('c${filterNum}_');
          }).toList();
        }
        return mockTests.where((t) => t.book == filter).toList();
      }

      expect(filterTests('全部').length, 3);
      expect(filterTests('剑18').first.testId, 'c18_t1_s1');
      expect(filterTests('Cambridge 19').first.testId, 'c19_t1_s1');
      expect(filterTests('剑4').first.testId, 'c4_t1_s1');
      expect(filterTests('剑10'), isEmpty);
    });
  });
}
