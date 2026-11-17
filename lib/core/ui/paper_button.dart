/// 纸感按钮家族（v1.9.0）。
///
/// 三个包装件把「按下回弹 + 下沉 + 暖涟漪 + 文案形变」统一到所有
/// 主/次/文字按钮上。内部**仍然是真正的 Material 按钮**——
/// 语义、主题、既有测试的 `find.widgetWithText(ElevatedButton, …)`
/// 全部不受影响，包装件只负责手感：
///
/// - 按压：[PressableScale] 缩放 0.97 + 向桌面下沉 1.5px，
///   松手 easeOutBack 回弹（纸被压下去又弹回来）
/// - 涟漪：陶土底上用暖白涟漪、纸底上用陶土涟漪，替代默认灰波纹
/// - 形变：文案 / 图标切换走 180ms 交叉淡入 + 微位移，不再瞬切
/// - 等待：[PaperButton.loading] 内嵌小进度环并禁用点击，
///   异步操作期间按钮自己说明「正在处理」
library;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'pressable_scale.dart';

/// 文案形变：值变化时交叉淡入 + 轻微上移。
class _MorphLabel extends StatelessWidget {
  const _MorphLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.3),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: Text(text, key: ValueKey<String>(text)),
    );
  }
}

/// 图标形变：图标变化时交叉淡入 + 缩放弹出。
class _MorphIcon extends StatelessWidget {
  const _MorphIcon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.7, end: 1).animate(animation),
            child: child,
          ),
        );
      },
      child: Icon(icon, key: ValueKey<IconData>(icon)),
    );
  }
}

/// 主按钮：整块陶土（或调用方指定的底色）+ 暖白文字。
class PaperButton extends StatelessWidget {
  const PaperButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.loading = false,
    this.loadingLabel,
    this.backgroundColor,
    this.foregroundColor,
    this.padding,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// 异步操作进行中：内嵌进度环、禁用点击。
  final bool loading;

  /// loading 时替换的文案（不给则沿用 [label]）。
  final String? loadingLabel;

  final Color? backgroundColor;
  final Color? foregroundColor;
  final EdgeInsetsGeometry? padding;

  /// 紧凑档：横幅、弹窗行内这类小按钮。
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null && !loading;
    final Color fg = foregroundColor ?? AppColors.textOnPrimary;

    final List<Widget> children = <Widget>[
      if (loading)
        SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: fg),
        )
      else if (icon != null)
        _MorphIcon(icon!),
      if (loading || icon != null) const SizedBox(width: AppSpacing.xs),
      Flexible(child: _MorphLabel(loading ? (loadingLabel ?? label) : label)),
    ];

    final Widget button = ElevatedButton(
      onPressed: enabled ? onPressed : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        disabledBackgroundColor: AppColors.inkSubtle,
        disabledForegroundColor: AppColors.textHint,
        overlayColor: fg.withValues(alpha: 0.18),
        padding:
            padding ??
            (compact
                ? const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  )
                : null),
        minimumSize: compact ? const Size(0, 36) : null,
        tapTargetSize: compact
            ? MaterialTapTargetSize.shrinkWrap
            : MaterialTapTargetSize.padded,
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );

    return PressableScale(
      enabled: enabled,
      scale: 0.97,
      pressOffset: 1.5,
      child: button,
    );
  }
}

/// 次按钮：陶土细描边的空框，纸面上的第二操作。
class PaperOutlinedButton extends StatelessWidget {
  const PaperOutlinedButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.foregroundColor,
    this.padding,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? foregroundColor;
  final EdgeInsetsGeometry? padding;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final Color fg = foregroundColor ?? AppColors.primary;

    final List<Widget> children = <Widget>[
      if (icon != null) ...<Widget>[
        _MorphIcon(icon!),
        const SizedBox(width: AppSpacing.xs),
      ],
      Flexible(child: _MorphLabel(label)),
    ];

    final Widget button = OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: foregroundColor,
        overlayColor: fg.withValues(alpha: 0.10),
        padding:
            padding ??
            (compact
                ? const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  )
                : null),
        minimumSize: compact ? const Size(0, 36) : null,
        tapTargetSize: compact
            ? MaterialTapTargetSize.shrinkWrap
            : MaterialTapTargetSize.padded,
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );

    return PressableScale(
      enabled: onPressed != null,
      scale: 0.97,
      pressOffset: 1.2,
      child: button,
    );
  }
}

/// 文字按钮：弹窗动作、行内轻操作。
class PaperTextButton extends StatelessWidget {
  const PaperTextButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.color,
    this.padding,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// 前景色（删除动作传 [AppColors.error]）。
  final Color? color;
  final EdgeInsetsGeometry? padding;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final Color fg = color ?? AppColors.primary;

    final List<Widget> children = <Widget>[
      if (icon != null) ...<Widget>[
        _MorphIcon(icon!),
        const SizedBox(width: AppSpacing.xxs),
      ],
      Flexible(child: _MorphLabel(label)),
    ];

    final Widget button = TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: color,
        overlayColor: fg.withValues(alpha: 0.10),
        padding:
            padding ??
            (compact
                ? const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                    vertical: AppSpacing.xxs,
                  )
                : null),
        minimumSize: compact ? Size.zero : null,
        tapTargetSize: compact
            ? MaterialTapTargetSize.shrinkWrap
            : MaterialTapTargetSize.padded,
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );

    return PressableScale(
      enabled: onPressed != null,
      scale: 0.96,
      pressOffset: 0.8,
      child: button,
    );
  }
}