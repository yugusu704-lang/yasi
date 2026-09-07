import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_miuix/miuix.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/models/study_stats.dart';
import '../providers/app_providers.dart';

class ProfileDriveScreen extends ConsumerWidget {
  const ProfileDriveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final driveState = ref.watch(googleDriveProvider);
    final driveNotifier = ref.read(googleDriveProvider.notifier);
    final overallStatsAsync = ref.watch(overallPrepStatsProvider);

    ref.listen<GoogleDriveState>(googleDriveProvider, (previous, next) {
      if (next.errorMessage != null &&
          next.errorMessage != previous?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.ieltsCrimson,
            content: Text(next.errorMessage!),
            duration: const Duration(seconds: 4),
          ),
        );
      } else if (next.statusMessage != null &&
          next.statusMessage != previous?.statusMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.statusMessage!),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: AppColors.paperBackground,
      appBar: AppBar(
        backgroundColor: AppColors.paperBackground,
        elevation: 0,
        title: const Text(
          '云盘与备考档案',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
            fontFamily: 'serif',
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // 谷歌云盘连接卡片
          _buildGoogleDriveCard(context, driveState, driveNotifier),
          const SizedBox(height: 20),

          // 备考数据与掌控度
          const Text(
            '备考数据看板',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _buildStatsCard(overallStatsAsync),
          const SizedBox(height: 20),

          // 离线引擎与发音偏好设置
          const Text(
            '离线引擎与发音偏好',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _buildSettingsCard(context),
        ],
      ),
    );
  }

  Widget _buildGoogleDriveCard(BuildContext context,
      GoogleDriveState driveState, GoogleDriveNotifier driveNotifier) {
    return MiuixCard(
      cornerRadius: 18,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.oxfordNavy.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.add_to_drive_rounded,
                      color: AppColors.oxfordNavy, size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Google Drive 云盘互联',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        driveState.isConnected
                            ? (driveState.displayName.isNotEmpty
                                ? '${driveState.displayName} (${driveState.accountEmail})'
                                : '已绑定: ${driveState.accountEmail}')
                            : '未授权连接个人谷歌云盘',
                        style: TextStyle(
                          fontSize: 12,
                          color: driveState.isConnected
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: driveState.isConnected && driveState.autoSyncEnabled,
                  activeThumbColor: AppColors.ieltsCrimson,
                  onChanged: (val) {
                    driveNotifier.toggleAutoSync(val);
                  },
                ),
              ],
            ),
            if (driveState.isConnected) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '上次同步: ${driveState.lastSyncTime}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      visualDensity: VisualDensity.compact,
                      foregroundColor: AppColors.textSecondary,
                    ),
                    icon: const Icon(Icons.link_off_rounded, size: 14),
                    label: const Text('解除绑定', style: TextStyle(fontSize: 12)),
                    onPressed: () {
                      _showUnbindConfirmDialog(context, driveNotifier);
                    },
                  ),
                ],
              ),
            ],
            if (driveState.isSyncing) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.oxfordNavy,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      driveState.statusMessage ?? '正在处理云端任务...',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.oxfordNavy,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (driveState.errorMessage != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.ieltsCrimson.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.ieltsCrimson.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        color: AppColors.ieltsCrimson, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        driveState.errorMessage!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.ieltsCrimson,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            const Divider(color: AppColors.borderLight, height: 1),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.cloud_download_rounded, size: 16),
                    label: const Text('增量拉取音频'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.oxfordNavy,
                      side: const BorderSide(color: AppColors.borderLight),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: driveState.isConnected
                        ? () {
                            driveNotifier.syncNow();
                          }
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.backup_rounded, size: 16),
                    label: const Text('备份学习记录'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.ieltsCrimson,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: driveState.isConnected
                        ? () {
                            driveNotifier.backupDataNow();
                          }
                        : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showUnbindConfirmDialog(
      BuildContext context, GoogleDriveNotifier driveNotifier) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('解除 Google Drive 绑定'),
        content: const Text('解除绑定后将清除本地登录授权凭证。本地已下载的音频和做题记录将完整保留，确定退出吗？'),
        actions: [
          TextButton(
            child: const Text('取消'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.ieltsCrimson,
              foregroundColor: Colors.white,
            ),
            child: const Text('确定解绑'),
            onPressed: () {
              Navigator.of(ctx).pop();
              driveNotifier.disconnect();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(AsyncValue<OverallPrepStats> overallStatsAsync) {
    return MiuixCard(
      cornerRadius: 18,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: overallStatsAsync.when(
          data: (stats) => Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatMetric('累计精听', '${stats.totalListeningHours}', '小时'),
                  _buildStatMetric('FSRS 掌握', '${stats.fsrsMasteredWords}', '词'),
                  _buildStatMetric('连续备考', '${stats.streakDays}', '天'),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.paperSurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.insights_rounded,
                        color: AppColors.fsrsGood, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        stats.retentionPrediction,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textPrimary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          loading: () => Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatMetric('累计精听', '-', '小时'),
                  _buildStatMetric('FSRS 掌握', '-', '词'),
                  _buildStatMetric('连续备考', '-', '天'),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.paperSurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.insights_rounded,
                        color: AppColors.fsrsGood, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '记忆预测计算中...',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          error: (err, stack) => Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatMetric('累计精听', '0.0', '小时'),
                  _buildStatMetric('FSRS 掌握', '0', '词'),
                  _buildStatMetric('连续备考', '0', '天'),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.paperSurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.insights_rounded,
                        color: AppColors.fsrsGood, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '开始听力和词汇练习后，此处将呈现个性化记忆留存预测。',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textPrimary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatMetric(String label, String value, String unit) {
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
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.ieltsCrimson,
                  fontFamily: 'serif',
                ),
              ),
              TextSpan(
                text: ' $unit',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsCard(BuildContext context) {
    return MiuixCard(
      cornerRadius: 18,
      child: Material(
        color: Colors.transparent,
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.record_voice_over_rounded,
                  color: AppColors.oxfordNavy),
              title: const Text('发音口音偏好'),
              subtitle: const Text('默认英音（British English - en-GB）'),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已配置为官方剑桥英音 (en-GB)')),
                );
              },
            ),
            const Divider(color: AppColors.borderLight, height: 1),
            ListTile(
              leading: const Icon(Icons.storage_rounded,
                  color: AppColors.oxfordNavy),
              title: const Text('离线雅思词典包'),
              subtitle: const Text('SQLite 本地词库已就绪 (14.2 MB)'),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.fsrsGood.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  '已就绪',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.fsrsGood,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const Divider(color: AppColors.borderLight, height: 1),
            const ListTile(
              leading: Icon(Icons.info_outline_rounded,
                  color: AppColors.oxfordNavy),
              title: Text('关于应用'),
              subtitle: Text('雅思精听备考 v1.0.0 (DevFlow Engine)'),
            ),
          ],
        ),
      ),
    );
  }
}
