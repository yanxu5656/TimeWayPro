import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 一个分段选项。
class Segment<T> {
  const Segment(this.value, this.label);

  final T value;
  final String label;
}

/// 下划线分段控件（编辑风的页签）。
///
/// 玻璃版是「底色块 + 滑动指示块」；纸面版换成**目录页语言**：
/// 等宽文字 + 选中项下方的朱砂短线。选中的文字加粗变墨色，
/// 未选中是灰的——字重和颜色一起表达层级，不靠底色。
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
    return Row(
      children: <Widget>[
        for (final Segment<T> segment in segments)
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(segment.value),
              behavior: HitTestBehavior.opaque,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: AnimatedDefaultTextStyle(
                      duration: duration,
                      curve: Curves.easeOutCubic,
                      // 未选中用 textSecondary 而不是 textHint：
                      // 这是 13px 且可点的语义文字，textHint（2.7:1）
                      // 按对比度规则不得用于此（v1.5.0 迁移时误降过）
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: segment.value == value
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: segment.value == value
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                      child: Text(
                        segment.label,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  // 朱砂短线：高度恒定，避免切换时下方内容跳动
                  AnimatedContainer(
                    duration: duration,
                    curve: Curves.easeOutCubic,
                    height: 2,
                    color: segment.value == value
                        ? AppColors.primary
                        : Colors.transparent,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
