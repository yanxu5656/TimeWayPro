import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_haptics.dart';
import 'glass_surface.dart';

/// 一个分段选项。
class Segment<T> {
  const Segment(this.value, this.label);

  final T value;
  final String label;
}

/// 下划线分段控件（编辑风的页签）。
///
/// 玻璃版是「底色块 + 滑动指示块」；纸面版换成**目录页语言**：
/// 等宽文字 + 选中项下方的陶土短线。选中的文字加粗变墨色，
/// 未选中是灰的——字重和颜色一起表达层级，不靠底色。
///
/// v1.9.0：陶土短线不再各自淡入淡出，而是**一整条滑过去**
/// （AnimatedPositioned），切换时段/周期时视线能跟着线走；
/// 落定伴随一次轻触觉。
class SegmentedControl<T> extends StatelessWidget {
  const SegmentedControl({
    super.key,
    required this.segments,
    required this.value,
    required this.onChanged,
    this.duration = const Duration(milliseconds: 260),
  });

  final List<Segment<T>> segments;
  final T value;
  final ValueChanged<T> onChanged;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final bool reduced =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final Duration effectiveDuration = reduced ? Duration.zero : duration;

    int index = segments.indexWhere((Segment<T> s) => s.value == value);
    if (index < 0) index = 0;

    if (context.isGlass) {
      return GlassSurface(
        borderRadius: BorderRadius.circular(28),
        blur: true,
        shadow: true,
        rimColor: context.colors.primary,
        padding: const EdgeInsets.all(4),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double width = constraints.maxWidth / segments.length;
            return SizedBox(
              height: 42,
              child: Stack(
                children: <Widget>[
                  AnimatedPositioned(
                    duration: effectiveDuration,
                    curve: Curves.easeOutCubic,
                    left: index * width,
                    top: 0,
                    bottom: 0,
                    width: width,
                    child: GlassSurface(
                      borderRadius: BorderRadius.circular(23),
                      gradient: <Color>[
                        Color.lerp(context.colors.primary, Colors.black, 0.2)!,
                        context.colors.primary,
                        Color.lerp(
                          context.colors.primary,
                          context.colors.accent,
                          0.78,
                        )!,
                      ],
                      blur: false,
                      shadow: true,
                      padding: EdgeInsets.zero,
                      child: const SizedBox.expand(),
                    ),
                  ),
                  Row(
                    children: <Widget>[
                      for (final Segment<T> segment in segments)
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              if (segment.value != value) AppHaptics.select();
                              onChanged(segment.value);
                            },
                            child: Center(
                              child: AnimatedDefaultTextStyle(
                                duration: effectiveDuration,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: segment.value == value
                                      ? context.colors.textOnPrimary
                                      : context.colors.textSecondary,
                                ),
                                child: Text(segment.label),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      );
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double segWidth = constraints.maxWidth / segments.length;
        return Stack(
          children: <Widget>[
            Row(
              children: <Widget>[
                for (final Segment<T> segment in segments)
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (segment.value != value) AppHaptics.select();
                        onChanged(segment.value);
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: AnimatedDefaultTextStyle(
                              duration: effectiveDuration,
                              curve: Curves.easeOutCubic,
                              // 未选中用 textSecondary 而不是 textHint：
                              // 这是 13px 且可点的语义文字，textHint（2.7:1）
                              // 按对比度规则不得用于此（v1.5.0 迁移时误降过）
                              style: TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 13,
                                fontWeight: segment.value == value
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: segment.value == value
                                    ? context.colors.textPrimary
                                    : context.colors.textSecondary,
                              ),
                              child: Text(
                                segment.label,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          // 占位保持行高恒定，真正的线在 Stack 层滑动
                          const SizedBox(height: 2),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            AnimatedPositioned(
              duration: effectiveDuration,
              curve: Curves.easeOutCubic,
              left: index * segWidth,
              bottom: 0,
              width: segWidth,
              height: 2,
              child: ColoredBox(color: context.colors.primary),
            ),
          ],
        );
      },
    );
  }
}
