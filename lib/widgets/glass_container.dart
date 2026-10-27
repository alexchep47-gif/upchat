import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/theme/app_glass.dart';

/// Surface verre unique (ClipRRect + BackdropFilter optionnel + teinte + bordure).
/// Max 3 flous permanents à l'écran — utiliser [enableBlur] / low-data pour le repli.
class GlassSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final double? blur;
  final Color? tint;
  final Color? borderColor;
  final double borderWidth;
  final List<BoxShadow>? boxShadow;
  final bool forceOpaque;

  const GlassSurface({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius,
    this.blur,
    this.tint,
    this.borderColor,
    this.borderWidth = 1,
    this.boxShadow,
    this.forceOpaque = false,
  });

  @override
  Widget build(BuildContext context) {
    final glass = AppGlass.of(context);
    final radius = borderRadius ?? BorderRadius.circular(20);
    final useBlur = !forceOpaque && glass.enableBlur;
    final sigma = blur ?? glass.blurHeader;
    final fill = tint ?? glass.tint;
    final stroke = borderColor ?? glass.border;

    final decorated = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: useBlur ? fill : fill.withOpacity(0.96),
        borderRadius: radius,
        border: Border.all(color: stroke, width: borderWidth),
        boxShadow: boxShadow,
      ),
      child: child,
    );

    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: radius,
        child: useBlur
            ? BackdropFilter(
                filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                child: decorated,
              )
            : decorated,
      ),
    );
  }
}

/// Alias rétrocompat.
class GlassContainer extends GlassSurface {
  const GlassContainer({
    super.key,
    required super.child,
    super.padding,
    super.margin,
    super.borderRadius,
    double blur = 16,
    double opacity = 0.72,
  }) : super(blur: blur);
}
