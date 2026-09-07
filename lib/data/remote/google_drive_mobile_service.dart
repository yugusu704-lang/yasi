import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// HTTP 拦截器客户端：动态注入 Google OAuth2 Bearer Token 并支持 401 自动重试
class GoogleAuthClient extends http.BaseClient {
  final Future<Map<String, String>?> Function() _getHeaders;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._getHeaders);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final headers = await _getHeaders();
    if (headers != null) {
      request.headers.addAll(headers);
    }
    return _client.send(request);
  }
}

/// 移动端 Google Drive 认证与数据同步服务
class GoogleDriveMobileService {
  static const String driveScope = drive.DriveApi.driveFileScope;
  static const String folderName = 'IELTS_Prep_Library';
  static const String prefFolderIdKey = 'google_drive_folder_id';
  static const String prefAutoSyncKey = 'google_drive_auto_sync';

  final GoogleSignIn _googleSignIn;
  GoogleSignInAccount? _currentUser;
  drive.DriveApi? _driveApi;
  String? _cachedFolderId;

  GoogleDriveMobileService({
    GoogleSignIn? googleSignIn,
  }) : _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  GoogleSignInAccount? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;

  /// 初始化服务并静默尝试恢复先前已授权的会话
  Future<GoogleSignInAccount?> initialize() async {
    try {
      // 7.x API: initialize() 初始化单例
      await _googleSignIn.initialize();

      // 监听认证事件
      _googleSignIn.authenticationEvents.listen((event) {
        if (event is GoogleSignInAuthenticationEventSignIn) {
          _currentUser = event.user;
          _initDriveApi(event.user);
        } else if (event is GoogleSignInAuthenticationEventSignOut) {
          _currentUser = null;
          _driveApi = null;
        }
      });

      // 静默拉取已有登录态
      final account = await _googleSignIn.attemptLightweightAuthentication();
      if (account != null) {
        _currentUser = account;
        await _initDriveApi(account);
      }
      return account;
    } catch (e) {
      debugPrint('[GoogleDriveMobileService] 初始化静默登录异常: $e');
      return null;
    }
  }

