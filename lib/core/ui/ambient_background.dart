import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'ui_effects.dart';

class AmbientBackground extends StatelessWidget {
  const AmbientBackground({super.key, required this.design});

  final AppDesign design;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 720),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: design.atmosphere == null
          ? const SizedBox.expand(key: ValueKey<String>('plain'))
          : _AuroraLayer(
              key: ValueKey<String>('${design.style.name}-aurora'),
              atmosphere: design.atmosphere!,
            ),
    );
  }
}

class _AuroraLayer extends StatefulWidget {
  const _AuroraLayer({super.key, required this.atmosphere});

  final AppAtmosphere atmosphere;

  @override
  State<_AuroraLayer> createState() => _AuroraLayerState();
}

class _AuroraLayerState extends State<_AuroraLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 28),
  );

  bool _canAnimate = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool disabled =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _canAnimate = !disabled && UiEffects.stagger;
    if (_canAnimate && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!_canAnimate && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              widget.atmosphere.background,
              widget.atmosphere.backgroundElevated,
              widget.atmosphere.background,
            ],
            stops: const <double>[0, 0.52, 1],
          ),
        ),
        child: ValueListenableBuilder<UiEffectTier>(
          valueListenable: UiEffects.tier,
          builder: (BuildContext context, UiEffectTier tier, Widget? child) {
            final bool animate = _canAnimate && tier == UiEffectTier.full;
            if (animate && !_controller.isAnimating) {
              _controller.repeat();
            } else if (!animate && _controller.isAnimating) {
              _controller.stop();
            }
            return RepaintBoundary(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (BuildContext context, Widget? child) {
                  final double phase = _controller.value * math.pi * 2;
                  return Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      _lightField(
                        widget.atmosphere.orbs[0],
                        Alignment(
                          -0.62 + math.sin(phase) * 0.16,
                          -0.3 + math.cos(phase * 0.7) * 0.08,
                        ),
                        1.34,
                        0.9,
                        0.78,
                      ),
                      _lightField(
                        widget.atmosphere.orbs[1],
                        Alignment(
                          0.62 + math.cos(phase * 0.8) * 0.14,
                          0.02 + math.sin(phase * 0.6) * 0.12,
                        ),
                        1.12,
                        0.78,
                        0.67,
                      ),
                      _lightField(
                        widget.atmosphere.orbs[2],
                        Alignment(
                          -0.18 + math.sin(phase * 0.65 + 1.8) * 0.18,
                          0.68 + math.cos(phase * 0.9) * 0.08,
                        ),
                        1.2,
                        0.72,
                        0.48,
                      ),
                      _lightField(
                        widget.atmosphere.orbs[3],
                        Alignment(
                          0.76 + math.cos(phase * 0.55 + 2) * 0.12,
                          0.84 + math.sin(phase * 0.75) * 0.06,
                        ),
                        0.96,
                        0.66,
                        0.5,
                      ),
                      const Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _AtmosphereGrainPainter(),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                center: Alignment.center,
                                radius: 1.05,
                                colors: <Color>[
                                  Colors.transparent,
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.3),
                                ],
                                stops: <double>[0, 0.62, 1],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _lightField(
    Color color,
    Alignment alignment,
    double width,
    double height,
    double opacity,
  ) {
    return Align(
      alignment: alignment,
      child: FractionallySizedBox(
        widthFactor: width,
        heightFactor: height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: <Color>[
                color.withValues(alpha: opacity),
                color.withValues(alpha: opacity * 0.68),
                color.withValues(alpha: opacity * 0.2),
                color.withValues(alpha: 0),
              ],
              stops: const <double>[0, 0.2, 0.52, 1],
            ),
          ),
        ),
      ),
    );
  }
}

class _AtmosphereGrainPainter extends CustomPainter {
  const _AtmosphereGrainPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final math.Random random = math.Random(28);
    final Paint paint = Paint()..color = Colors.white.withValues(alpha: 0.045);
    for (int i = 0; i < 150; i++) {
      final Offset point = Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height,
      );
      canvas.drawCircle(point, random.nextDouble() * 0.65 + 0.2, paint);
    }
  }

  @override
  bool shouldRepaint(_AtmosphereGrainPainter oldDelegate) => false;
}
