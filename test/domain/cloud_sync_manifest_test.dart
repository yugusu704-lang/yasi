import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ielts_prep/domain/models/cloud_manifest.dart';

void main() {
  group('Cloud Manifest & Ingestion Models Tests', () {
    test('Parses valid manifest JSON with multi-source fallback URLs', () {
      const sampleJson = '''
      {
        "version": 1,
        "lastUpdated": "2026-09-07T12:00:00Z",
        "tests": [
          {
            "testId": "c18_t1_s2",
            "book": 18,
            "testNum": 1,
            "sectionNum": 2,
            "title": "C18 Test 1 Section 2: Community Volunteering",
            "audioSize": 5242880,
            "audioUrls": [
              "https://cdn.ielts-prep.internal/audio/c18_t1_s2.mp3",
              "https://drive.google.com/uc?export=download&id=TEST_DRIVE_ID_1"
            ],
            "companionJsonUrl": "https://cdn.ielts-prep.internal/json/c18_t1_s2.json",
            "sha256": "abcdef1234567890"
          }
        ]
      }
      ''';

      final Map<String, dynamic> data = jsonDecode(sampleJson);
      final manifest = CloudManifest.fromJson(data);

      expect(manifest.version, 1);
      expect(manifest.tests.length, 1);

      final entry = manifest.tests.first;
      expect(entry.testId, 'c18_t1_s2');
      expect(entry.book, 18);
      expect(entry.testNum, 1);
      expect(entry.sectionNum, 2);
      expect(entry.formattedSize, '5.0 MB');
      expect(entry.audioUrls.length, 2);
      expect(entry.preferredAudioUrl,
          'https://cdn.ielts-prep.internal/audio/c18_t1_s2.mp3');
      expect(entry.googleDriveFallbackUrl,
          'https://drive.google.com/uc?export=download&id=TEST_DRIVE_ID_1');
    });

    test('Gracefully handles missing optional fields in manifest', () {
      const minimalJson = '''
      {
        "version": 1,
        "tests": [
          {
            "testId": "c17_t1_s1",
            "book": 17,
            "testNum": 1,
            "sectionNum": 1,
            "title": "C17 Test 1 Section 1",
            "audioUrls": ["https://example.com/audio.mp3"],
            "companionJsonUrl": "https://example.com/data.json"
          }
        ]
      }
      ''';

      final manifest = CloudManifest.fromJson(jsonDecode(minimalJson));
      final entry = manifest.tests.first;

      expect(entry.audioSize, 0);
      expect(entry.formattedSize, '0 MB');
      expect(entry.sha256, isNull);
      expect(entry.preferredAudioUrl, 'https://example.com/audio.mp3');
    });
  });
}
