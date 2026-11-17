import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/ui/paper.dart';
import '../../providers/focus_timer_provider.dart';

/// 全局顶部闹铃横幅：当 45 分钟专注或 5 分钟休息到期响铃时，
/// 无论用户当前停留在哪个 Tab，都可以一键关闭闹铃并衔接下一阶段。
class FocusAlarmBanner extends StatelessWidget {
  const FocusAlarmBanner({
    super.key,
    required this.onOpenTimer,
  });

  final VoidCallback onOpenTimer;

  @override
  Widget build(BuildContext context) {
    final FocusTimerProvider timer = context.watch<FocusTimerProvider>();
    if (!timer.isAlarming) {
      return const SizedBox.shrink();
    }

    final bool isFocusDone = timer.phase == FocusPhase.focusAlarm;
    final String title = isFocusDone ? '45 分钟专注时间到！' : '5 分钟休息时间到！';
    final String actionText = isFocusDone ? '停铃并休息 5 分钟' : '停铃并开始专注';

    return Material(
      key: const Key('focus_alarm_banner'),
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.brCard,
          border: Border.all(color: AppColors.error, width: 1.5),
          boxShadow: AppShadows.e2,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(
                  Icons.notifications_active_rounded,
                  color: AppColors.error,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    title,
                    style: AppText.titleSm.copyWith(color: AppColors.error),
                  ),
                ),
                PaperTextButton(
                  onPressed: onOpenTimer,
                  compact: true,
                  label: '详情',
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: <Widget>[
                PaperButton(
                  onPressed: isFocusDone ? timer.startBreak : timer.startFocus,
                  backgroundColor: AppColors.error,
                  compact: true,
                  label: actionText,
                ),
                PaperOutlinedButton(
                  onPressed: () {
                    AppHaptics.dismiss();
                    timer.dismissAlarm();
                  },
                  compact: true,
                  label: '仅关闭闹铃',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
