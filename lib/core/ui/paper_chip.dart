import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 可选中的纸面 chip。
///
/// 静止时是「细线描边的空框」，选中时整个翻成墨底纸字——编辑风里
/// 的表单选择件（时段、计时类型）。
///
/// - [vertical] true → 图标在上、文字在下（上午/下午/晚上时段选择）
/// - [vertical] false → 图标在左、文字在右（正计时/倒计时选择）
///
/// 注意：`expanded: true`（默认）时本组件直接返回 `Expanded`，
/// 因此**必须**作为 `Row` / `Column` 的直接子项使用。
/// （Expanded 是 ParentDataWidget、必须是 Flex 直接子节点——
/// v1.3.2 那个 release 灰方块 bug 的教训，见 git 历史。）
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
    final Color fg = selected ? AppColors.textOnInk : AppColors.textSecondary;

    final List<Widget> children = vertical
        ? <Widget>[
            Icon(icon, size: 22, color: fg),
            const SizedBox(height: 6),
            Text(label!, style: _labelStyle(fg)),
          ]
        : <Widget>[
            Icon(icon, size: 18, color: fg),
            const SizedBox(width: 6),
            Text(label!, style: _labelStyle(fg)),
          ];

    final Widget chip = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      padding:
          padding ??
          (vertical
              ? const EdgeInsets.symmetric(vertical: AppSpacing.md)
              : const EdgeInsets.symmetric(vertical: AppSpacing.sm)),
      decoration: BoxDecoration(
        color: selected ? AppColors.textPrimary : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: selected
              ? AppColors.textPrimary
              // 描边用 30% 墨：比发丝线重一档，框出可点区域但不抢戏
              : AppColors.textPrimary.withValues(alpha: 0.3),
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

    final Widget tappable = GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: chip,
    );

    return expanded ? Expanded(child: tappable) : tappable;
  }

  TextStyle _labelStyle(Color color) => TextStyle(
    fontSize: 13,
    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
    color: color,
  );
}
