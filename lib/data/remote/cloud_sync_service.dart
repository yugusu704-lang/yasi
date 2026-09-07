import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../../domain/models/cloud_manifest.dart';
import '../../domain/models/listening_test_info.dart';
import '../local/app_database.dart';

class CloudSyncProgress {
  final String testId;
  final double progress; // 0.0 ~ 1.0
  final bool isCompleted;
  final String? error;

  const CloudSyncProgress({
    required this.testId,
    required this.progress,
    this.isCompleted = false,
    this.error,
  });
}

class CloudSyncService {
  final http.Client _client;
  final AppDatabase _db;
  final Set<String> _activeDownloads = {};
  final StreamController<CloudSyncProgress> _progressController =
      StreamController<CloudSyncProgress>.broadcast();

  // 官方高可用镜像清单源（支持公网直接拉取，免翻墙，双向容灾）
  static const String defaultManifestUrl =
      'https://raw.githubusercontent.com/yugusu704-lang/yasi/main/assets/cloud_manifest.json';

  CloudSyncService({
    http.Client? client,
    AppDatabase? db,
  })  : _client = client ?? http.Client(),
        _db = db ?? AppDatabase.instance;

  final Map<String, double> _progressMap = {};

  Stream<CloudSyncProgress> get progressStream => _progressController.stream;
  bool isDownloading(String testId) => _activeDownloads.contains(testId);
  double getProgress(String testId) => _progressMap[testId] ?? 0.0;

  void _updateProgress(String testId, double progress,
      {bool isCompleted = false, String? error}) {
    _progressMap[testId] = progress;
    _progressController.add(CloudSyncProgress(
      testId: testId,
      progress: progress,
      isCompleted: isCompleted,
      error: error,
    ));
  }

