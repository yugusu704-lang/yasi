import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_miuix/miuix.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/models/listening_test_info.dart';
import '../../domain/models/study_stats.dart';
import '../providers/app_providers.dart';
import 'listening_workbench_screen.dart';
import 'exam_mode_screen.dart';

class ListeningHomeScreen extends ConsumerWidget {
  const ListeningHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final testsAsync = ref.watch(listeningTestsProvider);
    final statsAsync = ref.watch(todayListeningStatsProvider);

    return Scaffold(
      backgroundColor: AppColors.paperBackground,
      appBar: AppBar(
        backgroundColor: AppColors.paperBackground,
        elevation: 0,
        title: const Text(
          '剑雅真题精听',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
            fontFamily: 'serif',
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_download_outlined,
                color: AppColors.oxfordNavy),
            tooltip: '从云盘同步试卷清单',
            onPressed: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('正在从云端检测剑雅听力真题清单更新...'),
                  duration: Duration(seconds: 2),
                ),
              );
              final syncService = ref.read(cloudSyncServiceProvider);
              final manifest = await syncService.fetchManifest();
              if (manifest != null) {
                final added = await syncService.syncManifestToDatabase(manifest);
                ref.invalidate(listeningTestsProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('云盘同步就绪！收录 ${manifest.tests.length} 套试卷 (新增 $added 套)'),
                      backgroundColor: AppColors.oxfordNavy,
                    ),
                  );
                }
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('无法连接云端清单，请检查网络或网盘授权'),
                      backgroundColor: AppColors.ieltsCrimson,
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: testsAsync.when(
        data: (tests) => ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            // 今日精听战报看板
            _buildListeningStatsBanner(statsAsync),
            const SizedBox(height: 20),

            const Text(
              '真题精听库',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            for (final test in tests) _buildTestCard(context, ref, test),
          ],
        ),
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.ieltsCrimson),
        ),
        error: (err, _) => Center(child: Text('加载真题失败: $err')),
      ),
    );
  }

  Widget _buildListeningStatsBanner(AsyncValue<TodayListeningStats> statsAsync) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: statsAsync.when(
        data: (stats) => Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem('今日精听', '${stats.listeningMinutes}', '分钟'),
            Container(width: 1, height: 36, color: AppColors.borderLight),
            _buildStatItem('单句复读', '${stats.repeatCount}', '次'),
            Container(width: 1, height: 36, color: AppColors.borderLight),
            _buildStatItem('已掌握句', stats.formattedMasteryRate, '理解度'),
          ],
        ),
        loading: () => Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem('今日精听', '-', '分钟'),
            Container(width: 1, height: 36, color: AppColors.borderLight),
            _buildStatItem('单句复读', '-', '次'),
            Container(width: 1, height: 36, color: AppColors.borderLight),
            _buildStatItem('已掌握句', '-', '理解度'),
          ],
        ),
        error: (err, stack) => Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem('今日精听', '0', '分钟'),
            Container(width: 1, height: 36, color: AppColors.borderLight),
            _buildStatItem('单句复读', '0', '次'),
            Container(width: 1, height: 36, color: AppColors.borderLight),
            _buildStatItem('已掌握句', '0%', '理解度'),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, String unit) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
        const SizedBox(height: 4),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.ieltsCrimson,
                  fontFamily: 'serif',
                ),
              ),
              TextSpan(
                text: ' $unit',
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTestCard(
      BuildContext context, WidgetRef ref, ListeningTestInfo test) {
    final syncProgressAsync = ref.watch(syncProgressStreamProvider);
    final currentProgress = syncProgressAsync.value;
    final isDownloadingThisTest = currentProgress?.testId == test.testId &&
        currentProgress?.isCompleted != true &&
        currentProgress?.error == null;
    final progressVal = (currentProgress?.testId == test.testId)
        ? (currentProgress?.progress ?? 0.0)
        : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: MiuixCard(
        cornerRadius: 16,
        onPressed: test.isDownloaded
            ? () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (ctx) => ListeningWorkbenchScreen(test: test),
                  ),
                );
              }
            : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.ieltsCrimson.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      test.book,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.ieltsCrimson,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Test ${test.testNumber} · Section ${test.section}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.oxfordNavy,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: test.isDownloaded
                          ? AppColors.paperSurface
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: test.isDownloaded
                            ? AppColors.borderLight
                            : AppColors.textMuted,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          test.isDownloaded
                              ? Icons.offline_pin_rounded
                              : (isDownloadingThisTest
                                  ? Icons.downloading_rounded
                                  : Icons.cloud_outlined),
                          size: 13,
                          color: test.isDownloaded
                              ? AppColors.fsrsGood
                              : (isDownloadingThisTest
                                  ? AppColors.ieltsCrimson
                                  : AppColors.textMuted),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          test.isDownloaded
                              ? '离线就绪'
                              : (isDownloadingThisTest ? '下载中' : '云端待拉取'),
                          style: TextStyle(
                            fontSize: 10,
                            color: test.isDownloaded
                                ? AppColors.fsrsGood
                                : (isDownloadingThisTest
                                    ? AppColors.ieltsCrimson
                                    : AppColors.textMuted),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (test.isDownloaded &&
                      !test.localAudioPath.startsWith('assets/')) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded,
                          size: 16, color: AppColors.textMuted),
                      tooltip: '释放本地磁盘空间',
                      visualDensity: VisualDensity.compact,
                      onPressed: () async {
                        await ref
                            .read(cloudSyncServiceProvider)
                            .deleteTestAudio(test.testId);
                        ref.invalidate(listeningTestsProvider);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('已释放试卷音频本地空间，备考学习记录依然保留'),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              Text(
                test.title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.headphones_rounded,
                      size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    test.sentences.isNotEmpty
                        ? '${test.sentences.length} 句逐句精听'
                        : '云端高清音频',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(width: 16),
                  const Icon(Icons.timer_outlined,
                      size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    test.totalDurationMs > 0
                        ? '${(test.totalDurationMs / 1000).round()} 秒音频'
                        : '完整 Section 考段',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                  if (test.questions.isNotEmpty) ...[
                    const SizedBox(width: 16),
                    const Icon(Icons.quiz_outlined,
                        size: 14, color: AppColors.ieltsCrimson),
                    const SizedBox(width: 4),
                    Text(
                      '${test.questions.length} 道原题',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.ieltsCrimson),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              if (isDownloadingThisTest) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '正在从云端拉取音频与题目...',
                          style: TextStyle(
                              fontSize: 11, color: AppColors.textSecondary),
                        ),
                        Text(
                          '${(progressVal * 100).toInt()}%',
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.ieltsCrimson),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progressVal > 0 ? progressVal : null,
                        color: AppColors.ieltsCrimson,
                        backgroundColor: AppColors.borderLight,
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              ] else if (!test.isDownloaded) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.oxfordNavy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () async {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('开始拉取 ${test.title}...'),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                      final success = await ref
                          .read(cloudSyncServiceProvider)
                          .downloadTestById(test.testId);
                      if (success) {
                        ref.invalidate(listeningTestsProvider);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('【${test.title}】已下载完毕，可完全离线练习！'),
                              backgroundColor: AppColors.fsrsGood,
                            ),
                          );
                        }
                      } else {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('下载失败，请检查网络或稍后重试'),
                              backgroundColor: AppColors.ieltsCrimson,
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.cloud_download_rounded, size: 16),
                    label: const Text(
                      '拉取云端音频与试卷',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ] else ...[
                Row(
                  children: [
                    if (test.questions.isNotEmpty) ...[
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.ieltsCrimson,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (ctx) => ExamModeScreen(test: test),
                              ),
                            );
                          },
                          icon: const Icon(Icons.edit_note_rounded, size: 16),
                          label: const Text(
                            '1:1 官方真题模考',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.oxfordNavy,
                          side: const BorderSide(color: AppColors.borderLight),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (ctx) =>
                                  ListeningWorkbenchScreen(test: test),
                            ),
                          );
                        },
                        icon: const Icon(Icons.headphones_rounded, size: 16),
                        label: const Text(
                          '逐句精听与听写',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
