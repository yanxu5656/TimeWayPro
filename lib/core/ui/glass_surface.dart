import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'ui_effects.dart';

class GlassSurface extends StatefulWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.borderRadius,
    this.padding,
    this.fill,
    this.gradient,
    this.rimColor,
    this.blur = true,
    this.shadow = true,
    this.margin,
    this.interactiveLight = true,
  });

  final Widget child;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final Color? fill;
  final List<Color>? gradient;
  final Color? rimColor;
  final bool blur;
  final bool shadow;
  final EdgeInsetsGeometry? margin;
  final bool interactiveLight;

  @override
  State<GlassSurface> createState() => _GlassSurfaceState();
}

class _GlassSurfaceState extends State<GlassSurface> {
  Alignment _light = const Alignment(-0.65, -0.8);
  Alignment _settledLight = const Alignment(-0.65, -0.8);

  void _moveLight(Offset position, Size size) {
    if (!widget.interactiveLight || size.isEmpty) return;
    final Alignment next = Alignment(
      (position.dx / size.width) * 2 - 1,
      (position.dy / size.height) * 2 - 1,
    );
    if ((next.x - _light.x).abs() < 0.02 && (next.y - _light.y).abs() < 0.02) {
      return;
    }
    setState(() => _light = next);
  }

  @override
  Widget build(BuildContext context) {
    final AppAtmosphere atmosphere = context.atmosphere;
    final BorderRadius radius =
        widget.borderRadius ?? BorderRadius.circular(context.shape.cardRadius);
    final Color base = widget.fill ?? atmosphere.glassFill;
    final bool reducedMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    Widget surface = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: widget.shadow
            ? <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.42),
                  blurRadius: 26,
                  spreadRadius: -6,
                  offset: const Offset(0, 14),
                ),
                BoxShadow(
                  color: atmosphere.glow.withValues(alpha: 0.24),
                  blurRadius: 34,
                  spreadRadius: -10,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: RepaintBoundary(
          child: ValueListenableBuilder<UiEffectTier>(
            valueListenable: UiEffects.tier,
            builder: (BuildContext context, UiEffectTier tier, Widget? child) {
              return LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final Size size = constraints.biggest;
                  return Listener(
                    behavior: HitTestBehavior.deferToChild,
                    onPointerDown: (PointerDownEvent event) =>
                        _moveLight(event.localPosition, size),
                    onPointerHover: (PointerHoverEvent event) =>
                        _moveLight(event.localPosition, size),
                    child: TweenAnimationBuilder<Alignment>(
                      tween: Tween<Alignment>(
                        begin: _settledLight,
                        end: _light,
                      ),
                      duration: reducedMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                      onEnd: () {
                        _settledLight = _light;
                      },
                      builder:
                          (
                            BuildContext context,
                            Alignment light,
                            Widget? child,
                          ) {
                            final double sigma =
                                !widget.blur || tier == UiEffectTier.minimal
                                ? 0
                                : atmosphere.blurSigma *
                                      (tier == UiEffectTier.reduced ? 0.72 : 1);
                            return BackdropFilter(
                              filter: ui.ImageFilter.blur(
                                sigmaX: sigma,
                                sigmaY: sigma,
                              ),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: radius,
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors:
                                        widget.gradient ??
                                        <Color>[
                                          base.withValues(alpha: 0.58),
                                          base.withValues(alpha: 0.34),
                                        ],
                                  ),
                                ),
                                child: Stack(
                                  children: <Widget>[
                                    Positioned.fill(
                                      child: IgnorePointer(
                                        child: CustomPaint(
                                          painter: _GlassOpticsPainter(
                                            radius: radius,
                                            light: light,
                                            border: atmosphere.glassBorder,
                                            highlight: atmosphere.highlight,
                                            accent:
                                                widget.rimColor ??
                                                context.colors.accent,
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (widget.padding == null)
                                      child!
                                    else
                                      Padding(
                                        padding: widget.padding!,
                                        child: child!,
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                      child: child,
                    ),
                  );
                },
              );
            },
            child: widget.child,
          ),
        ),
      ),
    );

    if (widget.margin != null) {
      surface = Padding(padding: widget.margin!, child: surface);
    }
    return surface;
  }
}

class _GlassOpticsPainter extends CustomPainter {
  const _GlassOpticsPainter({
    required this.radius,
    required this.light,
    required this.border,
    required this.highlight,
    required this.accent,
  });

  final BorderRadius radius;
  final Alignment light;
  final Color border;
  final Color highlight;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final Rect rect = Offset.zero & size;
    final RRect rounded = radius.toRRect(rect);
    final Offset focal = light.withinRect(rect);

    final Paint reflection = Paint()
      ..shader = RadialGradient(
        center: light,
        radius: math.max(size.width, size.height) * 0.72,
        colors: <Color>[
          highlight.withValues(alpha: 0.15),
          highlight.withValues(alpha: 0.045),
          Colors.transparent,
        ],
        stops: const <double>[0, 0.34, 1],
      ).createShader(rect);
    canvas.drawRRect(rounded, reflection);

    final Paint rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.15
      ..shader = ui.Gradient.linear(
        rect.topLeft,
        rect.bottomRight,
        <Color>[
          highlight.withValues(alpha: 0.62),
          border.withValues(alpha: 0.14),
          accent.withValues(alpha: 0.36),
          highlight.withValues(alpha: 0.12),
        ],
        <double>[0, 0.36, 0.78, 1],
      );
    canvas.drawRRect(rounded.deflate(0.6), rim);

    final Paint innerRim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..color = Colors.white.withValues(alpha: 0.07);
    canvas.drawRRect(rounded.deflate(2), innerRim);

    final Paint glint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..shader = ui.Gradient.linear(
        focal - Offset(size.width * 0.22, 0),
        focal + Offset(size.width * 0.22, 0),
        <Color>[
          Colors.transparent,
          highlight.withValues(alpha: 0.44),
          Colors.transparent,
        ],
        const <double>[0, 0.5, 1],
      );
    final Path topEdge = Path()
      ..moveTo(rect.left + radius.topLeft.x, rect.top + 0.8)
      ..lineTo(rect.right - radius.topRight.x, rect.top + 0.8);
    canvas.drawPath(topEdge, glint);
  }

  @override
  bool shouldRepaint(_GlassOpticsPainter oldDelegate) {
    return oldDelegate.light != light ||
        oldDelegate.border != border ||
        oldDelegate.highlight != highlight ||
        oldDelegate.accent != accent ||
        oldDelegate.radius != radius;
  }
}

class GlassProgressRing extends StatelessWidget {
  const GlassProgressRing({
    super.key,
    required this.value,
    this.size = 64,
    this.strokeWidth = 6,
    this.child,
  });

  final double value;
  final double size;
  final double strokeWidth;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          CustomPaint(
            size: Size.square(size),
            painter: _GlassProgressPainter(
              value: value.clamp(0, 1),
              width: strokeWidth,
              track: Colors.white.withValues(alpha: 0.1),
              start: context.colors.primary,
              end: context.colors.accent,
            ),
          ),
          ?child,
        ],
      ),
    );
  }
}

class _GlassProgressPainter extends CustomPainter {
  const _GlassProgressPainter({
    required this.value,
    required this.width,
    required this.track,
    required this.start,
    required this.end,
  });

  final double value;
  final double width;
  final Color track;
  final Color start;
  final Color end;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = (size.shortestSide - width) / 2;
    final Rect rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..color = track,
    );
    if (value <= 0) return;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * value,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..shader = ui.Gradient.sweep(
          center,
          <Color>[start, end, start],
          const <double>[0, 0.5, 1],
          TileMode.clamp,
          -math.pi / 2,
        ),
    );
  }

  @override
  bool shouldRepaint(_GlassProgressPainter oldDelegate) =>
      oldDelegate.value != value ||
      oldDelegate.width != width ||
      oldDelegate.start != start ||
      oldDelegate.end != end;
}
