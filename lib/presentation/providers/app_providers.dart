import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/local/app_database.dart';
import '../../domain/models/word_item.dart';
import '../../domain/models/listening_test_info.dart';
import '../../domain/models/study_stats.dart';
import '../../domain/models/cloud_manifest.dart';
import '../../domain/audio/audio_player_service.dart';
import '../../domain/fsrs/fsrs_algorithm.dart';
import '../../domain/fsrs/fsrs_card.dart';
import '../../data/remote/audio_cache_service.dart';
import '../../data/remote/cloud_sync_service.dart';
import '../../data/remote/google_drive_mobile_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase.instance;
});

final fsrsAlgorithmProvider = Provider<FsrsAlgorithm>((ref) {
  return FsrsAlgorithm();
});

final Provider<AudioPlayerService> audioPlayerServiceProvider =
    Provider<AudioPlayerService>((ref) {
  final service = AudioPlayerService();
  final db = ref.read(databaseProvider);

  service.onPlayStarted = () {
    ref.read(audioCacheServiceProvider).stop();
  };

  service.onListeningTimeAccumulated = (seconds) async {
    await db.recordListeningTime(seconds);
    ref.invalidate(todayListeningStatsProvider);
    ref.invalidate(overallPrepStatsProvider);
  };

  service.onSentenceRepeated = () async {
    await db.recordSentenceRepeat();
    ref.invalidate(todayListeningStatsProvider);
  };

  ref.onDispose(() => service.dispose());
  return service;
});

final Provider<AudioCacheService> audioCacheServiceProvider =
    Provider<AudioCacheService>((ref) {
  final service = AudioCacheService();
  service.onAudioPlaybackStarting = () {
    ref.read(audioPlayerServiceProvider).pause();
  };
  ref.onDispose(() => service.dispose());
  return service;
});

// 词汇列表 Provider (Riverpod 3 AsyncNotifier)
class VocabularyNotifier extends AsyncNotifier<List<WordItem>> {
  @override
  Future<List<WordItem>> build() async {
    final db = ref.read(databaseProvider);
    return await db.getAllWords();
  }

  Future<void> addWord(WordItem word) async {
    final db = ref.read(databaseProvider);
    await db.insertOrUpdateWord(word);
    state = AsyncData(await db.getAllWords());
  }

  Future<void> toggleFavorite(String id) async {
    final db = ref.read(databaseProvider);
    await db.toggleFavorite(id);
    state = AsyncData(await db.getAllWords());
  }
}

final vocabularyListProvider =
    AsyncNotifierProvider<VocabularyNotifier, List<WordItem>>(
        VocabularyNotifier.new);

// 待复习卡片 Provider
final dueCardsProvider = FutureProvider<List<WordItem>>((ref) async {
  final wordsAsync = ref.watch(vocabularyListProvider);
  final db = ref.watch(databaseProvider);

  return wordsAsync.maybeWhen(
    data: (words) async {
      final now = DateTime.now();
      final dueWords = <WordItem>[];
      for (final w in words) {
        final card = await db.getFsrsCard(w.id);
        if (card == null ||
            card.nextDue.isBefore(now) ||
            card.state == FsrsState.newCard) {
          dueWords.add(w);
        }
      }
      return dueWords;
    },
    orElse: () => [],
  );
});

// 听力真题列表 Provider
final listeningTestsProvider =
    FutureProvider<List<ListeningTestInfo>>((ref) async {
  final db = ref.watch(databaseProvider);
  return await db.getAllTests();
});

/// 当前选中的书籍筛选标签 (例如 '全部', '剑19', '剑18', ...)
class SelectedBookFilterNotifier extends Notifier<String> {
  @override
  String build() => '全部';

  void setFilter(String filter) => state = filter;
}

final selectedBookFilterProvider =
    NotifierProvider<SelectedBookFilterNotifier, String>(
        SelectedBookFilterNotifier.new);

/// 动态提取真题库中所有已收录的书籍列表，按编号降序排布
final availableBooksProvider = Provider<List<String>>((ref) {
  final testsAsync = ref.watch(listeningTestsProvider);
  final tests = testsAsync.value ?? [];
  final bookSet = <String>{};
  for (final t in tests) {
    if (t.book.isNotEmpty) {
      bookSet.add(t.book);
    }
  }

  final sortedBooks = bookSet.toList()
    ..sort((a, b) {
      final numA =
          int.tryParse(RegExp(r'\d+').firstMatch(a)?.group(0) ?? '') ?? 0;
      final numB =
          int.tryParse(RegExp(r'\d+').firstMatch(b)?.group(0) ?? '') ?? 0;
      return numB.compareTo(numA);
    });

  return ['全部', ...sortedBooks];
});

