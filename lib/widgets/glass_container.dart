import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

/// Conteneur type glassmorphism (transparence + flou)
class GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final double blur;
  final double opacity;

  const GlassContainer({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius,
    this.blur = 16,
    this.opacity = 0.72,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = borderRadius ?? BorderRadius.circular(20);

    return RepaintBoundary(
      child: ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          margin: margin,
          padding: padding,
          decoration: BoxDecoration(
            color: (isDark ? AppColors.surfaceDark : Colors.white).withOpacity(opacity),
            borderRadius: radius,
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.06)
                  : Colors.white.withOpacity(0.5),
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
      ),
    );
  }
}
