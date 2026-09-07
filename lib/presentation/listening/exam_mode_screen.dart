import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_miuix/miuix.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/models/listening_test_info.dart';
import '../../domain/models/exam_question.dart';
import '../../domain/audio/audio_player_service.dart';
import '../providers/app_providers.dart';
import 'listening_workbench_screen.dart';

class ExamModeScreen extends ConsumerStatefulWidget {
  final ListeningTestInfo test;

  const ExamModeScreen({super.key, required this.test});

  @override
  ConsumerState<ExamModeScreen> createState() => _ExamModeScreenState();
}

class _ExamModeScreenState extends ConsumerState<ExamModeScreen> {
  final Map<int, TextEditingController> _controllers = {};
  bool _isSubmitted = false;

  @override
  void initState() {
    super.initState();
    for (final q in widget.test.questions) {
      _controllers[q.questionNumber] =
          TextEditingController(text: q.userAnswer);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(audioPlayerServiceProvider).loadTest(widget.test);
    });
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _submitExam() {
    setState(() {
      for (final q in widget.test.questions) {
        q.userAnswer = _controllers[q.questionNumber]?.text ?? '';
      }
      _isSubmitted = true;
    });
  }

  void _resetExam() {
    setState(() {
      for (final q in widget.test.questions) {
        q.userAnswer = '';
        _controllers[q.questionNumber]?.clear();
      }
      _isSubmitted = false;
    });
  }

