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

// 当前正在练习的真题
class CurrentActiveTestNotifier extends Notifier<ListeningTestInfo?> {
  @override
  ListeningTestInfo? build() => null;

  void setTest(ListeningTestInfo? test) => state = test;
}

final currentActiveTestProvider =
    NotifierProvider<CurrentActiveTestNotifier, ListeningTestInfo?>(
        CurrentActiveTestNotifier.new);

// 谷歌云盘同步状态 Provider
class GoogleDriveState {
  final bool isConnected;
  final String accountEmail;
  final bool isSyncing;
  final String lastSyncTime;

  const GoogleDriveState({
    this.isConnected = false,
    this.accountEmail = '',
    this.isSyncing = false,
    this.lastSyncTime = '未同步',
  });

  GoogleDriveState copyWith({
    bool? isConnected,
    String? accountEmail,
    bool? isSyncing,
    String? lastSyncTime,
  }) {
    return GoogleDriveState(
      isConnected: isConnected ?? this.isConnected,
      accountEmail: accountEmail ?? this.accountEmail,
      isSyncing: isSyncing ?? this.isSyncing,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
    );
  }
}

class GoogleDriveNotifier extends Notifier<GoogleDriveState> {
  @override
  GoogleDriveState build() => const GoogleDriveState();

  Future<void> connectGoogleDrive() async {
    state = state.copyWith(isSyncing: true);
    await Future.delayed(const Duration(milliseconds: 800));
    state = state.copyWith(
      isConnected: true,
      accountEmail: 'ielts_candidate@gmail.com',
      isSyncing: false,
      lastSyncTime: '刚刚',
    );
  }

  Future<void> syncNow() async {
    state = state.copyWith(isSyncing: true);
    try {
      final syncService = ref.read(cloudSyncServiceProvider);
      final manifest = await syncService.fetchManifest();
      if (manifest != null) {
        await syncService.syncManifestToDatabase(manifest);
        ref.invalidate(listeningTestsProvider);
      }
    } catch (_) {}
    state = state.copyWith(isSyncing: false, lastSyncTime: '刚刚');
  }

  void disconnect() {
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
