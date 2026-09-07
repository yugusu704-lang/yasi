import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:ielts_prep/data/remote/google_drive_mobile_service.dart';

class MockStreamClient extends http.BaseClient {
  http.BaseRequest? lastRequest;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    lastRequest = request;
    return http.StreamedResponse(
      Stream.value(utf8.encode('{"files":[]}')),
      200,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GoogleDriveMobileService & AuthClient Unit Tests', () {
    test('GoogleAuthClient attaches Bearer token to request headers', () async {
      const testToken = 'ya29.sample_test_token_12345';
      final authClient = GoogleAuthClient(() async {
        return {'Authorization': 'Bearer $testToken'};
      });

      final req = http.Request('GET', Uri.parse('https://example.com/api/test'));
      // Intercept via custom client
      await authClient.send(req);

      expect(req.headers['Authorization'], equals('Bearer $testToken'));
    });

    test('GoogleAuthClient handles null headers gracefully without throwing', () async {
      final authClient = GoogleAuthClient(() async => null);
      final req = http.Request('GET', Uri.parse('https://example.com/api/test'));

      await authClient.send(req);
      expect(req.headers.containsKey('Authorization'), isFalse);
    });

    test('GoogleDriveMobileService defines scoped drive.file permission and folder', () {
      expect(GoogleDriveMobileService.driveScope, equals(drive.DriveApi.driveFileScope));
      expect(GoogleDriveMobileService.driveScope, equals('https://www.googleapis.com/auth/drive.file'));
      expect(GoogleDriveMobileService.folderName, equals('IELTS_Prep_Library'));
    });
  });
}
