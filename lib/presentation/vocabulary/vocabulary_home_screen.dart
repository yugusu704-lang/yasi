import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/models/word_item.dart';
import '../../domain/fsrs/fsrs_card.dart';
import '../providers/app_providers.dart';

class VocabularyHomeScreen extends ConsumerStatefulWidget {
  const VocabularyHomeScreen({super.key});

  @override
  ConsumerState<VocabularyHomeScreen> createState() =>
      _VocabularyHomeScreenState();
}

class _VocabularyHomeScreenState extends ConsumerState<VocabularyHomeScreen> {
  int _selectedTab = 0; // 0: FSRS复习, 1: 生词笔记本
  int _currentCardIndex = 0;
  bool _isCardFlipped = false;
  final FlutterTts _tts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _tts.setLanguage('en-GB');
    _tts.setSpeechRate(0.45);
  }

  Future<void> _speak(String word) async {
    await _tts.speak(word);
  }

  void _handleFsrsRating(
      WordItem word, FsrsRating rating, List<WordItem> dueWords) async {
    final db = ref.read(databaseProvider);
    final fsrs = ref.read(fsrsAlgorithmProvider);

    final currentCard =
        await db.getFsrsCard(word.id) ?? FsrsCard.newCard(word.id);
    final updatedCard = fsrs.review(currentCard, rating);
    await db.saveFsrsCard(updatedCard);

    setState(() {
      _isCardFlipped = false;
      if (_currentCardIndex < dueWords.length - 1) {
        _currentCardIndex++;
      } else {
        _currentCardIndex = dueWords.length; // Finished
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final wordsAsync = ref.watch(vocabularyListProvider);

    return Scaffold(
      backgroundColor: AppColors.paperBackground,
      appBar: AppBar(
        backgroundColor: AppColors.paperBackground,
        elevation: 0,
        title: const Text(
          '雅思核心词汇',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
            fontFamily: 'serif',
          ),
        ),
      ),
      body: Column(
        children: [
          // 分段切换器（FSRS 卡片 vs 生词本）
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTab = 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _selectedTab == 0
                            ? AppColors.ieltsCrimson
                            : AppColors.paperSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _selectedTab == 0
                              ? AppColors.ieltsCrimson
                              : AppColors.borderLight,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'FSRS 记忆卡片',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: _selectedTab == 0
                              ? Colors.white
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTab = 1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _selectedTab == 1
                            ? AppColors.ieltsCrimson
                            : AppColors.paperSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _selectedTab == 1
                              ? AppColors.ieltsCrimson
                              : AppColors.borderLight,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '精听生词本',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: _selectedTab == 1
                              ? Colors.white
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // 主视图
          Expanded(
            child: _selectedTab == 0
                ? _buildFsrsTab(wordsAsync)
                : _buildNotebookTab(wordsAsync),
          ),
        ],
      ),
    );
  }

  Widget _buildFsrsTab(AsyncValue<List<WordItem>> wordsAsync) {
    return wordsAsync.when(
      data: (words) {
        if (words.isEmpty) {
          return const Center(child: Text('暂无词汇，可从精听工作台中点击添加'));
        }

        if (_currentCardIndex >= words.length) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.stars_rounded,
                    size: 64, color: AppColors.fsrsGood),
                const SizedBox(height: 16),
                const Text(
                  '今日 FSRS 复习任务已全部完成！',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '科学间隔算法已更新下次记忆周期',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 24),
                MiuixButton(
                  onPressed: () => setState(() {
                    _currentCardIndex = 0;
                    _isCardFlipped = false;
                  }),
                  colors: MiuixButtonDefaults.buttonColorsPrimary(context),
                  child: const Text('再过一遍'),
                ),
              ],
            ),
          );
        }

        final currentWord = words[_currentCardIndex];

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            children: [
              // 进度条与指标
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '待复习进度: ${_currentCardIndex + 1} / ${words.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.ieltsCrimson.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      currentWord.ieltsTag,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.ieltsCrimson,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 记忆翻转卡片
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _isCardFlipped = !_isCardFlipped);
                    _speak(currentWord.word);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.cardSurface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.borderLight),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          currentWord.word,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'serif',
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              currentWord.phoneticUk,
                              style: const TextStyle(
                                fontSize: 16,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.volume_up_rounded,
                                  color: AppColors.ieltsCrimson, size: 20),
                              onPressed: () => _speak(currentWord.word),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // 背面释义与真题语境
                        if (_isCardFlipped) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.paperSurface,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              currentWord.definitionZh,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          if (currentWord.contextSentenceEn.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Text(
                              '"${currentWord.contextSentenceEn}"',
                              style: const TextStyle(
                                fontSize: 13,
                                fontStyle: FontStyle.italic,
                                color: AppColors.textSecondary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ] else ...[
                          const SizedBox(height: 40),
                          const Text(
                            '轻触卡片翻看释义与语境例句',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // FSRS 4 档反馈按钮
              Row(
                children: [
                  _buildFsrsButton('忘记', AppColors.fsrsAgain, () {
                    _handleFsrsRating(
                        currentWord, FsrsRating.again, words);
                  }),
                  const SizedBox(width: 8),
                  _buildFsrsButton('困难', AppColors.fsrsHard, () {
                    _handleFsrsRating(
                        currentWord, FsrsRating.hard, words);
                  }),
                  const SizedBox(width: 8),
                  _buildFsrsButton('良好', AppColors.fsrsGood, () {
                    _handleFsrsRating(
                        currentWord, FsrsRating.good, words);
                  }),
                  const SizedBox(width: 8),
                  _buildFsrsButton('简单', AppColors.fsrsEasy, () {
                    _handleFsrsRating(
                        currentWord, FsrsRating.easy, words);
                  }),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.ieltsCrimson),
      ),
      error: (err, _) => Center(child: Text('加载失败: $err')),
    );
  }

  Widget _buildFsrsButton(String label, Color color, VoidCallback onTap) {
    return Expanded(
      child: SizedBox(
        height: 46,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: color.withValues(alpha: 0.12),
            foregroundColor: color,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: color.withValues(alpha: 0.4)),
            ),
          ),
          onPressed: onTap,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotebookTab(AsyncValue<List<WordItem>> wordsAsync) {
    return wordsAsync.when(
      data: (words) => ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: words.length,
        itemBuilder: (context, index) {
          final word = words[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: MiuixCard(
              cornerRadius: 14,
              child: Material(
                color: Colors.transparent,
                child: ListTile(
                  title: Text(
                    word.word,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'serif',
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        word.phoneticUk,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        word.definitionZh,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.volume_up_rounded,
                            color: AppColors.oxfordNavy, size: 20),
                        onPressed: () => _speak(word.word),
                      ),
                      IconButton(
                        icon: Icon(
                          word.isFavorite
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          color: word.isFavorite
                              ? AppColors.ieltsCrimson
                              : AppColors.textMuted,
                          size: 20,
                        ),
                        onPressed: () {
                          ref
                              .read(vocabularyListProvider.notifier)
                              .toggleFavorite(word.id);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.ieltsCrimson),
      ),
      error: (err, _) => Center(child: Text('加载失败: $err')),
    );
  }
}
