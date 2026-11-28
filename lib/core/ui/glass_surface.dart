import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'ui_effects.dart';

class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.borderRadius,
    this.padding,
    this.fill,
    this.blur = true,
    this.shadow = true,
    this.margin,
  });

  final Widget child;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final Color? fill;
  final bool blur;
  final bool shadow;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final AppAtmosphere atmosphere = context.atmosphere;
    final BorderRadius radius =
        borderRadius ?? BorderRadius.circular(context.shape.cardRadius);
    Widget surface = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: shadow
            ? <BoxShadow>[
                BoxShadow(
                  color: atmosphere.glow.withValues(alpha: 0.34),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.42),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: ValueListenableBuilder<UiEffectTier>(
          valueListenable: UiEffects.tier,
          builder: (BuildContext context, UiEffectTier tier, Widget? child) {
            return BackdropFilter(
              filter: ui.ImageFilter.blur(
                sigmaX: blur && tier != UiEffectTier.minimal
                    ? atmosphere.blurSigma
                    : 0,
                sigmaY: blur && tier != UiEffectTier.minimal
                    ? atmosphere.blurSigma
                    : 0,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      (fill ?? atmosphere.glassFill).withValues(alpha: 0.88),
                      (fill ?? atmosphere.glassFill).withValues(alpha: 0.58),
                    ],
                  ),
                  border: Border.all(color: atmosphere.glassBorder, width: 1),
                ),
                child: Stack(
                  children: <Widget>[
                    Positioned(
                      top: 0,
                      left: 20,
                      right: 20,
                      height: 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: <Color>[
                              Colors.transparent,
                              atmosphere.highlight,
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (padding == null)
                      child!
                    else
                      Padding(padding: padding!, child: child!),
                  ],
                ),
              ),
            );
          },
          child: child,
        ),
      ),
    );
    if (margin != null) surface = Padding(padding: margin!, child: surface);
    return surface;
  }
}
