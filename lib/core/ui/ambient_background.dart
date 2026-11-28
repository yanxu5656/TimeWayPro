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
      duration: const Duration(milliseconds: 650),
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
    duration: const Duration(seconds: 24),
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
      child: ColoredBox(
        color: widget.atmosphere.background,
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
                      _orb(
                        widget.atmosphere.orbs[0],
                        Alignment(-0.35 + math.sin(phase) * 0.12, -0.18),
                        0.92,
                      ),
                      _orb(
                        widget.atmosphere.orbs[1],
                        Alignment(0.55, 0.12 + math.cos(phase * 0.8) * 0.1),
                        1.05,
                      ),
                      _orb(
                        widget.atmosphere.orbs[2],
                        Alignment(
                          -0.1,
                          0.58 + math.sin(phase * 0.7 + 2) * 0.12,
                        ),
                        0.86,
                      ),
                      _orb(
                        widget.atmosphere.orbs[3],
                        Alignment(0.72, 0.78 + math.cos(phase * 0.9) * 0.08),
                        0.78,
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

  Widget _orb(Color color, Alignment alignment, double opacity) {
    return Align(
      alignment: alignment,
      child: FractionallySizedBox(
        widthFactor: 1.05,
        heightFactor: 0.72,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: <Color>[
                color.withValues(alpha: opacity),
                color.withValues(alpha: opacity * 0.42),
                color.withValues(alpha: 0),
              ],
              stops: const <double>[0, 0.42, 1],
            ),
          ),
        ),
      ),
    );
  }
}
