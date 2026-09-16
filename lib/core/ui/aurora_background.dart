import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_shadows.dart';
import 'ui_effects.dart';

/// 缓慢漂移的极光背景层。
///
/// 这是整套玻璃方案成立的前提：半透明卡片背后必须先有东西可看，
/// 否则"磨砂"等于什么都没发生（改造前的背景是纯色 #F8FAFB）。
///
/// ## 为什么不用 ImageFilter.blur 画光斑
///
/// 全屏模糊是一次全屏 offscreen pass（saveLayer + 双方向高斯），
/// 每帧都要重做。而 `RadialGradient(alpha → 0)` 本身就是柔和衰减，
/// 视觉上与"模糊圆"无法区分，成本只是一次 GPU 渐变填充。
///
/// ## 为什么不用 AnimatedBuilder / setState
///
/// 动画通过 `CustomPainter` 的 `repaint` Listenable 驱动，控制器每
/// tick 只让 `RenderCustomPaint` 标记 needs-paint，**零 widget
/// rebuild、零 layout**。`AnimatedBuilder` 也会 rebuild 它自己的子树。
///
/// 顺带一个测试上的好处：不使用 `Timer.periodic` 降帧，因此不会在
/// `testWidgets` 里触发 "A Timer is still pending"。
class AuroraBackground extends StatefulWidget {
  const AuroraBackground({super.key, this.forceAnimated});

  /// 显式指定是否播放漂移动画；为 null 时跟随 [UiEffects.auroraAnimated]。
  /// 测试里传 false 可让 `pumpAndSettle` 正常收敛。
  final bool? forceAnimated;

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground>
    with SingleTickerProviderStateMixin {
  /// 48 秒周期——足够慢，肉眼几乎察觉不到在动，但细看又不是静止的。
  static const Duration _cycle = Duration(seconds: 48);

  late final AnimationController _controller =
      AnimationController(vsync: this, duration: _cycle);

  @override
  void initState() {
    super.initState();
    UiEffects.tier.addListener(_syncAnimation);
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant AuroraBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.forceAnimated != widget.forceAnimated) _syncAnimation();
  }

  void _syncAnimation() {
    final animate = widget.forceAnimated ?? UiEffects.auroraAnimated;
    if (animate) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
      // 停在当前位置即可：静态极光与任意一帧动画画面视觉无差别
    }
  }

  @override
  void dispose() {
    UiEffects.tier.removeListener(_syncAnimation);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _AuroraPainter(_controller),
        isComplex: false,
        willChange: true,
        child: const SizedBox.expand(),
      ),
    );
  }
}

/// 单个光斑。
class _Blob {
  const _Blob({
    required this.color,
    required this.alpha,
    required this.radiusFactor,
    required this.center,
    required this.amp,
    required this.period,
  });

  final Color color;

  /// 光斑核心不透明度。**上限 0.45**——超过后 textSecondary 对玻璃底的
  /// 对比度会跌破 WCAG AA 的 4.5:1。见 [AppColors] 的对比度说明。
  final double alpha;

  /// 半径相对 `size.shortestSide` 的倍数
  final double radiusFactor;

  /// 平衡位置（屏幕归一化坐标）
  final Offset center;

  /// 漂移幅度（归一化）
  final Offset amp;

  /// 横/纵漂移周期相对 _cycle 的倍率。三者互质，视觉上认不出循环点。
  final Offset period;
}

class _AuroraPainter extends CustomPainter {
  _AuroraPainter(this.phase) : super(repaint: phase);

  final Animation<double> phase;

  static const List<_Blob> _blobs = <_Blob>[
    _Blob(
      color: AppColors.auroraBlobPrimary,
      alpha: 0.42,
      radiusFactor: 0.95,
      center: Offset(0.20, 0.14),
      amp: Offset(0.10, 0.07),
      period: Offset(37, 53),
    ),
    _Blob(
      color: AppColors.auroraBlobMint,
      alpha: 0.34,
      radiusFactor: 0.80,
      center: Offset(0.86, 0.30),
      amp: Offset(0.12, 0.06),
      period: Offset(53, 71),
    ),
    _Blob(
      color: AppColors.auroraBlobSky,
      alpha: 0.26,
      radiusFactor: 1.05,
      center: Offset(0.45, 0.92),
      amp: Offset(0.08, 0.10),
      period: Offset(71, 37),
    ),
  ];

  /// 对比度护栏：光斑 alpha 不得超过 0.45。
  static const double _maxBlobAlpha = 0.45;

  @override
  void paint(Canvas canvas, Size size) {
    assert(
      _blobs.every((b) => b.alpha <= _maxBlobAlpha),
      '极光光斑 alpha 超过 $_maxBlobAlpha 会让玻璃卡上的正文跌破 WCAG AA',
    );

    // 实底基色：极光层是部分透明的，必须有不透明的底
    final base = Paint()
      ..shader = AppGradients.auroraBase.createShader(
        Offset.zero & size,
      );
    canvas.drawRect(Offset.zero & size, base);

    final t = phase.value * 2 * math.pi;
    final fill = Paint();

    for (final blob in _blobs) {
      final cx =
          (blob.center.dx + blob.amp.dx * math.sin(t * 48 / blob.period.dx)) *
              size.width;
      final cy =
          (blob.center.dy + blob.amp.dy * math.cos(t * 48 / blob.period.dy)) *
              size.height;
      final r = blob.radiusFactor * size.shortestSide;

      // shader 建在局部坐标系原点，配合 translate 使用，
      // 避免每帧用画布绝对坐标重建 3 个 shader。
      fill.shader = ui.Gradient.radial(
        Offset.zero,
        r,
        <Color>[
          blob.color.withValues(alpha: blob.alpha),
          blob.color.withValues(alpha: 0),
        ],
        const <double>[0.0, 1.0],
      );

      canvas
        ..save()
        ..translate(cx, cy)
        ..drawCircle(Offset.zero, r, fill)
        ..restore();
    }
  }

  /// 重绘完全由构造时传入的 `repaint` Listenable 驱动，
  /// 这里返回 false 以免 widget 重建时多画一帧。
  @override
  bool shouldRepaint(covariant _AuroraPainter oldDelegate) => false;

  @override
  bool shouldRebuildSemantics(covariant _AuroraPainter oldDelegate) => false;
}