  void _jumpToMistakeWorkbench() {
    final wrongQuestions =
        widget.test.questions.where((q) => !q.isCorrect).toList();
    final firstWrongIndex = wrongQuestions.isNotEmpty
        ? wrongQuestions.first.targetSentenceIndex
        : 0;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => ListeningWorkbenchScreen(
          test: widget.test,
          initialSentenceIndex: firstWrongIndex,
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String _calculateBand(int correctCount, int total) {
    if (total == 0) return '0.0';
    final ratio = correctCount / total;
    if (ratio >= 0.9) return '8.5 ~ 9.0';
    if (ratio >= 0.8) return '7.5 ~ 8.0';
    if (ratio >= 0.7) return '6.5 ~ 7.0';
    if (ratio >= 0.6) return '5.5 ~ 6.0';
    return '5.0 以下';
  }

  @override
  Widget build(BuildContext context) {
    final audioService = ref.watch(audioPlayerServiceProvider);
    final correctCount =
        widget.test.questions.where((q) => q.isCorrect).length;
    final totalCount = widget.test.questions.length;

    return Scaffold(
      backgroundColor: AppColors.paperBackground,
      appBar: AppBar(
        backgroundColor: AppColors.paperBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '1:1 官方模考 · ${widget.test.displayTag}',
              style: const TextStyle(
                fontSize: 15,
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
          if (_isSubmitted)
            TextButton.icon(
              onPressed: _resetExam,
              icon: const Icon(Icons.refresh_rounded,
                  size: 16, color: AppColors.oxfordNavy),
              label: const Text('重练',
                  style: TextStyle(
                      color: AppColors.oxfordNavy,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: Column(
        children: [
          // 顶部固定音频播放栏
          _buildAudioHeader(audioService),

          // 试卷作答内容
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                // 考试说明 Banner
                _buildInstructionsCard(),
                const SizedBox(height: 16),

                // 判分结果卡片（仅交卷后展示）
                if (_isSubmitted) ...[
                  _buildResultBanner(correctCount, totalCount),
                  const SizedBox(height: 16),
                ],

                // 填空题列表
                _buildQuestionsList(),
                const SizedBox(height: 30),
              ],
            ),
          ),

          // 底部操作栏
          _buildBottomActionCard(correctCount, totalCount),
        ],
      ),
    );
  }

  Widget _buildAudioHeader(AudioPlayerService audioService) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        border: const Border(
          bottom: BorderSide(color: AppColors.borderLight, width: 0.8),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: StreamBuilder<Duration>(
        stream: audioService.positionStream,
        builder: (context, snapshot) {
          final pos = snapshot.data ?? Duration.zero;
          final totalMs = widget.test.totalDurationMs;
          final currentMs = pos.inMilliseconds.clamp(0, totalMs);
          final progress = totalMs > 0 ? (currentMs / totalMs) : 0.0;

          return Row(
            children: [
              // 播放/暂停
              StreamBuilder(
                stream: audioService.playerStateStream,
                builder: (context, _) {
                  final isPlaying = audioService.isPlaying;
                  return InkWell(
                    onTap: () => audioService.togglePlay(),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: AppColors.ieltsCrimson,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),

              // 进度条与时间
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(pos),
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                              fontFamily: 'monospace'),
                        ),
                        Text(
                          _formatDuration(Duration(milliseconds: totalMs)),
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                              fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                    MiuixSlider(
                      value: progress.clamp(0.0, 1.0),
                      onValueChanged: (val) {
                        final targetMs = (val * totalMs).round();
                        audioService.seek(Duration(milliseconds: targetMs));
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // 语速切换
              StreamBuilder<double>(
                stream: audioService.speedStream,
                initialData: audioService.currentSpeed,
                builder: (context, snapshot) {
                  final speed = snapshot.data ?? 1.0;
                  return PopupMenuButton<double>(
                    tooltip: '语速',
                    initialValue: speed,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.paperSurface,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Text(
                        '${speed}x',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.ieltsCrimson,
                        ),
                      ),
                    ),
                    onSelected: (val) => audioService.setSpeed(val),
                    itemBuilder: (ctx) => [
                      for (final s in [0.75, 0.9, 1.0, 1.25])
                        PopupMenuItem(value: s, child: Text('${s}x 语速')),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInstructionsCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.oxfordNavy.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.oxfordNavy.withValues(alpha: 0.15),
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.assignment_outlined,
                  size: 16, color: AppColors.oxfordNavy),
              SizedBox(width: 6),
              Text(
                'SECTION 1 · Questions 1-10',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.oxfordNavy,
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          Text(
            'Complete the notes below.\nWrite ONE WORD AND/OR A NUMBER for each answer.',
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultBanner(int correct, int total) {
    final accuracy = total > 0 ? (correct / total * 100).round() : 0;
    final band = _calculateBand(correct, total);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accuracy >= 70 ? AppColors.fsrsGood : AppColors.ieltsCrimson,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '模考成绩: $correct / $total 题',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  fontFamily: 'serif',
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: accuracy >= 70
                      ? AppColors.fsrsGood.withValues(alpha: 0.12)
                      : AppColors.ieltsCrimson.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '预测 Band $band',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: accuracy >= 70
                        ? AppColors.fsrsGood
                        : AppColors.ieltsCrimson,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            accuracy >= 80
                ? '🎉 极佳的抓词敏感度！建议对错题进行句子听写以夯实拼写细节。'
                : '💡 注意连读与核心名词单复数抓取。点击下方按钮可直达错题精听模式。',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionsList() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Transport Survey - Commuter Feedback',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
              fontFamily: 'serif',
            ),
          ),
          const Divider(height: 24, color: AppColors.borderLight),
          for (final q in widget.test.questions) ...[
            _buildQuestionItem(q),
            if (q.questionNumber < widget.test.questions.length)
              const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildQuestionItem(ExamQuestion q) {
    final controller = _controllers[q.questionNumber];
    final isCorrect = q.isCorrect;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 题号角标
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _isSubmitted
                    ? (isCorrect
                        ? AppColors.fsrsGood.withValues(alpha: 0.15)
                        : AppColors.ieltsCrimson.withValues(alpha: 0.15))
                    : AppColors.oxfordNavy.withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border: Border.all(
                  color: _isSubmitted
                      ? (isCorrect ? AppColors.fsrsGood : AppColors.ieltsCrimson)
                      : AppColors.oxfordNavy.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                '${q.questionNumber}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _isSubmitted
                      ? (isCorrect
                          ? AppColors.fsrsGood
                          : AppColors.ieltsCrimson)
                      : AppColors.oxfordNavy,
                ),
              ),
            ),
            const SizedBox(width: 8),

            // 题干前导文本
            Text(
              q.promptBefore,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),

            // 填空输入框
            Expanded(
              child: SizedBox(
                height: 36,
                child: TextField(
                  controller: controller,
                  readOnly: _isSubmitted,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _isSubmitted
                        ? (isCorrect
                            ? AppColors.fsrsGood
                            : AppColors.ieltsCrimson)
                        : AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    hintText: '写下答案...',
                    hintStyle: const TextStyle(
                        fontSize: 12, color: AppColors.textMuted),
                    filled: true,
                    fillColor: _isSubmitted
                        ? (isCorrect
                            ? AppColors.fsrsGood.withValues(alpha: 0.06)
                            : AppColors.ieltsCrimson.withValues(alpha: 0.06))
                        : AppColors.paperBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.borderLight),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.borderLight),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                          color: AppColors.ieltsCrimson, width: 1.5),
                    ),
                  ),
                ),
              ),
            ),

            // 题干后缀文本
            if (q.promptAfter.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text(
                q.promptAfter,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ],
        ),

        // 提交后的答案纠错提示
        if (_isSubmitted && !isCorrect) ...[
          Padding(
            padding: const EdgeInsets.only(left: 34, top: 4),
            child: Row(
              children: [
                const Icon(Icons.close_rounded,
                    size: 14, color: AppColors.ieltsCrimson),
                const SizedBox(width: 4),
                Text(
                  '官方标准答案: ${q.acceptableAnswers.join(' / ')}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.ieltsCrimson,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBottomActionCard(int correct, int total) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        border: const Border(
          top: BorderSide(color: AppColors.borderLight, width: 0.8),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: _isSubmitted
            ? Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        side: const BorderSide(color: AppColors.oxfordNavy),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _resetExam,
                      child: const Text(
                        '重做本套模考',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.oxfordNavy),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.ieltsCrimson,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _jumpToMistakeWorkbench,
                      icon: const Icon(Icons.headphones_rounded, size: 18),
                      label: const Text(
                        '一键跳转错题逐句精听',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              )
            : ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.ieltsCrimson,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _submitExam,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_outline_rounded, size: 18),
                    SizedBox(width: 8),
                    Text(
                      '交卷并智能判分',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
