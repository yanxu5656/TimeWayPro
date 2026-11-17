import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'pressable_scale.dart';

/// 可选中的纸面 chip。
///
/// 静止时是「细线描边的空框」，选中时整个翻成陶土底暖白字——
/// 表单里的选择件（时段、计时类型），选中态与主操作同色。
///
/// - [vertical] true → 图标在上、文字在下（上午/下午/晚上时段选择）
/// - [vertical] false → 图标在左、文字在右（正计时/倒计时选择）
///
/// v1.9.0：按下有回弹（[PressableScale]），翻色走 easeOutCubic，
/// 选中瞬间图标做一次小小的弹跳——「选上了」这件事有实体反馈。
///
/// 注意：`expanded: true`（默认）时本组件直接返回 `Expanded`，
/// 因此**必须**作为 `Row` / `Column` 的直接子项使用。
/// （Expanded 是 ParentDataWidget、必须是 Flex 直接子节点——
/// v1.3.2 那个 release 灰方块 bug 的教训，见 git 历史。
/// 回弹包装放在 Expanded **里面**，别反过来。）
class PaperChip extends StatelessWidget {
  const PaperChip({
    super.key,
    this.label,
    this.icon,
    required this.selected,
    required this.onTap,
    this.expanded = true,
    this.vertical = false,
    this.padding,
  });

  final String? label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;
  final bool expanded;
  final bool vertical;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final bool reduced =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final Color fg = selected
        ? AppColors.textOnPrimary
        : AppColors.textSecondary;

    // 选中瞬间图标从 0.85 弹回 1（easeOutBack 带一点过冲）。
    // key 挂在 selected 上：每次翻面都重新起跳，静止时恒为 1。
    Widget bounceIcon(double size) => TweenAnimationBuilder<double>(
      key: ValueKey<bool>(selected),
      tween: Tween<double>(begin: selected ? 0.85 : 1.0, end: 1.0),
      duration: reduced ? Duration.zero : const Duration(milliseconds: 240),
      curve: Curves.easeOutBack,
      builder: (BuildContext context, double scale, Widget? child) =>
          Transform.scale(scale: scale, child: child),
      child: Icon(icon, size: size, color: fg),
    );

    final List<Widget> children = vertical
        ? <Widget>[
            bounceIcon(22),
            const SizedBox(height: 6),
            Text(label!, style: _labelStyle(fg)),
          ]
        : <Widget>[
            bounceIcon(18),
            const SizedBox(width: 6),
            Text(label!, style: _labelStyle(fg)),
          ];

    final Widget chip = AnimatedContainer(
      duration: reduced ? Duration.zero : const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding:
          padding ??
          (vertical
              ? const EdgeInsets.symmetric(vertical: AppSpacing.md)
              : const EdgeInsets.symmetric(vertical: AppSpacing.sm)),
      decoration: BoxDecoration(
        color: selected ? AppColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: selected
              ? AppColors.primary
              // 描边用 30% 陶土：比发丝线重一档，框出可点区域但不抢戏
              : AppColors.primary.withValues(alpha: 0.3),
          width: 1.2,
        ),
      ),
      child: vertical
          ? Column(mainAxisSize: MainAxisSize.min, children: children)
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: children,
            ),
    );

    final Widget tappable = PressableScale(
      scale: 0.97,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: chip,
      ),
    );

    return expanded ? Expanded(child: tappable) : tappable;
  }

  TextStyle _labelStyle(Color color) => TextStyle(
    fontSize: 13,
    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
    color: color,
  );
}