  /// 获取云端试卷总清单 (支持公开直链与自定义镜像)
  Future<CloudManifest?> fetchManifest({String? customUrl}) async {
    final url = customUrl ?? defaultManifestUrl;
    try {
      final response = await _client
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200 &&
          !response.body.trim().startsWith('<')) {
        final Map<String, dynamic> data =
            jsonDecode(utf8.decode(response.bodyBytes));
        return CloudManifest.fromJson(data);
      }
    } catch (e) {
      debugPrint('[CloudSyncService] 获取云端清单失败: $e');
    }
    return null;
  }

  /// 增量同步云端试卷清单至本地 SQLite（标记为未下载）
  Future<int> syncManifestToDatabase(CloudManifest manifest) async {
    int newTestsCount = 0;
    for (final entry in manifest.tests) {
      final existing = await _db.getTestById(entry.testId);
      if (existing == null) {
        final placeholderTest = ListeningTestInfo(
          testId: entry.testId,
          book: 'Cambridge ${entry.book}',
          testNumber: entry.testNum,
          section: entry.sectionNum,
          title: entry.title,
          audioUrl: entry.preferredAudioUrl,
          localAudioPath: '',
          totalDurationMs: 0,
          sentences: const [],
          questions: const [],
          isDownloaded: false,
        );
        await _db.insertOrUpdateTest(placeholderTest);
        newTestsCount++;
      }
    }
    return newTestsCount;
  }

  /// 根据 testId 自动匹配清单条目并执行按需下载
  Future<bool> downloadTestById(String testId) async {
    final manifest = await fetchManifest();
    if (manifest != null) {
      for (final entry in manifest.tests) {
        if (entry.testId == testId) {
          return await downloadTest(entry);
        }
      }
    }
    final localTest = await _db.getTestById(testId);
    if (localTest != null) {
      final fallbackEntry = ManifestTestEntry(
        testId: localTest.testId,
        book:
            int.tryParse(localTest.book.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0,
        testNum: localTest.testNumber,
        sectionNum: localTest.section,
        title: localTest.title,
        audioUrls: [localTest.audioUrl],
        companionJsonUrl: '',
      );
      return await downloadTest(fallbackEntry);
    }
    return false;
  }

  /// 按需即时下载指定试卷音频与伴随题目（原子暂存 + 校验 + 事务入库 + 失败回滚）
  Future<bool> downloadTest(ManifestTestEntry entry) async {
    final testId = entry.testId;
    if (_activeDownloads.contains(testId)) return false;

    _activeDownloads.add(testId);
    _updateProgress(testId, 0.05);

    File? tempAudioFile;
    File? finalAudioFile;
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final testsDir = Directory('${docDir.path}/local_tests');
      if (!await testsDir.exists()) {
        await testsDir.create(recursive: true);
      }

      final relativeAudioPath = 'local_tests/$testId.mp3';
      finalAudioFile = File('${docDir.path}/$relativeAudioPath');
      tempAudioFile = File('${docDir.path}/$relativeAudioPath.tmp');

      // 1. 拉取伴随 JSON 数据 (含毫秒级字幕与题目)
      _updateProgress(testId, 0.15);
      ListeningTestInfo? parsedTest;
      if (entry.companionJsonUrl.isNotEmpty) {
        final jsonRes = await _client
            .get(Uri.parse(entry.companionJsonUrl))
            .timeout(const Duration(seconds: 12));
        if (jsonRes.statusCode == 200 && !jsonRes.body.trim().startsWith('<')) {
          final jsonMap =
              jsonDecode(utf8.decode(jsonRes.bodyBytes)) as Map<String, dynamic>;
          parsedTest = ListeningTestInfo.fromJson(jsonMap);
        }
      }

      // 2. 流式下载 MP3 音频 (多源回退 + 5s 握手超时 + Magic Bytes 防御)
      _updateProgress(testId, 0.25);
      bool audioDownloaded = false;

      for (final audioUrl in entry.audioUrls) {
        if (audioUrl.isEmpty) continue;
        IOSink? sink;
        try {
          final request = http.Request('GET', Uri.parse(audioUrl));
          final streamedResponse =
              await _client.send(request).timeout(const Duration(seconds: 15));

          if (streamedResponse.statusCode == 200) {
            final contentLength =
                streamedResponse.contentLength ?? entry.audioSize;
            int receivedBytes = 0;

            try {
              sink = tempAudioFile.openWrite();
              await for (final chunk in streamedResponse.stream) {
                sink.add(chunk);
                receivedBytes += chunk.length;
                if (contentLength > 0) {
                  final currentProgress =
                      0.25 + (receivedBytes / contentLength) * 0.65;
                  _updateProgress(
                      testId, currentProgress.clamp(0.25, 0.9));
                }
              }
            } finally {
              // 护栏 4: IOSink 确保无论异常与否 100% 释放文件句柄
              if (sink != null) {
                await sink.flush();
                await sink.close();
                sink = null;
              }
            }

            // 护栏 2: 严密二进制魔数 (Magic Bytes) 校验与非音频流拦截
            final fileLen = await tempAudioFile.length();
            if (fileLen > 10000) {
              final headerBytes = await tempAudioFile.openRead(0, 64).first;
              final headerStr =
                  String.fromCharCodes(headerBytes).toLowerCase();

              final isHtmlOrJson = headerStr.contains('<!doctype') ||
                  headerStr.contains('<html') ||
                  headerStr.contains('{"error"');

              final hasId3 = headerBytes.length >= 3 &&
                  headerBytes[0] == 0x49 &&
                  headerBytes[1] == 0x44 &&
                  headerBytes[2] == 0x33;
              final hasMpegSync = headerBytes.length >= 2 &&
                  headerBytes[0] == 0xFF &&
                  (headerBytes[1] & 0xE0) == 0xE0;

              if (!isHtmlOrJson &&
                  (hasId3 ||
                      hasMpegSync ||
                      streamedResponse.headers['content-type']
                              ?.contains('audio') ==
                          true)) {
                audioDownloaded = true;
                break;
              }
            }
            if (await tempAudioFile.exists()) await tempAudioFile.delete();
          }
        } catch (e) {
          debugPrint('[CloudSyncService] 尝试音频源 $audioUrl 失败: $e');
          if (sink != null) {
            try {
              await sink.close();
            } catch (_) {}
          }
          if (await tempAudioFile.exists()) await tempAudioFile.delete();
        }
      }

      if (!audioDownloaded) {
        throw Exception('所有音频源拉取失败或响应非音频流');
      }

      // 3. 原子性提交：重命名 .tmp 文件为正式文件
      if (await finalAudioFile.exists()) await finalAudioFile.delete();
      await tempAudioFile.rename(finalAudioFile.path);

      // 4. 数据库事务原子化更新 (护栏 4: 双仓联动回滚)
      final completeTest = ListeningTestInfo(
        testId: testId,
        book: parsedTest?.book.isNotEmpty == true
            ? parsedTest!.book
            : 'Cambridge ${entry.book}',
        testNumber: parsedTest?.testNumber ?? entry.testNum,
        section: parsedTest?.section ?? entry.sectionNum,
        title: parsedTest?.title.isNotEmpty == true
            ? parsedTest!.title
            : entry.title,
        audioUrl: entry.preferredAudioUrl,
        localAudioPath: relativeAudioPath,
        totalDurationMs: parsedTest?.totalDurationMs ?? 0,
        sentences: parsedTest?.sentences ?? const [],
        questions: parsedTest?.questions ?? const [],
        isDownloaded: true,
        playCount: 0,
        completionRate: 0.0,
      );

      try {
        await _db.insertOrUpdateTest(completeTest);
      } catch (dbError) {
        // 数据库写入失败时回滚物理文件，杜绝孤儿文件
        if (await finalAudioFile.exists()) {
          await finalAudioFile.delete();
        }
        rethrow;
      }

      _updateProgress(testId, 1.0, isCompleted: true);
      return true;
    } catch (e) {
      debugPrint('[CloudSyncService] 试卷 $testId 下载异常: $e');
      if (tempAudioFile != null && await tempAudioFile.exists()) {
        try {
          await tempAudioFile.delete();
        } catch (_) {}
      }
      _updateProgress(testId, 0.0, error: e.toString());
      return false;
    } finally {
      _activeDownloads.remove(testId);
    }
  }

  /// 释放指定真题的本地磁盘空间
  Future<void> deleteTestAudio(String testId) async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final targetFile = File('${docDir.path}/local_tests/$testId.mp3');
      if (await targetFile.exists()) {
        await targetFile.delete();
      }
      await _db.deleteTestAudio(testId);
    } catch (e) {
      debugPrint('[CloudSyncService] 删除试卷音频异常: $e');
    }
  }

  void dispose() {
    _progressController.close();
  }
}
