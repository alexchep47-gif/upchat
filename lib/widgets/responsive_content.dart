import 'package:flutter/material.dart';

/// Donne à chaque écran toute la largeur et toute la hauteur disponibles.
class ResponsiveContent extends StatelessWidget {
  final Widget child;

  const ResponsiveContent({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(child: child);
  }
}
