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
    final testsAsync = ref.watch(filteredListeningTestsProvider);
    final statsAsync = ref.watch(todayListeningStatsProvider);
    final selectedBook = ref.watch(selectedBookFilterProvider);
    final availableBooks = ref.watch(availableBooksProvider);

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
            tooltip: '从云端同步试卷清单',
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
                final added =
                    await syncService.syncManifestToDatabase(manifest);
                ref.invalidate(listeningTestsProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          '云端同步就绪！收录 ${manifest.tests.length} 套试卷 (新增 $added 套)'),
                      backgroundColor: AppColors.oxfordNavy,
                    ),
                  );
                }
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('无法连接云端清单，请检查网络或稍后重试'),
                      backgroundColor: AppColors.ieltsCrimson,
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 今日精听战报看板
                  _buildListeningStatsBanner(statsAsync),
                  const SizedBox(height: 16),

                  // 剑雅书籍横向快速筛选 Chips
                  _buildBookFilterChips(
                      context, ref, availableBooks, selectedBook),
                  const SizedBox(height: 16),

                  // 列表标题与计数
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text(
                            '真题精听库',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color:
                                  AppColors.oxfordNavy.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              selectedBook == '全部' ? '全套真题' : selectedBook,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.oxfordNavy,
                              ),
                            ),
                          ),
                        ],
                      ),
                      testsAsync.maybeWhen(
                        data: (tests) => Text(
                          '共 ${tests.length} 套试卷',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                        orElse: () => const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          testsAsync.when(
            data: (tests) {
              if (tests.isEmpty) {
                return const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      '暂无当前分类试卷，请点击右上角同步清单',
                      style:
                          TextStyle(fontSize: 13, color: AppColors.textMuted),
                    ),
                  ),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList.builder(
                  itemCount: tests.length,
                  itemBuilder: (context, index) {
                    return _buildTestCard(context, ref, tests[index]);
                  },
                ),
              );
            },
            loading: () => const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child:
                    CircularProgressIndicator(color: AppColors.ieltsCrimson),
              ),
            ),
            error: (err, _) => SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: Text('加载真题失败: $err')),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  Widget _buildBookFilterChips(BuildContext context, WidgetRef ref,
      List<String> books, String selectedBook) {
    if (books.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: books.length,
        separatorBuilder: (_, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final book = books[index];
          final isSelected = book == selectedBook;
          final displayText = book == '全部'
              ? '全部'
              : (book.startsWith('Cambridge ')
                  ? '剑${book.replaceFirst('Cambridge ', '')}'
                  : book);

          return ChoiceChip(
            label: Text(displayText),
            selected: isSelected,
            selectedColor: AppColors.oxfordNavy,
            backgroundColor: AppColors.cardSurface,
            labelStyle: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
            side: BorderSide(
              color: isSelected ? AppColors.oxfordNavy : AppColors.borderLight,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            showCheckmark: false,
            onSelected: (_) {
              ref.read(selectedBookFilterProvider.notifier).setFilter(book);
            },
          );
        },
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
    final progressVal = ref.watch(singleTestProgressProvider(test.testId));
    final isDownloadingThisTest = progressVal > 0.0 && progressVal < 1.0;
    final bool isIncomplete = test.isDownloaded &&
        (test.questions.isEmpty || test.sentences.isEmpty);

    String statusText = '云端待拉取';
    IconData statusIcon = Icons.cloud_outlined;
    Color statusColor = AppColors.textMuted;
    Color badgeBg = Colors.transparent;

    if (isDownloadingThisTest) {
      statusText = '下载中';
      statusIcon = Icons.downloading_rounded;
      statusColor = AppColors.ieltsCrimson;
      badgeBg = AppColors.ieltsCrimson.withValues(alpha: 0.08);
    } else if (isIncomplete) {
      statusText = '题库待补全';
      statusIcon = Icons.sync_problem_rounded;
      statusColor = AppColors.ieltsAmber;
      badgeBg = AppColors.ieltsAmber.withValues(alpha: 0.1);
    } else if (test.isDownloaded) {
      statusText = '离线就绪';
      statusIcon = Icons.offline_pin_rounded;
      statusColor = AppColors.fsrsGood;
      badgeBg = AppColors.paperSurface;
    }

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
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isIncomplete
                            ? AppColors.ieltsAmber.withValues(alpha: 0.4)
                            : (test.isDownloaded
                                ? AppColors.borderLight
                                : AppColors.textMuted),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          statusIcon,
                          size: 13,
                          color: statusColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 10,
                            color: statusColor,
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
                if (isIncomplete) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.ieltsAmber.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppColors.ieltsAmber.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.info_outline,
                            size: 14, color: AppColors.ieltsAmber),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '当前试卷缺少模考题库，建议立即补全以解锁1:1真题模考与精听',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.ieltsAmber,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
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
                      onPressed: () async {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('正在升级补全【${test.title}】题库...'),
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
                                content: Text('【${test.title}】已成功升级官方全功能题库！'),
                                backgroundColor: AppColors.fsrsGood,
                              ),
                            );
                          }
                        } else {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('升级题库失败，请检查网络或稍后重试'),
                                backgroundColor: AppColors.ieltsCrimson,
                              ),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.upgrade_rounded, size: 16),
                      label: const Text(
                        '一键升级官方模考与题库',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
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
