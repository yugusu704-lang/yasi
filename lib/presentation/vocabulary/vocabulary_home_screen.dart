import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_miuix/miuix.dart';
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
  int _selectedTab = 0; // 0: FSRS卡片, 1: 听音拼写测试, 2: 生词笔记本
  int _currentCardIndex = 0;
  bool _isCardFlipped = false;
  bool _isBlindListeningMode = false; // 盲听辨义开关

  // 听音拼写测试状态
  int _spellingIndex = 0;
  final TextEditingController _spellingController = TextEditingController();
  bool _spellingChecked = false;
  bool _spellingCorrect = false;

  @override
  void dispose() {
    _spellingController.dispose();
    super.dispose();
  }

  void _playUkAudio(String word) {
    ref.read(audioCacheServiceProvider).playWordUk(word);
  }

  void _speakSentence(String sentence, {String? word}) {
    ref.read(audioCacheServiceProvider).speakSentence(sentence, word: word);
  }

  void _handleFsrsRating(
      WordItem word, FsrsRating rating, List<WordItem> words) async {
    final db = ref.read(databaseProvider);
    final fsrs = ref.read(fsrsAlgorithmProvider);

    final currentCard =
        await db.getFsrsCard(word.id) ?? FsrsCard.newCard(word.id);
    final updatedCard = fsrs.review(currentCard, rating);
    await db.saveFsrsCard(updatedCard);

    setState(() {
      _isCardFlipped = false;
      if (_currentCardIndex < words.length - 1) {
        _currentCardIndex++;
        if (_isBlindListeningMode) {
          _playUkAudio(words[_currentCardIndex].word);
        }
      } else {
        _currentCardIndex = words.length; // Finished
      }
    });
  }

  void _checkSpelling(WordItem word, List<WordItem> words) async {
    final input = _spellingController.text.trim().toLowerCase();
    final target = word.word.trim().toLowerCase();
    final isCorrect = input == target;

    setState(() {
      _spellingChecked = true;
      _spellingCorrect = isCorrect;
    });

    final db = ref.read(databaseProvider);
    final fsrs = ref.read(fsrsAlgorithmProvider);
    final currentCard =
        await db.getFsrsCard(word.id) ?? FsrsCard.newCard(word.id);
    final rating = isCorrect ? FsrsRating.good : FsrsRating.again;
    final updatedCard = fsrs.review(currentCard, rating);
    await db.saveFsrsCard(updatedCard);
  }

  void _nextSpellingWord(List<WordItem> words) {
    setState(() {
      _spellingChecked = false;
      _spellingCorrect = false;
      _spellingController.clear();
      if (_spellingIndex < words.length - 1) {
        _spellingIndex++;
        _playUkAudio(words[_spellingIndex].word);
      } else {
        _spellingIndex = words.length;
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
        actions: [
          if (_selectedTab == 0)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilterChip(
                label: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.hearing_rounded,
                        size: 14, color: AppColors.ieltsCrimson),
                    SizedBox(width: 4),
                    Text('盲听辨义', style: TextStyle(fontSize: 12)),
                  ],
                ),
                selected: _isBlindListeningMode,
                selectedColor: AppColors.ieltsCrimson.withValues(alpha: 0.15),
                checkmarkColor: AppColors.ieltsCrimson,
                onSelected: (val) {
                  setState(() {
                    _isBlindListeningMode = val;
                    _isCardFlipped = false;
                  });
                  if (val) {
                    wordsAsync.whenData((words) {
                      if (_currentCardIndex < words.length) {
                        _playUkAudio(words[_currentCardIndex].word);
                      }
                    });
                  }
                },
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // 顶部分段切换器（FSRS卡片 vs 听音拼写测试 vs 生词本）
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildSegmentButton(0, 'FSRS 记忆卡片'),
                const SizedBox(width: 8),
                _buildSegmentButton(1, '听音拼写测试'),
                const SizedBox(width: 8),
                _buildSegmentButton(2, '精听生词本'),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // 主视图
          Expanded(
            child: switch (_selectedTab) {
              0 => _buildFsrsTab(wordsAsync),
              1 => _buildSpellingTestTab(wordsAsync),
              _ => _buildNotebookTab(wordsAsync),
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentButton(int index, String title) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTab = index;
            if (index == 1) {
              _spellingChecked = false;
              _spellingController.clear();
            }
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color:
                isSelected ? AppColors.ieltsCrimson : AppColors.paperSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color:
                  isSelected ? AppColors.ieltsCrimson : AppColors.borderLight,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
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
                  '已同步至间隔重复记忆模型与发音库',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 24),
                MiuixButton(
                  onPressed: () => setState(() {
                    _currentCardIndex = 0;
                    _isCardFlipped = false;
                  }),
                  colors: MiuixButtonDefaults.buttonColorsPrimary(context),
                  child: const Text('重新过一遍'),
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
              // 进度条与标签
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
                    _playUkAudio(currentWord.word);
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
                        if (_isBlindListeningMode && !_isCardFlipped) ...[
                          // 盲听模式正面：隐藏文字，强化听音能力
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color:
                                  AppColors.ieltsCrimson.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.volume_up_rounded,
                                  size: 44, color: AppColors.ieltsCrimson),
                              onPressed: () => _playUkAudio(currentWord.word),
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            '🎧 盲听英音辨义',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                              fontFamily: 'serif',
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '在大脑中回忆拼写与中文释义\n轻触卡片查看答案',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ] else ...[
                          // 常规正面或翻转后的背面
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
                                    color: AppColors.ieltsCrimson, size: 22),
                                onPressed: () =>
                                    _playUkAudio(currentWord.word),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          if (_isCardFlipped) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
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
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.oxfordNavy,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  side: const BorderSide(
                                      color: AppColors.borderLight),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20)),
                                ),
                                onPressed: () => _speakSentence(
                                    currentWord.contextSentenceEn,
                                    word: currentWord.word),
                                icon: const Icon(Icons.play_arrow_rounded,
                                    size: 16),
                                label: const Text('原声语境例句朗读',
                                    style: TextStyle(fontSize: 11)),
                              ),
                            ],
                          ] else ...[
                            const SizedBox(height: 40),
                            const Text(
                              '轻触卡片翻看释义与真题例句',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
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

  Widget _buildSpellingTestTab(AsyncValue<List<WordItem>> wordsAsync) {
    return wordsAsync.when(
      data: (words) {
        if (words.isEmpty) {
          return const Center(child: Text('词库为空'));
        }

        if (_spellingIndex >= words.length) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.verified_rounded,
                    size: 64, color: AppColors.fsrsGood),
                const SizedBox(height: 16),
                const Text(
                  '🎉 恭喜！本组听音拼写测试已全部完成',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 24),
                MiuixButton(
                  onPressed: () => setState(() {
                    _spellingIndex = 0;
                    _spellingChecked = false;
                    _spellingController.clear();
                  }),
                  colors: MiuixButtonDefaults.buttonColorsPrimary(context),
                  child: const Text('重新测试一遍'),
                ),
              ],
            ),
          );
        }

        final word = words[_spellingIndex];

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            children: [
              // 进度指示
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '拼写测试: ${_spellingIndex + 1} / ${words.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    word.ieltsTag,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.ieltsCrimson),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 播放英音核心交互按钮
              GestureDetector(
                onTap: () => _playUkAudio(word.word),
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: AppColors.ieltsCrimson.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.ieltsCrimson.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.volume_up_rounded,
                    size: 48,
                    color: AppColors.ieltsCrimson,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                '轻触播放真人英音发音',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),

              // 中文提示
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.cardSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Text(
                  '中文释义：${word.definitionZh}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),

              // 拼写输入框
              TextField(
                controller: _spellingController,
                readOnly: _spellingChecked,
                autocorrect: false,
                textCapitalization: TextCapitalization.none,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: '输入英文拼写...',
                  hintStyle: const TextStyle(
                      fontSize: 14, color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.cardSurface,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.borderLight),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: AppColors.ieltsCrimson, width: 1.8),
                  ),
                ),
                onSubmitted: (_) {
                  if (!_spellingChecked) _checkSpelling(word, words);
                },
              ),
              const SizedBox(height: 20),

              // 检查结果展示
              if (_spellingChecked) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _spellingCorrect
                        ? AppColors.fsrsGood.withValues(alpha: 0.1)
                        : AppColors.ieltsCrimson.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _spellingCorrect
                          ? AppColors.fsrsGood
                          : AppColors.ieltsCrimson,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _spellingCorrect
                                ? Icons.check_circle_rounded
                                : Icons.cancel_rounded,
                            color: _spellingCorrect
                                ? AppColors.fsrsGood
                                : AppColors.ieltsCrimson,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _spellingCorrect ? '拼写完全正确！' : '拼写有误',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: _spellingCorrect
                                  ? AppColors.fsrsGood
                                  : AppColors.ieltsCrimson,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '标准拼写: ${word.word}   ${word.phoneticUk}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (word.contextSentenceEn.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          '"${word.contextSentenceEn}"',
                          style: const TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.ieltsCrimson,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => _nextSpellingWord(words),
                    child: const Text(
                      '下一词',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.oxfordNavy,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => _checkSpelling(word, words),
                    child: const Text(
                      '确认核对',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
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
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  title: Row(
                    children: [
                      Flexible(
                        child: Text(
                          word.word,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'serif',
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (word.phoneticUk.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            word.phoneticUk,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textMuted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 2),
                      Text(
                        word.definitionZh,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textSecondary),
                      ),
                      if (word.contextSentenceEn.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          '"${word.contextSentenceEn}"',
                          style: const TextStyle(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color: AppColors.textMuted,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 32, minHeight: 32),
                        icon: const Icon(Icons.volume_up_rounded,
                            color: AppColors.ieltsCrimson, size: 20),
                        tooltip: '真人英音',
                        onPressed: () => _playUkAudio(word.word),
                      ),
                      if (word.contextSentenceEn.isNotEmpty)
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints:
                              const BoxConstraints(minWidth: 32, minHeight: 32),
                          icon: const Icon(Icons.play_circle_outline_rounded,
                              color: AppColors.oxfordNavy, size: 20),
                          tooltip: '朗读例句',
                          onPressed: () =>
                              _speakSentence(word.contextSentenceEn, word: word.word),
                        ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 32, minHeight: 32),
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