/// 根据书籍筛选标签过滤后的真题列表
final filteredListeningTestsProvider =
    FutureProvider<List<ListeningTestInfo>>((ref) async {
  final tests = await ref.watch(listeningTestsProvider.future);
  final filter = ref.watch(selectedBookFilterProvider);

  if (filter == '全部') {
    return tests;
  }

  final filterNum = RegExp(r'\d+').firstMatch(filter)?.group(0);
  if (filterNum != null) {
    return tests.where((t) {
      final tNum = RegExp(r'\d+').firstMatch(t.book)?.group(0);
      return tNum == filterNum || t.testId.startsWith('c${filterNum}_');
    }).toList();
  }

  return tests.where((t) => t.book == filter).toList();
});

// 当前正在练习的真题
class CurrentActiveTestNotifier extends Notifier<ListeningTestInfo?> {
  @override
  ListeningTestInfo? build() => null;

  void setTest(ListeningTestInfo? test) => state = test;
}

final currentActiveTestProvider =
    NotifierProvider<CurrentActiveTestNotifier, ListeningTestInfo?>(
        CurrentActiveTestNotifier.new);

// 谷歌云盘移动端服务 Provider
final googleDriveMobileServiceProvider =
    Provider<GoogleDriveMobileService>((ref) {
  return GoogleDriveMobileService();
});

// 谷歌云盘同步状态 Provider
class GoogleDriveState {
  final bool isConnected;
  final String accountEmail;
  final String displayName;
  final String? photoUrl;
  final bool isSyncing;
  final String lastSyncTime;
  final bool autoSyncEnabled;
  final String? statusMessage;
  final String? errorMessage;

  const GoogleDriveState({
    this.isConnected = false,
    this.accountEmail = '',
    this.displayName = '',
    this.photoUrl,
    this.isSyncing = false,
    this.lastSyncTime = '未同步',
    this.autoSyncEnabled = false,
    this.statusMessage,
    this.errorMessage,
  });

  GoogleDriveState copyWith({
    bool? isConnected,
    String? accountEmail,
    String? displayName,
    String? photoUrl,
    bool? isSyncing,
    String? lastSyncTime,
    bool? autoSyncEnabled,
    String? statusMessage,
    String? errorMessage,
  }) {
    return GoogleDriveState(
      isConnected: isConnected ?? this.isConnected,
      accountEmail: accountEmail ?? this.accountEmail,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      isSyncing: isSyncing ?? this.isSyncing,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      autoSyncEnabled: autoSyncEnabled ?? this.autoSyncEnabled,
      statusMessage: statusMessage,
      errorMessage: errorMessage,
    );
  }
}

class GoogleDriveNotifier extends Notifier<GoogleDriveState> {
  late final GoogleDriveMobileService _mobileService;

  @override
  GoogleDriveState build() {
    _mobileService = ref.watch(googleDriveMobileServiceProvider);
    _restoreSavedState();
    return const GoogleDriveState();
  }

