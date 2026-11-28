import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/ui/paper.dart';
import '../../providers/focus_timer_provider.dart';

/// 全局悬浮专注入口：显示在每个 Tab 页面表层左下角，支持拖拽移动位置，
/// 点击进入 [FocusTimerScreen]（避免使用 PaperFab 类型以保持页面主 FAB 唯一）。
class FocusTimerFab extends StatelessWidget {
  const FocusTimerFab({super.key, required this.onTap, this.onDragDelta});

  final VoidCallback onTap;
  final ValueChanged<Offset>? onDragDelta;

  @override
  Widget build(BuildContext context) {
    final FocusTimerProvider timer = context.watch<FocusTimerProvider>();

    final Color bgColor;
    final Color fgColor;
    final IconData icon;
    final String label;

    if (timer.isAlarming) {
      bgColor = context.colors.error;
      fgColor = context.colors.textOnPrimary;
      icon = Icons.notifications_active_rounded;
      label = timer.phase == FocusPhase.focusAlarm ? '去休息' : '该专注';
    } else if (timer.isRunning) {
      bgColor = timer.phase == FocusPhase.breaking
          ? context.colors.success
          : context.colors.primary;
      fgColor = context.colors.textOnPrimary;
      icon = timer.phase == FocusPhase.breaking
          ? Icons.coffee_rounded
          : Icons.timer_rounded;
      label = timer.formattedRemaining;
    } else {
      bgColor = context.colors.surface;
      fgColor = context.colors.primary;
      icon = Icons.timer_outlined;
      label = '专注';
    }

    final bool glass = context.isGlass;
    Widget bubble = AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: glass ? Colors.transparent : bgColor,
        borderRadius: AppRadius.brFull,
        border: glass || timer.isActive
            ? null
            : Border.all(color: context.colors.primaryLight, width: 1.2),
        boxShadow: glass ? null : context.shape.floatShadows,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder: (Widget child, Animation<double> animation) =>
                FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.7, end: 1).animate(animation),
                    child: child,
                  ),
                ),
            child: Icon(
              icon,
              key: ValueKey<IconData>(icon),
              size: 19,
              color: fgColor,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: (timer.isRunning ? context.text.serifNum : AppText.labelLg)
                .copyWith(
                  fontSize: 14,
                  color: fgColor,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );

    if (glass) {
      bubble = GlassSurface(
        gradient: timer.isActive
            ? <Color>[
                Color.lerp(bgColor, Colors.black, 0.22)!,
                bgColor,
                Color.lerp(bgColor, context.colors.accent, 0.34)!,
              ]
            : null,
        fill: context.atmosphere.glassFill,
        rimColor: timer.isActive ? bgColor : context.colors.primary,
        blur: true,
        shadow: true,
        borderRadius: AppRadius.brFull,
        padding: EdgeInsets.zero,
        child: bubble,
      );
    }

    return GestureDetector(
      key: const Key('focus_timer_fab'),
      onTap: onTap,
      onPanUpdate: onDragDelta == null
          ? null
          : (DragUpdateDetails details) => onDragDelta!(details.delta),
      child: Tooltip(
        message: '45/5 专注计时（可拖动位置）',
        child: PressableScale(
          child: Semantics(
            button: true,
            label: '专注计时悬浮按钮：$label',
            child: bubble,
          ),
        ),
      ),
    );
  }
}
