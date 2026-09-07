import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../../domain/models/word_item.dart';
import '../../domain/models/listening_test_info.dart';
import '../../domain/models/subtitle_sentence.dart';
import '../../domain/fsrs/fsrs_card.dart';
import 'default_data.dart';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._internal();
  AppDatabase._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'ielts_prep_v1.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE vocabulary (
            id TEXT PRIMARY KEY,
            word TEXT NOT NULL,
            phonetic_uk TEXT,
            phonetic_us TEXT,
            definition_zh TEXT,
            ielts_tag TEXT,
            context_en TEXT,
            context_zh TEXT,
            source_test TEXT,
            is_favorite INTEGER DEFAULT 0,
            added_at TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE fsrs_cards (
            card_id TEXT PRIMARY KEY,
            stability REAL,
            difficulty REAL,
            elapsed_days INTEGER,
            scheduled_days INTEGER,
            reps INTEGER,
            lapses INTEGER,
            state INTEGER,
            last_review TEXT,
            next_due TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE listening_tests (
            test_id TEXT PRIMARY KEY,
            book TEXT,
            test_number INTEGER,
            section INTEGER,
            title TEXT,
            audio_url TEXT,
            local_audio_path TEXT,
            total_duration_ms INTEGER,
            is_downloaded INTEGER,
            play_count INTEGER,
            completion_rate REAL
          )
        ''');

        await db.execute('''
          CREATE TABLE sentence_subtitles (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            test_id TEXT,
            sentence_index INTEGER,
            start_ms INTEGER,
            end_ms INTEGER,
            text_en TEXT,
            text_zh TEXT,
            key_words TEXT
          )
        ''');

        // 初始填充默认种子数据
        await _seedInitialData(db);
      },
    );
  }

  Future<void> _seedInitialData(Database db) async {
    final batch = db.batch();

    for (final test in DefaultData.initialTests) {
      batch.insert('listening_tests', {
        'test_id': test.testId,
        'book': test.book,
        'test_number': test.testNumber,
        'section': test.section,
        'title': test.title,
        'audio_url': test.audioUrl,
        'local_audio_path': test.localAudioPath,
        'total_duration_ms': test.totalDurationMs,
        'is_downloaded': test.isDownloaded ? 1 : 0,
        'play_count': test.playCount,
        'completion_rate': test.completionRate,
      });

      for (final s in test.sentences) {
        batch.insert('sentence_subtitles', {
          'test_id': test.testId,
          'sentence_index': s.index,
          'start_ms': s.startMs,
          'end_ms': s.endMs,
          'text_en': s.textEn,
          'text_zh': s.textZh,
          'key_words': s.keyWords.join(','),
        });
      }
    }

    for (final word in DefaultData.initialVocabulary) {
      batch.insert('vocabulary', {
        'id': word.id,
        'word': word.word,
        'phonetic_uk': word.phoneticUk,
        'phonetic_us': word.phoneticUs,
        'definition_zh': word.definitionZh,
        'ielts_tag': word.ieltsTag,
        'context_en': word.contextSentenceEn,
        'context_zh': word.contextSentenceZh,
        'source_test': word.sourceTest,
        'is_favorite': word.isFavorite ? 1 : 0,
        'added_at': word.addedAt.toIso8601String(),
      });

      final card = FsrsCard.newCard(word.id);
      batch.insert('fsrs_cards', {
        'card_id': card.cardId,
        'stability': card.stability,
        'difficulty': card.difficulty,
        'elapsed_days': card.elapsedDays,
        'scheduled_days': card.scheduledDays,
        'reps': card.reps,
        'lapses': card.lapses,
        'state': card.state.value,
        'last_review': card.lastReview.toIso8601String(),
        'next_due': card.nextDue.toIso8601String(),
      });
    }

    await batch.commit(noResult: true);
  }

  // --- 单词管理 ---
  Future<List<WordItem>> getAllWords() async {
    final db = await database;
    final maps = await db.query('vocabulary', orderBy: 'added_at DESC');
    return maps.map((m) => _mapToWord(m)).toList();
  }

  Future<void> insertOrUpdateWord(WordItem word) async {
    final db = await database;
    await db.insert(
      'vocabulary',
      {
        'id': word.id,
        'word': word.word,
        'phonetic_uk': word.phoneticUk,
        'phonetic_us': word.phoneticUs,
        'definition_zh': word.definitionZh,
        'ielts_tag': word.ieltsTag,
        'context_en': word.contextSentenceEn,
        'context_zh': word.contextSentenceZh,
        'source_test': word.sourceTest,
        'is_favorite': word.isFavorite ? 1 : 0,
        'added_at': word.addedAt.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // 同步确保 FSRS 卡片存在
    final existingCard = await getFsrsCard(word.id);
    if (existingCard == null) {
      await saveFsrsCard(FsrsCard.newCard(word.id));
    }
  }

  Future<void> toggleFavorite(String id) async {
    final db = await database;
    await db.rawUpdate('''
      UPDATE vocabulary SET is_favorite = CASE WHEN is_favorite = 1 THEN 0 ELSE 1 END WHERE id = ?
    ''', [id]);
  }

  WordItem _mapToWord(Map<String, dynamic> m) {
    return WordItem(
      id: m['id'] as String,
      word: m['word'] as String,
      phoneticUk: m['phonetic_uk'] as String? ?? '',
      phoneticUs: m['phonetic_us'] as String? ?? '',
      definitionZh: m['definition_zh'] as String? ?? '',
      ieltsTag: m['ielts_tag'] as String? ?? '雅思核心',
      contextSentenceEn: m['context_en'] as String? ?? '',
      contextSentenceZh: m['context_zh'] as String? ?? '',
      sourceTest: m['source_test'] as String? ?? '',
      isFavorite: (m['is_favorite'] as int? ?? 0) == 1,
      addedAt: DateTime.tryParse(m['added_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  // --- FSRS 记忆卡片 ---
  Future<FsrsCard?> getFsrsCard(String cardId) async {
    final db = await database;
    final res = await db.query('fsrs_cards', where: 'card_id = ?', whereArgs: [cardId]);
    if (res.isEmpty) return null;
    final m = res.first;
    return FsrsCard(
      cardId: m['card_id'] as String,
      stability: (m['stability'] as num).toDouble(),
      difficulty: (m['difficulty'] as num).toDouble(),
      elapsedDays: m['elapsed_days'] as int,
      scheduledDays: m['scheduled_days'] as int,
      reps: m['reps'] as int,
      lapses: m['lapses'] as int,
      state: FsrsState.values.firstWhere(
        (s) => s.value == (m['state'] as int),
        orElse: () => FsrsState.newCard,
      ),
      lastReview: DateTime.parse(m['last_review'] as String),
      nextDue: DateTime.parse(m['next_due'] as String),
    );
  }

  Future<void> saveFsrsCard(FsrsCard card) async {
    final db = await database;
    await db.insert(
      'fsrs_cards',
      {
        'card_id': card.cardId,
        'stability': card.stability,
        'difficulty': card.difficulty,
        'elapsed_days': card.elapsedDays,
        'scheduled_days': card.scheduledDays,
        'reps': card.reps,
        'lapses': card.lapses,
        'state': card.state.value,
        'last_review': card.lastReview.toIso8601String(),
        'next_due': card.nextDue.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // --- 听力真题与字幕 ---
  Future<List<ListeningTestInfo>> getAllTests() async {
    final db = await database;
    final testMaps = await db.query('listening_tests');
    final tests = <ListeningTestInfo>[];

    for (final m in testMaps) {
      final testId = m['test_id'] as String;
      final subMaps = await db.query(
        'sentence_subtitles',
        where: 'test_id = ?',
        whereArgs: [testId],
        orderBy: 'sentence_index ASC',
      );

      final sentences = subMaps.map((s) {
        final kw = (s['key_words'] as String? ?? '')
            .split(',')
            .where((w) => w.isNotEmpty)
            .toList();
        return SubtitleSentence(
          index: s['sentence_index'] as int,
          startMs: s['start_ms'] as int,
          endMs: s['end_ms'] as int,
          textEn: s['text_en'] as String,
          textZh: s['text_zh'] as String,
          keyWords: kw,
        );
      }).toList();

      tests.add(ListeningTestInfo(
        testId: testId,
        book: m['book'] as String,
        testNumber: m['test_number'] as int,
        section: m['section'] as int,
        title: m['title'] as String,
        audioUrl: m['audio_url'] as String,
        localAudioPath: m['local_audio_path'] as String,
        totalDurationMs: m['total_duration_ms'] as int,
        isDownloaded: (m['is_downloaded'] as int) == 1,
        playCount: m['play_count'] as int,
        completionRate: (m['completion_rate'] as num).toDouble(),
        sentences: sentences,
      ));
    }

    return tests;
  }
}
