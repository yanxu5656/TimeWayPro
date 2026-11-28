import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/ui/paper.dart';
import '../../providers/focus_timer_provider.dart';
import '../../services/focus_alarm_service.dart';

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
        _phaseMeta(context, timer);

    return PaperCard(
      tone: PaperTone.row,
      tint: meta.tint == context.colors.textSecondary ? null : meta.tint,
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
                  style: AppText.titleSm.copyWith(
                    color: context.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  meta.subtitle,
                  style: AppText.bodySm.copyWith(
                    color: context.colors.textSecondary,
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
    BuildContext context,
    FocusTimerProvider t,
  ) {
    switch (t.phase) {
      case FocusPhase.idle:
        return (
          badge: '待开始',
          title: '45 分钟专注 · 5 分钟休息',
          subtitle: '倒计时结束后通过手机持续振动闹铃提醒休息',
          tint: context.colors.textSecondary,
        );
      case FocusPhase.focusing:
        return (
          badge: t.isPaused ? '已暂停' : '专注中',
          title: '保持心流，专注当下',
          subtitle: t.isPaused ? '点击「继续专注」恢复倒计时' : '满 45 分钟后将持续振动提醒你休息 5 分钟',
          tint: context.colors.primary,
        );
      case FocusPhase.focusAlarm:
        return (
          badge: '闹铃中',
          title: '45 分钟专注时间到',
          subtitle: '手机正在持续振动闹铃，建议起身放松眼睛并休息 5 分钟',
          tint: context.colors.error,
        );
      case FocusPhase.breaking:
        return (
          badge: t.isPaused ? '休息暂停' : '休息中',
          title: '喝口水、远眺放松一下',
          subtitle: t.isPaused ? '点击「继续休息」恢复 5 分钟倒计时' : '5 分钟休息结束后将提醒你开始下一轮专注',
          tint: context.colors.success,
        );
      case FocusPhase.breakAlarm:
        return (
          badge: '闹铃中',
          title: '5 分钟休息已结束',
          subtitle: '手机正在持续振动闹铃，准备好就可以开启下一轮 45 分钟专注',
          tint: context.colors.error,
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
      FocusPhase.idle => context.colors.primary,
      FocusPhase.focusing => context.colors.primary,
      FocusPhase.focusAlarm => context.colors.error,
      FocusPhase.breaking => context.colors.success,
      FocusPhase.breakAlarm => context.colors.error,
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
                trackColor: context.colors.surfaceVariant,
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
                      style: context.text.serifNum.copyWith(
                        fontSize: 48,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '已完成 ${timer.completedRounds} 轮',
                      style: AppText.bodySm.copyWith(
                        color: context.colors.textSecondary,
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
              _InfoPill(
                icon: timer.alarmMode == FocusAlarmMode.vibrationOnly
                    ? Icons.vibration_rounded
                    : Icons.notifications_active_rounded,
                label: timer.alarmMode == FocusAlarmMode.vibrationOnly
                    ? '仅振动闹铃'
                    : '响铃 + 振动闹铃',
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
        color: context.colors.surfaceVariant,
        borderRadius: AppRadius.brFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: context.colors.textSecondary),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            label,
            style: AppText.bodySm.copyWith(color: context.colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _PrimaryControls extends StatefulWidget {
  const _PrimaryControls({required this.timer});

  final FocusTimerProvider timer;

  @override
  State<_PrimaryControls> createState() => _PrimaryControlsState();
}

class _PrimaryControlsState extends State<_PrimaryControls> {
  /// 「开始专注」要先过电池优化引导（异步平台通道），期间按钮
  /// 自己显示进度环，而不是点了没反应。
  bool _starting = false;

  FocusTimerProvider get timer => widget.timer;

  Future<void> _start() async {
    setState(() => _starting = true);
    try {
      await _startFocusWithBatteryCheck(context, timer);
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (timer.isAlarming) {
      final bool isFocusDone = timer.phase == FocusPhase.focusAlarm;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          PaperButton(
            onPressed: isFocusDone ? timer.startBreak : timer.startFocus,
            icon: isFocusDone ? Icons.coffee_rounded : Icons.play_arrow_rounded,
            label: isFocusDone ? '关闭闹铃 · 开始休息 5 分钟' : '关闭闹铃 · 开始下一轮专注',
          ),
          const SizedBox(height: AppSpacing.sm),
          PaperOutlinedButton(
            onPressed: () {
              AppHaptics.dismiss();
              timer.dismissAlarm();
            },
            icon: Icons.notifications_off_rounded,
            label: '仅关闭闹铃',
          ),
        ],
      );
    }

    switch (timer.phase) {
      case FocusPhase.idle:
        return PaperButton(
          onPressed: _start,
          loading: _starting,
          loadingLabel: '正在准备…',
          icon: Icons.play_arrow_rounded,
          label: '开始 45 分钟专注',
        );
      case FocusPhase.focusing:
        return _runningControls(
          resumeLabel: '继续专注',
          secondaryLabel: '立即休息',
          secondaryIcon: Icons.coffee_rounded,
          onSecondary: timer.startBreak,
          stopLabel: '结束本轮专注',
        );
      case FocusPhase.breaking:
        return _runningControls(
          resumeLabel: '继续休息',
          secondaryLabel: '跳过休息',
          secondaryIcon: Icons.skip_next_rounded,
          onSecondary: timer.startFocus,
          stopLabel: '结束专注循环',
        );
      case FocusPhase.focusAlarm:
      case FocusPhase.breakAlarm:
        return const SizedBox.shrink();
    }
  }

  Widget _runningControls({
    required String resumeLabel,
    required String secondaryLabel,
    required IconData secondaryIcon,
    required VoidCallback onSecondary,
    required String stopLabel,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: PaperButton(
                onPressed: timer.isPaused ? timer.resume : timer.pause,
                icon: timer.isPaused
                    ? Icons.play_arrow_rounded
                    : Icons.pause_rounded,
                label: timer.isPaused ? resumeLabel : '暂停',
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: PaperOutlinedButton(
                onPressed: onSecondary,
                icon: secondaryIcon,
                label: secondaryLabel,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        PaperTextButton(
          onPressed: timer.stop,
          icon: Icons.stop_rounded,
          color: context.colors.error,
          label: stopLabel,
        ),
      ],
    );
  }
}

/// 首次开始专注前引导关闭电池优化，避免国产 ROM 后台查杀导致闹铃不响。
Future<void> _startFocusWithBatteryCheck(
  BuildContext context,
  FocusTimerProvider timer,
) async {
  if (await timer.needsBatteryOptimizationPrompt()) {
    if (!context.mounted) return;
    final bool? goSettings = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => PaperAlertDialog(
        title: const Text('让闹铃锁屏后也准时响'),
        content: const Text(
          '为确保专注到点时即使锁屏、退出应用也能准时提醒：\n\n'
          '1. 点「去设置」后，系统会询问是否允许时途忽略电池优化，请选择允许；\n'
          '2. 小米 / 华为 / OPPO / vivo 等手机，还请在本机「手机管家」中为时途开启自启动权限。',
        ),
        actions: <Widget>[
          PaperTextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            label: '暂不',
          ),
          PaperButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            compact: true,
            label: '去设置',
          ),
        ],
      ),
    );
    await timer.markBatteryPromptShown();
    if (goSettings == true) {
      await timer.requestIgnoreBatteryOptimizations();
    }
  }
  await timer.startFocus();
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
            style: AppText.titleSm.copyWith(color: context.colors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '• 计时期间通知栏常驻倒计时，锁屏、退出应用后到点依然准时响铃，直到你手动关闭或进入休息。\n'
            '• 休息倒计时固定 5 分钟，结束后同样提醒开启下一轮。',
            style: AppText.bodySm.copyWith(color: context.colors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '闹铃模式',
            style: AppText.label.copyWith(color: context.colors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xxs),
          SegmentedControl<FocusAlarmMode>(
            segments: const <Segment<FocusAlarmMode>>[
              Segment(FocusAlarmMode.soundAndVibration, '响铃 + 振动'),
              Segment(FocusAlarmMode.vibrationOnly, '仅振动'),
            ],
            value: timer.alarmMode,
            onChanged: timer.setAlarmMode,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            timer.alarmMode == FocusAlarmMode.vibrationOnly
                ? '只振动不响铃，适合会议、课堂、图书馆等安静场合。'
                : '闹钟铃声加持续振动，提醒效果最强。',
            style: AppText.bodySm.copyWith(color: context.colors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: PaperOutlinedButton(
              onPressed: timer.isAlarming ? null : timer.toggleTestAlarm,
              icon: timer.isTestingAlarm
                  ? Icons.stop_circle_outlined
                  : Icons.vibration_rounded,
              label: timer.isTestingAlarm ? '停止测试闹铃' : '试听持续振动闹铃',
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
