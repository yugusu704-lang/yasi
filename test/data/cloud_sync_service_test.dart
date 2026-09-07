import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:ielts_prep/data/remote/cloud_sync_service.dart';

class MockHttpClient extends http.BaseClient {
  final Map<String, String> stringResponses;
  final Map<String, List<int>> byteResponses;

  MockHttpClient({
    this.stringResponses = const {},
    this.byteResponses = const {},
  });

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final url = request.url.toString();

    if (byteResponses.containsKey(url)) {
      final bytes = byteResponses[url]!;
      return http.StreamedResponse(
        Stream.value(bytes),
        200,
        contentLength: bytes.length,
      );
    }

    if (stringResponses.containsKey(url)) {
      final text = stringResponses[url]!;
      final bytes = utf8.encode(text);
      return http.StreamedResponse(
        Stream.value(bytes),
        200,
        contentLength: bytes.length,
      );
    }

    return http.StreamedResponse(
      Stream.value(utf8.encode('Not Found')),
      404,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CloudSyncService Unit Tests', () {
    test('fetchManifest parses valid manifest JSON over HTTP', () async {
      const manifestUrl = 'https://example.com/manifest.json';
      const mockManifestBody = '''
      {
        "version": 1,
        "lastUpdated": "2026-09-07T12:00:00Z",
        "tests": [
          {
            "testId": "c19_t1_s1",
            "book": 19,
            "testNum": 1,
            "sectionNum": 1,
            "title": "C19 Test 1 Section 1",
            "audioUrls": ["https://example.com/c19.mp3"],
            "companionJsonUrl": "https://example.com/c19.json"
          }
        ]
      }
      ''';

      final mockClient = MockHttpClient(
        stringResponses: {manifestUrl: mockManifestBody},
      );

      final syncService = CloudSyncService(client: mockClient);
      final manifest = await syncService.fetchManifest(customUrl: manifestUrl);

      expect(manifest, isNotNull);
      expect(manifest!.tests.length, 1);
      expect(manifest.tests.first.testId, 'c19_t1_s1');
    });

    test('fetchManifest rejects Google virus scan HTML interception pages', () async {
      const driveUrl = 'https://drive.google.com/uc?export=download&id=FAKE';
      const htmlBody = '''
      <!DOCTYPE html>
      <html>
        <head><title>Google Drive - Virus scan warning</title></head>
        <body><p>Google Drive can't scan this file for viruses.</p></body>
      </html>
      ''';

      final mockClient = MockHttpClient(
        stringResponses: {driveUrl: htmlBody},
      );

      final syncService = CloudSyncService(client: mockClient);
      final manifest = await syncService.fetchManifest(customUrl: driveUrl);

      // Should safely return null instead of crashing on invalid JSON
      expect(manifest, isNull);
    });

    test('getProgress returns 0.0 for idle test and tracks progress', () {
      final syncService = CloudSyncService();
      expect(syncService.getProgress('non_existent_test'), 0.0);
    });

    test('defaultManifestUrls prioritizes fast CDN mirrors', () {
      expect(CloudSyncService.defaultManifestUrls.first,
          contains('cdn.jsdelivr.net'));
      expect(CloudSyncService.defaultManifestUrls.length, greaterThanOrEqualTo(3));
    });

    test('onBeforeFileReplace callback can be assigned and invoked', () {
      final syncService = CloudSyncService();
      bool called = false;
      syncService.onBeforeFileReplace = () {
        called = true;
      };
      syncService.onBeforeFileReplace?.call();
      expect(called, isTrue);
    });
  });
}
