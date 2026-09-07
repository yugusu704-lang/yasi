import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}

class GoogleDriveService {
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  GoogleSignInAccount? _currentUser;
  drive.DriveApi? _driveApi;

  bool get isSignedIn => _currentUser != null;
  String? get userEmail => _currentUser?.email;

  Future<bool> signIn() async {
    try {
      await _googleSignIn.initialize();
      _currentUser = await _googleSignIn.authenticate();

      final auth = await _currentUser!.authorizationClient.authorizeScopes([
        drive.DriveApi.driveFileScope,
        drive.DriveApi.driveReadonlyScope,
      ]);

      final authHeaders = {
        'Authorization': 'Bearer ${auth.accessToken}',
      };

      final authClient = GoogleAuthClient(authHeaders);
      _driveApi = drive.DriveApi(authClient);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentUser = null;
    _driveApi = null;
  }

  /// 搜索或创建工作区目录 "IELTS_Resources"
  Future<String?> getOrCreateAppFolder() async {
    if (_driveApi == null) return null;

    try {
      final fileList = await _driveApi!.files.list(
        q: "mimeType = 'application/vnd.google-apps.folder' and name = 'IELTS_Resources' and trashed = false",
        $fields: 'files(id, name)',
      );

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        return fileList.files!.first.id;
      }

      // 创建目录
      final folder = drive.File()
        ..name = 'IELTS_Resources'
        ..mimeType = 'application/vnd.google-apps.folder';

      final created = await _driveApi!.files.create(folder);
      return created.id;
    } catch (e) {
      return null;
    }
  }

  /// 备份学习记录至网盘
  Future<bool> backupStudyData(Map<String, dynamic> data) async {
    if (_driveApi == null) return false;

    try {
      final folderId = await getOrCreateAppFolder();
      final content = utf8.encode(jsonEncode(data));
      final media = drive.Media(
        Stream.value(content),
        content.length,
      );

      final fileMetadata = drive.File()
        ..name =
            'ielts_study_backup_${DateTime.now().toIso8601String().substring(0, 10)}.json'
        ..parents = folderId != null ? [folderId] : null;

      await _driveApi!.files.create(fileMetadata, uploadMedia: media);
      return true;
    } catch (e) {
      return false;
    }
  }
}
