import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 可选中的玻璃 chip。
///
/// 取代改造前**三处**自绘实现，其中 daily_screen 里的两份
/// `_buildPeriodChip` 是逐字重复的代码。
///
/// - [vertical] true → 图标在上、文字在下（上午/下午/晚上时段选择）
/// - [vertical] false → 图标在左、文字在右（正计时/倒计时选择）
///
/// 注意：`expanded: true`（默认）时本组件直接返回 `Expanded`，
/// 因此**必须**作为 `Row` / `Column` 的直接子项使用。这沿用了改造前
/// `_buildChoiceChip` / `_buildPeriodChip` 的用法约定。
class GlassChip extends StatelessWidget {
  const GlassChip({
    super.key,
    this.label,
    this.icon,
    required this.selected,
    required this.onTap,
    this.tint = AppColors.primary,
    this.expanded = true,
    this.vertical = false,
    this.padding,
  });

  final String? label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;
  final Color tint;
  final bool expanded;
  final bool vertical;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final Color fg = selected ? tint : AppColors.textSecondary;
    final Color iconFg = selected ? tint : AppColors.textHint;

    final List<Widget> children = vertical
        ? <Widget>[
            Icon(icon, size: 22, color: iconFg),
            const SizedBox(height: 6),
            Text(label!, style: _labelStyle(fg)),
          ]
        : <Widget>[
            Icon(icon, size: 18, color: iconFg),
            const SizedBox(width: 6),
            Text(label!, style: _labelStyle(fg)),
          ];

    final Widget chip = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      padding: padding ??
          (vertical
              ? const EdgeInsets.symmetric(vertical: 14)
              : const EdgeInsets.symmetric(vertical: 12)),
      decoration: BoxDecoration(
        color: selected ? tint.withValues(alpha: 0.15) : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(vertical ? 14 : AppRadius.md),
        border: Border.all(
          color: selected ? tint : Colors.transparent,
          width: selected ? 2 : 1,
        ),
      ),
      child: vertical
          ? Column(mainAxisSize: MainAxisSize.min, children: children)
          : Row(mainAxisAlignment: MainAxisAlignment.center, children: children),
    );

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: expanded ? Expanded(child: chip) : chip,
    );
  }

  TextStyle _labelStyle(Color color) => TextStyle(
        fontSize: 13,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        color: color,
      );
}