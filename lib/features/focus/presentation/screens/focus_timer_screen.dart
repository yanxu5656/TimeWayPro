import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/ui/paper.dart';
import '../../providers/focus_timer_provider.dart';

/// 全局悬浮专注计时页：45 分钟专注 -> 持续振动闹铃提醒 -> 5 分钟休息循环。
class FocusTimerScreen extends StatelessWidget {
  const FocusTimerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final FocusTimerProvider timer = context.watch<FocusTimerProvider>();

    return PaperScaffold(
      title: '专注计时',
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenH,
          AppSpacing.md,
          AppSpacing.screenH,
          AppSpacing.xxl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _PhaseHeaderCard(timer: timer),
            const SizedBox(height: AppSpacing.md),
            _DialCard(timer: timer),
            const SizedBox(height: AppSpacing.md),
            _PrimaryControls(timer: timer),
            const SizedBox(height: AppSpacing.md),
            _CycleAndAlarmCard(timer: timer),
          ],
        ),
      ),
    );
  }
}

class _PhaseHeaderCard extends StatelessWidget {
  const _PhaseHeaderCard({required this.timer});

  final FocusTimerProvider timer;

  @override
  Widget build(BuildContext context) {
    final ({String badge, String title, String subtitle, Color tint}) meta =
        _phaseMeta(timer);

    return PaperCard(
      tone: PaperTone.row,
      tint: meta.tint == AppColors.textSecondary ? null : meta.tint,
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xxs + 2,
            ),
            decoration: BoxDecoration(
              color: meta.tint.withValues(alpha: 0.12),
              borderRadius: AppRadius.brFull,
            ),
            child: Text(
              meta.badge,
              style: AppText.label.copyWith(color: meta.tint),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  meta.title,
                  style: AppText.titleSm.copyWith(color: AppColors.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  meta.subtitle,
                  style: AppText.bodySm.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  ({String badge, String title, String subtitle, Color tint}) _phaseMeta(
    FocusTimerProvider t,
  ) {
    switch (t.phase) {
      case FocusPhase.idle:
        return (
          badge: '待开始',
          title: '45 分钟专注 · 5 分钟休息',
          subtitle: '倒计时结束后通过手机持续振动闹铃提醒休息',
          tint: AppColors.textSecondary,
        );
      case FocusPhase.focusing:
        return (
          badge: t.isPaused ? '已暂停' : '专注中',
          title: '保持心流，专注当下',
          subtitle: t.isPaused ? '点击「继续专注」恢复倒计时' : '满 45 分钟后将持续振动提醒你休息 5 分钟',
          tint: AppColors.primary,
        );
      case FocusPhase.focusAlarm:
        return (
          badge: '闹铃中',
          title: '45 分钟专注时间到',
          subtitle: '手机正在持续振动闹铃，建议起身放松眼睛并休息 5 分钟',
          tint: AppColors.error,
        );
      case FocusPhase.breaking:
        return (
          badge: t.isPaused ? '休息暂停' : '休息中',
          title: '喝口水、远眺放松一下',
          subtitle: t.isPaused ? '点击「继续休息」恢复 5 分钟倒计时' : '5 分钟休息结束后将提醒你开始下一轮专注',
          tint: AppColors.success,
        );
      case FocusPhase.breakAlarm:
        return (
          badge: '闹铃中',
          title: '5 分钟休息已结束',
          subtitle: '手机正在持续振动闹铃，准备好就可以开启下一轮 45 分钟专注',
          tint: AppColors.error,
        );
    }
  }
}

class _DialCard extends StatelessWidget {
  const _DialCard({required this.timer});

  final FocusTimerProvider timer;

  @override
  Widget build(BuildContext context) {
    final Color ringColor = switch (timer.phase) {
      FocusPhase.idle => AppColors.primary,
      FocusPhase.focusing => AppColors.primary,
      FocusPhase.focusAlarm => AppColors.error,
      FocusPhase.breaking => AppColors.success,
      FocusPhase.breakAlarm => AppColors.error,
    };

    final String phaseLabel = switch (timer.phase) {
      FocusPhase.idle => '准备专注',
      FocusPhase.focusing => timer.isPaused ? '专注已暂停' : '专注倒计时',
      FocusPhase.focusAlarm => '专注完成 · 闹铃提醒中',
      FocusPhase.breaking => timer.isPaused ? '休息已暂停' : '休息倒计时',
      FocusPhase.breakAlarm => '休息结束 · 闹铃提醒中',
    };

    final int focusMinutes = math.max(1, timer.focusDurationSeconds ~/ 60);
    final int breakMinutes = math.max(1, timer.breakDurationSeconds ~/ 60);

    return PaperCard(
      tone: PaperTone.row,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xl,
      ),
      child: Column(
        children: <Widget>[
          SizedBox(
            width: 224,
            height: 224,
            child: CustomPaint(
              painter: _DialPainter(
                progress: timer.isAlarming ? 1.0 : timer.progress,
                ringColor: ringColor,
                trackColor: AppColors.surfaceVariant,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      phaseLabel,
                      style: AppText.label.copyWith(color: ringColor),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      timer.formattedRemaining,
                      style: AppText.serifNum.copyWith(
                        fontSize: 48,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '已完成 ${timer.completedRounds} 轮',
                      style: AppText.bodySm.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              _InfoPill(
                icon: Icons.center_focus_strong_rounded,
                label: '专注 $focusMinutes 分钟',
              ),
              _InfoPill(
                icon: Icons.coffee_rounded,
                label: '休息 $breakMinutes 分钟',
              ),
              const _InfoPill(
                icon: Icons.vibration_rounded,
                label: '持续振动闹铃',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs + 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: AppRadius.brFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            label,
            style: AppText.bodySm.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _PrimaryControls extends StatelessWidget {
  const _PrimaryControls({required this.timer});

  final FocusTimerProvider timer;

  @override
  Widget build(BuildContext context) {
    if (timer.isAlarming) {
      final bool isFocusDone = timer.phase == FocusPhase.focusAlarm;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ElevatedButton.icon(
            onPressed: isFocusDone ? timer.startBreak : timer.startFocus,
            icon: Icon(
              isFocusDone ? Icons.coffee_rounded : Icons.play_arrow_rounded,
            ),
            label: Text(
              isFocusDone ? '关闭闹铃 · 开始休息 5 分钟' : '关闭闹铃 · 开始下一轮专注',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: timer.dismissAlarm,
            icon: const Icon(Icons.notifications_off_rounded),
            label: const Text('仅关闭闹铃'),
          ),
        ],
      );
    }

    switch (timer.phase) {
      case FocusPhase.idle:
        return ElevatedButton.icon(
          onPressed: timer.startFocus,
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('开始 45 分钟专注'),
        );
      case FocusPhase.focusing:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: timer.isPaused ? timer.resume : timer.pause,
                    icon: Icon(
                      timer.isPaused
                          ? Icons.play_arrow_rounded
                          : Icons.pause_rounded,
                    ),
                    label: Text(timer.isPaused ? '继续专注' : '暂停'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: timer.startBreak,
                    icon: const Icon(Icons.coffee_rounded),
                    label: const Text('立即休息'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            TextButton.icon(
              onPressed: timer.stop,
              icon: const Icon(Icons.stop_rounded, color: AppColors.error),
              label: const Text(
                '结束本轮专注',
                style: TextStyle(color: AppColors.error),
              ),
            ),
          ],
        );
      case FocusPhase.breaking:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: timer.isPaused ? timer.resume : timer.pause,
                    icon: Icon(
                      timer.isPaused
                          ? Icons.play_arrow_rounded
                          : Icons.pause_rounded,
                    ),
                    label: Text(timer.isPaused ? '继续休息' : '暂停'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: timer.startFocus,
                    icon: const Icon(Icons.skip_next_rounded),
                    label: const Text('跳过休息'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            TextButton.icon(
              onPressed: timer.stop,
              icon: const Icon(Icons.stop_rounded, color: AppColors.error),
              label: const Text(
                '结束专注循环',
                style: TextStyle(color: AppColors.error),
              ),
            ),
          ],
        );
      case FocusPhase.focusAlarm:
      case FocusPhase.breakAlarm:
        return const SizedBox.shrink();
    }
  }
}

class _CycleAndAlarmCard extends StatelessWidget {
  const _CycleAndAlarmCard({required this.timer});

  final FocusTimerProvider timer;

  @override
  Widget build(BuildContext context) {
    return PaperCard(
      tone: PaperTone.ruled,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '节奏说明与闹铃测试',
            style: AppText.titleSm.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '• 每专注 45 分钟，自动拉响持续振动与闹钟铃声提醒，直到你手动关闭或进入休息。\n'
            '• 休息倒计时固定 5 分钟，结束后同样通过持续振动提醒开启下一轮。',
            style: AppText.bodySm.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: timer.isAlarming ? null : timer.toggleTestAlarm,
              icon: Icon(
                timer.isTestingAlarm
                    ? Icons.stop_circle_outlined
                    : Icons.vibration_rounded,
              ),
              label: Text(timer.isTestingAlarm ? '停止测试闹铃' : '试听持续振动闹铃'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  const _DialPainter({
    required this.progress,
    required this.ringColor,
    required this.trackColor,
  });

  final double progress;
  final Color ringColor;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    const double strokeWidth = 10;
    final Offset center = size.center(Offset.zero);
    final double radius = (math.min(size.width, size.height) - strokeWidth) / 2;

    final Paint trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    if (progress <= 0) return;

    final Paint ringPaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      ringPaint,
    );
  }

  @override
  bool shouldRepaint(_DialPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.ringColor != ringColor ||
        oldDelegate.trackColor != trackColor;
  }
}
