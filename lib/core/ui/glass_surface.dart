import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'ui_effects.dart';

/// 玻璃填充的不透明度档位。
enum GlassTone {
  /// 62% —— 小表面、chip、顶栏、底部导航
  subtle,

  /// 78% —— 普通卡片
  regular,

  /// 91% —— 文字密集的卡片、对话框、底部弹窗
  strong,
}

extension GlassToneX on GlassTone {
  Color get fill => switch (this) {
    GlassTone.subtle => AppColors.glassFillWeak,
    GlassTone.regular => AppColors.glassFill,
    GlassTone.strong => AppColors.glassFillStrong,
  };

  /// 静置阴影。列表里的卡片只用 e1（blur 12 封顶）。
  List<BoxShadow> get shadows => switch (this) {
    GlassTone.subtle => const <BoxShadow>[],
    GlassTone.regular => AppShadows.e1,
    GlassTone.strong => AppShadows.e1,
  };
}

/// 描边的位置。
enum GlassEdge {
  /// 四周一圈渐变内高光（卡片、chip）
  ring,

  /// 只有上缘发丝线（底部弹窗、底部导航）
  top,

  /// 只有下缘发丝线（顶栏）
  bottom,

  /// 不画描边
  none,
}

/// 玻璃的视觉配方。
///
/// 所有玻璃组件的共同实现，避免同一套「渐变描边 + 半透明填充 + 阴影 +
/// 可选真模糊」在 8 个组件里各写一遍。
///
/// ## 为什么用渐变描边而不是 `Border.all(color: white)`
///
/// 均匀白环在白底区域完全不可见、在青绿区域才可见，看起来像"缺了一块"。
/// 左上 95% 白 → 右下 30% 白的渐变模拟"光从左上打来、上缘被照亮"，
/// 这才是玻璃质感的来源。
///
/// ## 为什么列表卡片不开 [blurSigma]
///
/// `BackdropFilter` 是一次 GPU 高斯模糊 pass。滚动列表里十几张卡同时模糊，
/// minSdk 24 的中低端机大概率掉帧。视觉上仿玻璃与真模糊几乎无法区分。
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.radius,
    this.topRadius,
    this.tone = GlassTone.regular,
    this.fill,
    this.tint,
    this.padding,
    this.margin,
    this.shadows,
    this.blurSigma,
    this.edge = GlassEdge.ring,
    this.edgeWidth = 1.0,
    this.animate = false,
  });

  final Widget child;

  /// 四角统一圆角；与 [topRadius] 二选一
  final double? radius;

  /// 只有顶角圆角（底部弹窗 / 底部导航）
  final double? topRadius;

  final GlassTone tone;

  /// 直接指定填充色，覆盖 [tone] 派生的值（FAB 用 primary 淡色底）。
  final Color? fill;

  /// 强调色。非空时描边与阴影走该色的强调态（计时进行中 = success）。
  final Color? tint;

  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  /// 覆盖默认阴影
  final List<BoxShadow>? shadows;

  /// 模糊半径（sigma）。null 表示不使用真模糊。
  /// 实际是否生效还取决于 [UiEffects.trueBlur]。
  final double? blurSigma;

  final GlassEdge edge;

  /// 描边宽度。计时进行中的卡片传 2.0 加粗。
  final double edgeWidth;

  /// 开启隐式动画（仅在值会变化的卡片上开，静止卡片保持普通 Container
  /// 以免白白分配隐式动画的 State）。
  final bool animate;

  BorderRadiusGeometry get _outerRadius {
    if (topRadius != null) {
      return BorderRadius.vertical(top: Radius.circular(topRadius!));
    }
    if (radius != null) return BorderRadius.circular(radius!);
    return BorderRadius.zero;
  }

  /// 内层圆角必须减去描边宽度才能与外圈同心
  BorderRadiusGeometry get _innerRadius {
    double shrink(double r) => (r - edgeWidth).clamp(0.0, double.infinity);
    if (topRadius != null) {
      return BorderRadius.vertical(top: Radius.circular(shrink(topRadius!)));
    }
    if (radius != null) return BorderRadius.circular(shrink(radius!));
    return BorderRadius.zero;
  }

  Gradient _edgeGradient() {
    final Color? c = tint;
    if (c == null) return AppGradients.glassEdge;
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[c.withValues(alpha: 0.55), c.withValues(alpha: 0.18)],
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color effectiveFill = fill ?? tone.fill;
    final List<BoxShadow> shadowList =
        shadows ?? (tint != null ? AppShadows.tint(tint!) : tone.shadows);
    final BorderRadiusGeometry outer = _outerRadius;
    final bool isRing = edge == GlassEdge.ring;

    // 填充层
    Widget body = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: effectiveFill,
        borderRadius: isRing ? _innerRadius : null,
      ),
      child: child,
    );

    // 真模糊：必须先裁圆角再模糊，顺序反了模糊会溢出圆角外
    if (blurSigma != null && UiEffects.trueBlur) {
      body = ClipRRect(
        borderRadius: isRing ? _innerRadius : outer,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma!, sigmaY: blurSigma!),
          child: body,
        ),
      );
    }

    Widget content;
    if (isRing) {
      // 环形描边：外层画渐变 + edgeWidth 内边距，内层画填充
      content = Container(
        padding: EdgeInsets.all(edgeWidth),
        decoration: BoxDecoration(
          gradient: _edgeGradient(),
          borderRadius: outer,
          boxShadow: shadowList,
        ),
        child: body,
      );
    } else {
      // 发丝线描边。
      //
      // 注意：非均匀 Border（Border.only / Border(top:)）不能与
      // BoxDecoration.borderRadius 同时使用，Flutter 会直接断言失败。
      // 所以圆角交给 ClipRRect 裁剪，BoxDecoration 上只放 border。
      final BorderSide side = BorderSide(
        color: tint?.withValues(alpha: 0.5) ?? AppColors.glassEdgeBottom,
        width: edgeWidth,
      );
      content = DecoratedBox(
        decoration: BoxDecoration(boxShadow: shadowList),
        child: ClipRRect(
          borderRadius: outer,
          child: Container(
            decoration: BoxDecoration(
              color: effectiveFill,
              border: switch (edge) {
                GlassEdge.top => Border(top: side),
                GlassEdge.bottom => Border(bottom: side),
                GlassEdge.ring || GlassEdge.none => null,
              },
            ),
            child: body,
          ),
        ),
      );
    }

    if (animate && isRing) {
      // 只有环形描边的卡片需要隐式动画（计时状态切换）
      content = AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: EdgeInsets.all(edgeWidth),
        decoration: BoxDecoration(
          gradient: _edgeGradient(),
          borderRadius: outer,
          boxShadow: shadowList,
        ),
        child: body,
      );
    }

    return margin != null ? Padding(padding: margin!, child: content) : content;
  }
}
