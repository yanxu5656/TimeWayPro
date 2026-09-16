import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'glass_surface.dart';

/// 一个分段选项。
class Segment<T> {
  const Segment(this.value, this.label);

  final T value;
  final String label;
}

/// 带滑动指示块的分段控件。
///
/// 取代改造前统计页 `_buildPeriodTab` 的「只改背景色的 AnimatedContainer」——
/// 那种做法在切换时没有位置连续性，看不出"选中项从哪滑到哪"。
///
/// 这里用 `AnimatedPositioned` 让指示块真正滑动，是导航滑动指示器技术
/// 的第一个复用点。
class SegmentedControl<T> extends StatelessWidget {
  const SegmentedControl({
    super.key,
    required this.segments,
    required this.value,
    required this.onChanged,
    this.tint = AppColors.primary,
    this.duration = const Duration(milliseconds: 260),
  });

  final List<Segment<T>> segments;
  final T value;
  final ValueChanged<T> onChanged;
  final Color tint;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final int found = segments.indexWhere((Segment<T> s) => s.value == value);
    final int index = found < 0 ? 0 : found;

    return GlassSurface(
      radius: AppRadius.md,
      tone: GlassTone.subtle,
      padding: const EdgeInsets.all(4),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double segW = constraints.maxWidth / segments.length;

          return Stack(
            children: <Widget>[
              // 指示块。用 top/bottom 拉伸而非固定高度，这样不需要知道
              // 容器高度（在 ListView 里 maxHeight 是无穷大）。
              AnimatedPositioned(
                duration: duration,
                curve: Curves.easeOutCubic,
                left: index * segW,
                top: 0,
                bottom: 0,
                width: segW,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: tint,
                    borderRadius: BorderRadius.circular(AppRadius.sm + 1),
                    boxShadow: AppShadows.e1,
                  ),
                ),
              ),
              // 等宽的可点区域
              Row(
                children: <Widget>[
                  for (final Segment<T> segment in segments)
                    Expanded(
                      child: GestureDetector(
                        onTap: () => onChanged(segment.value),
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: AnimatedDefaultTextStyle(
                            duration: duration,
                            curve: Curves.easeOutCubic,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: segment.value == value
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: segment.value == value
                                  ? AppColors.textOnPrimary
                                  : AppColors.textSecondary,
                            ),
                            child: Text(
                              segment.label,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}