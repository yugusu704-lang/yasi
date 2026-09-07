import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_miuix/miuix.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/models/listening_test_info.dart';
import '../../domain/models/subtitle_sentence.dart';
import '../../domain/audio/audio_player_service.dart';
import '../providers/app_providers.dart';
import 'components/word_lookup_bottom_sheet.dart';

enum MaskMode {
  normal('双语完整'),
  hideZh('盲听英文'),
  dictation('听写填空');

  final String label;
  const MaskMode(this.label);
}

class ListeningWorkbenchScreen extends ConsumerStatefulWidget {
  final ListeningTestInfo test;

  const ListeningWorkbenchScreen({super.key, required this.test});

  @override
  ConsumerState<ListeningWorkbenchScreen> createState() =>
      _ListeningWorkbenchScreenState();
}

class _ListeningWorkbenchScreenState
    extends ConsumerState<ListeningWorkbenchScreen> {
  MaskMode _maskMode = MaskMode.normal;
  final ScrollController _scrollController = ScrollController();
  final List<GlobalKey> _sentenceKeys = [];

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < widget.test.sentences.length; i++) {
      _sentenceKeys.add(GlobalKey());
    }

    // 初始化音频播放源
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(audioPlayerServiceProvider).loadTest(widget.test);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToSentence(int index) {
    if (index >= 0 && index < _sentenceKeys.length) {
      final key = _sentenceKeys[index];
      if (key.currentContext != null) {
        Scrollable.ensureVisible(
          key.currentContext!,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: 0.3,
        );
      }
    }
  }

  void _openWordLookup(String word, SubtitleSentence s) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => WordLookupBottomSheet(
        word: word,
        contextSentenceEn: s.textEn,
        contextSentenceZh: s.textZh,
        sourceTest: widget.test.displayTag,
        onAddToNotebook: (item) {
          ref.read(vocabularyListProvider.notifier).addWord(item);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final audioService = ref.watch(audioPlayerServiceProvider);

    return Scaffold(
      backgroundColor: AppColors.paperBackground,
      appBar: AppBar(
        backgroundColor: AppColors.paperBackground,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.test.displayTag,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              widget.test.title,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          // 模式切换菜单
          PopupMenuButton<MaskMode>(
            icon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.paperSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.tune_rounded,
                      size: 14, color: AppColors.ieltsCrimson),
                  const SizedBox(width: 4),
                  Text(
                    _maskMode.label,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ieltsCrimson,
                    ),
                  ),
                ],
              ),
            ),
            onSelected: (mode) => setState(() => _maskMode = mode),
            itemBuilder: (ctx) => [
              for (final mode in MaskMode.values)
                PopupMenuItem(
                  value: mode,
                  child: Text(mode.label),
                ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // 字幕列表主体
          Expanded(
            child: StreamBuilder<int>(
              stream: audioService.currentSentenceIndexStream,
              initialData: audioService.currentSentenceIndex,
              builder: (context, snapshot) {
                final currentIndex = snapshot.data ?? 0;

                return ListView.builder(
                  controller: _scrollController,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: widget.test.sentences.length,
                  itemBuilder: (context, index) {
                    final s = widget.test.sentences[index];
                    final isCurrent = index == currentIndex;

                    return _buildSentenceCard(s, index, isCurrent, audioService);
                  },
                );
              },
            ),
          ),

          // 底部精听控制工作台
          _buildControlPanel(audioService),
        ],
      ),
    );
  }

  Widget _buildSentenceCard(SubtitleSentence s, int index, bool isCurrent,
      AudioPlayerService audioService) {
    return Container(
      key: _sentenceKeys[index],
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCurrent ? AppColors.cardSurface : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrent ? AppColors.ieltsCrimson : AppColors.borderLight,
          width: isCurrent ? 1.5 : 0.8,
        ),
        boxShadow: isCurrent
            ? [
                BoxShadow(
                  color: AppColors.ieltsCrimson.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 句子头部序号与快速播放
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isCurrent
                      ? AppColors.ieltsCrimson
                      : AppColors.paperSurface,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isCurrent ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${(s.startMs / 1000).toStringAsFixed(1)}s ~ ${(s.endMs / 1000).toStringAsFixed(1)}s',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () {
                  audioService.jumpToSentence(index);
                  if (!audioService.isPlaying) {
                    audioService.play();
                  }
                },
                child: Icon(
                  isCurrent && audioService.isPlaying
                      ? Icons.pause_circle_outline_rounded
                      : Icons.play_circle_outline_rounded,
                  size: 22,
                  color: isCurrent
                      ? AppColors.ieltsCrimson
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 英文内容（可点击查词）
          if (_maskMode == MaskMode.dictation && !isCurrent) ...[
            Container(
              height: 24,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.borderLight.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: const Text(
                '（点击播放并默写拼写）',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ),
          ] else ...[
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: s.textEn.split(' ').map((rawWord) {
                final isKeyWord = s.keyWords.any((kw) => rawWord
                    .toLowerCase()
                    .contains(kw.toLowerCase()));

                return InkWell(
                  onTap: () => _openWordLookup(rawWord, s),
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                    decoration: isKeyWord
                        ? BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: AppColors.ieltsCrimson,
                                width: 1.5,
                              ),
                            ),
                          )
                        : null,
                    child: Text(
                      rawWord,
                      style: TextStyle(
                        fontSize: 15,
                        fontFamily: 'serif',
                        height: 1.3,
                        fontWeight:
                            isKeyWord ? FontWeight.w600 : FontWeight.normal,
                        color: isKeyWord
                            ? AppColors.ieltsCrimson
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],

          // 中文翻译（可遮挡）
          if (_maskMode != MaskMode.hideZh) ...[
            const SizedBox(height: 8),
            Text(
              s.textZh,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildControlPanel(AudioPlayerService audioService) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 进度与时间
          StreamBuilder<Duration>(
            stream: audioService.positionStream,
            builder: (context, snapshot) {
              final pos = snapshot.data ?? Duration.zero;
              final totalMs = widget.test.totalDurationMs;
              final currentMs = pos.inMilliseconds.clamp(0, totalMs);
              final progress = totalMs > 0 ? (currentMs / totalMs) : 0.0;

              return Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(pos),
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary),
                      ),
                      Text(
                        _formatDuration(Duration(milliseconds: totalMs)),
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  MiuixSlider(
                    value: progress.clamp(0.0, 1.0),
                    onValueChanged: (val) {
                      final targetMs = (val * totalMs).round();
                      audioService.seek(Duration(milliseconds: targetMs));
                    },
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 10),

          // 主播控按钮组
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // 单句循环开关
              StreamBuilder<bool>(
                stream: audioService.isSingleLoopStream,
                initialData: audioService.isSingleLoop,
                builder: (context, snapshot) {
                  final isLoop = snapshot.data ?? false;
                  return IconButton(
                    icon: Icon(
                      Icons.repeat_one_rounded,
                      color: isLoop
                          ? AppColors.ieltsCrimson
                          : AppColors.textMuted,
                      size: 24,
                    ),
                    onPressed: () {
                      audioService.toggleSingleLoop();
                      setState(() {});
                    },
                    tooltip: '单句循环',
                  );
                },
              ),

              // 上一句
              IconButton(
                icon: const Icon(Icons.skip_previous_rounded,
                    color: AppColors.textPrimary, size: 28),
                onPressed: () async {
                  await audioService.previousSentence();
                  _scrollToSentence(audioService.currentSentenceIndex);
                },
              ),

              // 播放/暂停
              StreamBuilder(
                stream: audioService.playerStateStream,
                builder: (context, snapshot) {
                  final isPlaying = audioService.isPlaying;

                  return GestureDetector(
                    onTap: () async {
                      await audioService.togglePlay();
                      setState(() {});
                    },
                    child: Container(
                      width: 54,
                      height: 54,
                      decoration: const BoxDecoration(
                        color: AppColors.ieltsCrimson,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  );
                },
              ),

              // 下一句
              IconButton(
                icon: const Icon(Icons.skip_next_rounded,
                    color: AppColors.textPrimary, size: 28),
                onPressed: () async {
                  await audioService.nextSentence();
                  _scrollToSentence(audioService.currentSentenceIndex);
                },
              ),

              // 变速调节弹窗
              StreamBuilder<double>(
                stream: audioService.speedStream,
                initialData: audioService.currentSpeed,
                builder: (context, snapshot) {
                  final speed = snapshot.data ?? 1.0;

                  return PopupMenuButton<double>(
                    tooltip: '播放速度',
                    initialValue: speed,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.paperSurface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${speed}x',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.ieltsCrimson,
                        ),
                      ),
                    ),
                    onSelected: (val) => audioService.setSpeed(val),
                    itemBuilder: (ctx) => [
                      for (final s in [0.75, 0.9, 1.0, 1.25, 1.5])
                        PopupMenuItem(
                          value: s,
                          child: Text('${s}x 语速'),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
