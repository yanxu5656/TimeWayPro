import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/ui/glass.dart';
import '../../data/models/task.dart';

class TaskCard extends StatelessWidget {
  final Task task;
  final bool isRunning;
  final int elapsedSeconds;
  final int dailyDuration;

  /// 那个时长的前缀文案。任务页会传「今日」或「当日」——
  /// 选中今天是「今日 X分钟」，翻到别的日期是「当日 X分钟」。
  final String durationLabel;

  final VoidCallback onComplete;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onStart;
  final VoidCallback onStop;

  const TaskCard({
    super.key,
    required this.task,
    this.isRunning = false,
    this.elapsedSeconds = 0,
    this.dailyDuration = 0,
    this.durationLabel = '今日',
    required this.onComplete,
    required this.onEdit,
    required this.onDelete,
    required this.onStart,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    // TaskProvider 每秒 tick 会重建整个列表，包一层 RepaintBoundary
    // 把重栅格化限制在真正变化的卡片上
    return RepaintBoundary(
      child: GlassCard(
        // 不指定 radius，用默认 lg(16)——与待办/规划页的列表项卡片一致。
        // 原先这里是 xl(20)，同一类东西两个圆角。
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        // 计时中：描边加粗 + success 强调色 + 开启隐式过渡
        animate: true,
        edgeWidth: isRunning ? 2 : 1,
        tint: isRunning ? AppColors.success : null,
        onTap: onEdit,
        onLongPress: () => _showOptions(context),
        child: Row(
          children: [
            // 完成按钮
            _buildCompleteButton(),
            const SizedBox(width: 14),

            // 任务信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题和计时状态
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          task.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: task.isCompleted
                                ? AppColors.textHint
                                : AppColors.textPrimary,
                            decoration: task.isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ),
                      if (isRunning) _buildRunningIndicator(),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // 计时显示（进行中）
                  if (isRunning) _buildTimerDisplay(),

                  // 标签行
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _buildTag(
                        task.timerType == TimerType.countUp
                            ? Icons.timer_outlined
                            : Icons.hourglass_bottom,
                        task.timerType == TimerType.countUp
                            ? '正计时'
                            : '倒计时 ${task.durationText}',
                      ),
                      if (task.isRepeatable)
                        _buildTag(Icons.repeat, task.repeatTypeText),
                      if (task.isRepeatable && task.repeatCount > 1)
                        _buildTag(Icons.refresh, '${task.repeatCount}次/天'),
                      if (task.dueDate != null)
                        _buildTag(
                          Icons.event_outlined,
                          DateFormat('MM/dd').format(task.dueDate!),
                        ),
                    ],
                  ),

                  // 完成次数
                  if (task.isRepeatable && task.completedCount > 0) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primarySubtle,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.check_circle_outline,
                                size: 14,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${task.completedCount}/${task.repeatCount}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadius.xs),
                            child: LinearProgressIndicator(
                              value: task.repeatCount > 0
                                  ? task.completedCount / task.repeatCount
                                  : 0,
                              backgroundColor: AppColors.surfaceVariant,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                task.completedCount >= task.repeatCount
                                    ? AppColors.success
                                    : AppColors.primary,
                              ),
                              minHeight: 4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  // 当日累计时长。
                  //
                  // 颜色用 textSecondary 而不是 textHint：这是 12px 且承载
                  // 真实数据，而 textHint 在玻璃底上只有约 3.1:1，
                  // 按 AppColors 里写明的规则不得用于 <18px 的语义文字。
                  if (dailyDuration > 0) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$durationLabel ${_formatDuration(dailyDuration)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // 操作按钮
            if (!task.isCompleted)
              isRunning ? _buildStopButton() : _buildStartButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildCompleteButton() {
    // 尺寸与配色统一走 GlassCheckCircle（28px + success 绿）。
    // 原先这里是 28/primary，待办页是 26/success，两页观感不一致。
    return GlassCheckCircle(
      isChecked: task.isCompleted,
      onTap: onComplete,
      semanticLabel: task.title,
    );
  }

  Widget _buildRunningIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.success,
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            '进行中',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerDisplay() {
    final hours = elapsedSeconds ~/ 3600;
    final minutes = (elapsedSeconds % 3600) ~/ 60;
    final seconds = elapsedSeconds % 60;

    String timeStr;
    if (hours > 0) {
      timeStr =
          '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      timeStr =
          '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }

    // 倒计时模式显示剩余时间
    if (task.timerType == TimerType.countDown && task.duration != null) {
      final remaining = task.duration! - elapsedSeconds;
      if (remaining > 0) {
        final remHours = remaining ~/ 3600;
        final remMinutes = (remaining % 3600) ~/ 60;
        final remSeconds = remaining % 60;
        if (remHours > 0) {
          timeStr =
              '${remHours.toString().padLeft(2, '0')}:${remMinutes.toString().padLeft(2, '0')}:${remSeconds.toString().padLeft(2, '0')}';
        } else {
          timeStr =
              '${remMinutes.toString().padLeft(2, '0')}:${remSeconds.toString().padLeft(2, '0')}';
        }
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: AppGradients.softFill(AppColors.primary),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.access_time_filled,
            size: 18,
            color: AppColors.primary,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(timeStr, style: AppText.mono.copyWith(color: AppColors.primary)),
        ],
      ),
    );
  }

  Widget _buildStartButton() {
    return GlassIconButton(
      icon: task.timerType == TimerType.countUp
          ? Icons.play_arrow_rounded
          : Icons.timer_outlined,
      onTap: onStart,
      color: AppColors.primary,
    );
  }

  Widget _buildStopButton() {
    return GlassIconButton(
      icon: Icons.stop_rounded,
      onTap: onStop,
      color: AppColors.error,
    );
  }

  Widget _buildTag(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) return '$seconds秒';
    if (seconds < 3600) return '${seconds ~/ 60}分钟';
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    return '$hours小时$minutes分钟';
  }

  void _showOptions(BuildContext context) {
    showGlassSheet(
      context,
      // SafeArea 与拖拽把手由 GlassSheet 统一提供
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Text(
              task.title,
              style: AppText.h3.copyWith(color: AppColors.textPrimary),
            ),
          ),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(AppSpacing.xs),
              decoration: BoxDecoration(
                color: AppColors.primarySubtle,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Icon(
                Icons.edit_outlined,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            title: const Text('编辑任务'),
            onTap: () {
              Navigator.pop(context);
              onEdit();
            },
          ),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(AppSpacing.xs),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Icon(
                Icons.delete_outline,
                color: AppColors.error,
                size: 20,
              ),
            ),
            title: const Text('删除任务', style: TextStyle(color: AppColors.error)),
            onTap: () {
              Navigator.pop(context);
              onDelete();
            },
          ),
        ],
      ),
    );
  }
}