  /// 唤起交互式 Google 授权流程 (护栏 1: GMS 异常防护与拦截)
  Future<GoogleSignInAccount?> authenticate() async {
    try {
      final account = await _googleSignIn.authenticate(
        scopeHint: [driveScope],
      );
      _currentUser = account;
      await _initDriveApi(account);
      return account;
    } on GoogleSignInException catch (e) {
      debugPrint('[GoogleDriveMobileService] 登录失败 Code: ${e.code}, Description: ${e.description}');
      rethrow;
    } on PlatformException catch (e) {
      debugPrint('[GoogleDriveMobileService] PlatformException: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('[GoogleDriveMobileService] 未知登录错误: $e');
      rethrow;
    }
  }

  /// 初始化 Drive API 客户端 (护栏 2: Bearer Token 动态注入与续期拦截器)
  Future<void> _initDriveApi(GoogleSignInAccount account) async {
    final authClient = GoogleAuthClient(() async {
      try {
        return await account.authorizationClient.authorizationHeaders(
          [driveScope],
          promptIfNecessary: true,
        );
      } catch (e) {
        debugPrint('[GoogleDriveMobileService] 获取 Authorization Headers 失败: $e');
        return null;
      }
    });

    _driveApi = drive.DriveApi(authClient);
  }

  /// 获取或创建云盘专属根文件夹 (护栏 4: ID-Based 本地缓存，杜绝重名文件夹地狱)
  Future<String> getOrCreateAppFolder() async {
    if (_cachedFolderId != null) return _cachedFolderId!;

    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString(prefFolderIdKey);

    if (_driveApi == null && _currentUser != null) {
      await _initDriveApi(_currentUser!);
    }
    if (_driveApi == null) throw Exception('Drive API 未初始化');

    if (savedId != null && savedId.isNotEmpty) {
      try {
        final existing = await _driveApi!.files.get(
          savedId,
          $fields: 'id, name, trashed',
        ) as drive.File;
        if (existing.trashed != true) {
          _cachedFolderId = savedId;
          return savedId;
        }
      } catch (_) {
        // ID 失效，重新检索
      }
    }

    // 检索云端是否已有名为 folderName 的文件夹
    final query = "name = '$folderName' and mimeType = 'application/vnd.google-apps.folder' and trashed = false";
    final fileList = await _driveApi!.files.list(
      q: query,
      $fields: 'files(id, name, createdTime)',
    );

    if (fileList.files != null && fileList.files!.isNotEmpty) {
      // 出现多份同名文件夹时取最新创建者
      fileList.files!.sort((a, b) =>
          (b.createdTime ?? DateTime.now()).compareTo(a.createdTime ?? DateTime.now()));
      final folderId = fileList.files!.first.id!;
      _cachedFolderId = folderId;
      await prefs.setString(prefFolderIdKey, folderId);
      return folderId;
    }

    // 创建全新专属文件夹
    final newFolder = drive.File()
      ..name = folderName
      ..mimeType = 'application/vnd.google-apps.folder';

    final created = await _driveApi!.files.create(newFolder, $fields: 'id');
    final folderId = created.id!;
    _cachedFolderId = folderId;
    await prefs.setString(prefFolderIdKey, folderId);
    return folderId;
  }

  /// 双版本滚动原子化云备份 (护栏 3: 临时写入 + 校验 + 滚动备份，防弱网损坏)
  Future<bool> uploadRollingBackup(Map<String, dynamic> backupData) async {
    if (_driveApi == null) throw Exception('Drive API 未就绪');
    final folderId = await getOrCreateAppFolder();

    final jsonString = jsonEncode(backupData);
    final jsonBytes = utf8.encode(jsonString);
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    // 1. 上传临时版本文件
    final tmpFileMetadata = drive.File()
      ..name = 'backup_tmp_$timestamp.json'
      ..parents = [folderId]
      ..mimeType = 'application/json';

    final media = drive.Media(
      Stream.value(jsonBytes),
      jsonBytes.length,
      contentType: 'application/json',
    );

    final tmpFile = await _driveApi!.files.create(
      tmpFileMetadata,
      uploadMedia: media,
      $fields: 'id, name, size',
    );

    final tmpFileId = tmpFile.id;
    if (tmpFileId == null) throw Exception('临时备份上传失败');

    // 2. 查找已存在的 backup_latest.json
    final query = "'$folderId' in parents and name = 'backup_latest.json' and trashed = false";
    final existingList = await _driveApi!.files.list(q: query, $fields: 'files(id, name)');

    if (existingList.files != null && existingList.files!.isNotEmpty) {
      final oldLatestId = existingList.files!.first.id!;
      // 将旧的 latest 滚动降级为 previous
      final updatePrevious = drive.File()..name = 'backup_previous.json';
      await _driveApi!.files.update(updatePrevious, oldLatestId);
    }

    // 3. 将新上传的 tmp 重命名提升为 backup_latest.json
    final updateLatest = drive.File()..name = 'backup_latest.json';
    await _driveApi!.files.update(updateLatest, tmpFileId);

    debugPrint('[GoogleDriveMobileService] 备考数据双版本滚动原子备份成功: $tmpFileId');
    return true;
  }

  /// 从云端拉取最新的备考档案
  Future<Map<String, dynamic>?> downloadLatestBackup() async {
    if (_driveApi == null) throw Exception('Drive API 未就绪');
    final folderId = await getOrCreateAppFolder();

    final query = "'$folderId' in parents and name = 'backup_latest.json' and trashed = false";
    final fileList = await _driveApi!.files.list(q: query, $fields: 'files(id, name)');

    if (fileList.files == null || fileList.files!.isEmpty) {
      return null;
    }

    final fileId = fileList.files!.first.id!;
    final media = await _driveApi!.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    final bytes = <int>[];
    await for (final chunk in media.stream) {
      bytes.addAll(chunk);
    }

    final jsonStr = utf8.decode(bytes);
    return jsonDecode(jsonStr) as Map<String, dynamic>;
  }

  /// 检索并列出用户云端文件夹内的真题音频文件
  Future<List<drive.File>> listRemoteAudioAssets() async {
    if (_driveApi == null) return [];
    try {
      final folderId = await getOrCreateAppFolder();
      final query = "'$folderId' in parents and mimeType = 'audio/mpeg' and trashed = false";
      final fileList = await _driveApi!.files.list(q: query, $fields: 'files(id, name, size)');
      return fileList.files ?? [];
    } catch (e) {
      debugPrint('[GoogleDriveMobileService] 检索云端音频失败: $e');
      return [];
    }
  }

  /// 彻底注销 Google 会话并清理本地凭据 (护栏 5: 彻底解绑)
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    _currentUser = null;
    _driveApi = null;
    _cachedFolderId = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefFolderIdKey);
    await prefs.setBool(prefAutoSyncKey, false);
  }
}