  Future<void> _restoreSavedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final autoSync =
          prefs.getBool(GoogleDriveMobileService.prefAutoSyncKey) ?? false;
      final account = await _mobileService.initialize();
      if (account != null) {
        state = state.copyWith(
          isConnected: true,
          accountEmail: account.email,
          displayName: account.displayName ?? '',
          photoUrl: account.photoUrl,
          autoSyncEnabled: autoSync,
        );
      } else {
        state = state.copyWith(autoSyncEnabled: autoSync);
      }
    } catch (_) {}
  }

  /// 切换云端自动同步状态 (护栏 5: 软断开，不销毁 Token)
  Future<void> toggleAutoSync(bool enabled) async {
    if (!state.isConnected && enabled) {
      await connectGoogleDrive();
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(GoogleDriveMobileService.prefAutoSyncKey, enabled);
    state = state.copyWith(autoSyncEnabled: enabled);
  }

  /// 唤起 Google 授权登录流程 (护栏 1: GMS 异常防护与拦截)
  Future<void> connectGoogleDrive() async {
    state = state.copyWith(
      isSyncing: true,
      statusMessage: '正在调起 Google 授权...',
      errorMessage: null,
    );
    try {
      final account = await _mobileService.authenticate();
      if (account != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(GoogleDriveMobileService.prefAutoSyncKey, true);

        state = state.copyWith(
          isConnected: true,
          accountEmail: account.email,
          displayName: account.displayName ?? '',
          photoUrl: account.photoUrl,
          isSyncing: false,
          autoSyncEnabled: true,
          statusMessage: 'Google Drive 已成功连接',
          lastSyncTime: '刚刚',
        );

        // 成功连接后自动验证云盘根目录并同步真题清单
        await syncNow();
      } else {
        state = state.copyWith(isSyncing: false, statusMessage: null);
      }
    } catch (e) {
      String errStr = e.toString();
      if (errStr.contains('12500') || errStr.contains('SERVICE_MISSING')) {
        errStr = '当前设备未安装或禁用了 Google Play 服务框架，请检查系统 GMS 设置。';
      } else if (errStr.contains('SocketException') ||
          errStr.contains('TimeoutException') ||
          errStr.contains('NetworkImageLoadException')) {
        errStr = '连接 Google 服务器超时，请确保已开启科学上网网络环境。';
      } else if (errStr.contains('canceled') || errStr.contains('CANCELED')) {
        errStr = '用户取消了授权。';
      }
      state = state.copyWith(
        isSyncing: false,
        statusMessage: null,
        errorMessage: errStr,
      );
    }
  }

  /// 一键全量导出备考数据并执行原子双版本滚动备份 (护栏 3)
  Future<bool> backupDataNow() async {
    if (!state.isConnected) {
      await connectGoogleDrive();
      if (!state.isConnected) return false;
    }

    state = state.copyWith(
      isSyncing: true,
      statusMessage: '正在打包本地备考档案与生词...',
      errorMessage: null,
    );
    try {
      final db = ref.read(databaseProvider);
      final backupData = await db.exportFullBackupData();

      state = state.copyWith(statusMessage: '正在上传云端双版本滚动备份...');
      final success = await _mobileService.uploadRollingBackup(backupData);

      state = state.copyWith(
        isSyncing: false,
        statusMessage: success ? '备考档案已成功备份至 Google Drive！' : '备份失败',
        lastSyncTime: '刚刚',
      );
      return success;
    } catch (e) {
      state = state.copyWith(
        isSyncing: false,
        statusMessage: null,
        errorMessage: '备份失败: $e',
      );
      return false;
    }
  }

  /// 增量拉取音频与试卷清单
  Future<void> syncNow() async {
    state = state.copyWith(
      isSyncing: true,
      statusMessage: '正在同步真题清单与云端音频...',
      errorMessage: null,
    );
    try {
      final syncService = ref.read(cloudSyncServiceProvider);
      final manifest = await syncService.fetchManifest();
      if (manifest != null) {
        await syncService.syncManifestToDatabase(manifest);
        ref.invalidate(listeningTestsProvider);
      }

      // 如果已授权，额外检索用户云盘专属目录下的自定义音频
      if (state.isConnected) {
        await _mobileService.listRemoteAudioAssets();
      }

      state = state.copyWith(
        isSyncing: false,
        statusMessage: '云端清单已同步最新状态',
        lastSyncTime: '刚刚',
      );
    } catch (e) {
      state = state.copyWith(
        isSyncing: false,
        statusMessage: null,
        errorMessage: '同步发生异常: $e',
      );
    }
  }

  /// 彻底解除绑定并清除凭据 (护栏 5)
  Future<void> disconnect() async {
    state = state.copyWith(isSyncing: true);
    await _mobileService.signOut();
    state = const GoogleDriveState();
  }
}

final googleDriveProvider =
    NotifierProvider<GoogleDriveNotifier, GoogleDriveState>(
        GoogleDriveNotifier.new);

// 云端题库同步服务 Provider
final cloudSyncServiceProvider = Provider<CloudSyncService>((ref) {
  final db = ref.watch(databaseProvider);
  final service = CloudSyncService(db: db);
  service.onBeforeFileReplace = () {
    try {
      ref.read(audioPlayerServiceProvider).stop();
    } catch (_) {}
  };
  ref.onDispose(() => service.dispose());
  return service;
});

// 云端清单 Provider
final cloudManifestProvider = FutureProvider<CloudManifest?>((ref) async {
  final syncService = ref.watch(cloudSyncServiceProvider);
  return await syncService.fetchManifest();
});

// 单题下载进度流 Provider
final syncProgressStreamProvider =
    StreamProvider<CloudSyncProgress>((ref) {
  final syncService = ref.watch(cloudSyncServiceProvider);
  return syncService.progressStream;
});

// 单题独立进度监听 Provider
final singleTestProgressProvider =
    Provider.family<double, String>((ref, testId) {
  final currentProgress = ref.watch(syncProgressStreamProvider).value;
  if (currentProgress != null &&
      currentProgress.testId == testId &&
      !currentProgress.isCompleted &&
      currentProgress.error == null) {
    return currentProgress.progress;
  }
  final syncService = ref.watch(cloudSyncServiceProvider);
  return syncService.getProgress(testId);
});

// 学习统计数据 Providers
final todayListeningStatsProvider =
    FutureProvider<TodayListeningStats>((ref) async {
  final db = ref.watch(databaseProvider);
  return await db.getTodayListeningStats();
});

final overallPrepStatsProvider =
    FutureProvider<OverallPrepStats>((ref) async {
  final db = ref.watch(databaseProvider);
  return await db.getOverallPrepStats();
});
