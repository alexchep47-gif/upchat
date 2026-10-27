import 'dart:ui';
import 'package:flutter/material.dart';

/// Jetons de verre — contrastes renforcés clair / sombre.
class AppGlass extends ThemeExtension<AppGlass> {
  final double blurHeader;
  final double blurInput;
  final double blurChip;
  final double blurSheet;
  final Color tint;
  final Color border;
  final Color bubbleMe;
  final Color bubbleOther;
  final Color chatGradientTop;
  final Color chatGradientBottom;
  final bool enableBlur;

  const AppGlass({
    required this.blurHeader,
    required this.blurInput,
    required this.blurChip,
    required this.blurSheet,
    required this.tint,
    required this.border,
    required this.bubbleMe,
    required this.bubbleOther,
    required this.chatGradientTop,
    required this.chatGradientBottom,
    this.enableBlur = true,
  });

  /// Clair : teinte blanche semi-transparente, bordure visible, flou marqué.
  static const light = AppGlass(
    blurHeader: 28,
    blurInput: 26,
    blurChip: 16,
    blurSheet: 30,
    tint: Color(0xD9FFFFFF), // ~85% blanc
    border: Color(0x66FFFFFF),
    bubbleMe: Color(0xFFD6EEFF),
    bubbleOther: Color(0xF2FFFFFF),
    chatGradientTop: Color(0xFFEEF6FC),
    chatGradientBottom: Color(0xFFDCEAF7),
  );

  /// Sombre : teinte bleu-nuit lisible, bordure claire, flou fort.
  static const dark = AppGlass(
    blurHeader: 28,
    blurInput: 26,
    blurChip: 16,
    blurSheet: 30,
    tint: Color(0xCC1A2734), // ~80% opaque sombre
    border: Color(0x40FFFFFF),
    bubbleMe: Color(0xFF2B5278),
    bubbleOther: Color(0xF01E2A36),
    chatGradientTop: Color(0xFF0B141C),
    chatGradientBottom: Color(0xFF15202B),
  );

  static const oled = AppGlass(
    blurHeader: 22,
    blurInput: 20,
    blurChip: 12,
    blurSheet: 24,
    tint: Color(0xE00A0A0A),
    border: Color(0x33FFFFFF),
    bubbleMe: Color(0xFF1A3A5C),
    bubbleOther: Color(0xF0121212),
    chatGradientTop: Color(0xFF000000),
    chatGradientBottom: Color(0xFF0A0A0A),
  );

  AppGlass withBlurEnabled(bool enabled) => copyWith(enableBlur: enabled);

  @override
  AppGlass copyWith({
    double? blurHeader,
    double? blurInput,
    double? blurChip,
    double? blurSheet,
    Color? tint,
    Color? border,
    Color? bubbleMe,
    Color? bubbleOther,
    Color? chatGradientTop,
    Color? chatGradientBottom,
    bool? enableBlur,
  }) {
    return AppGlass(
      blurHeader: blurHeader ?? this.blurHeader,
      blurInput: blurInput ?? this.blurInput,
      blurChip: blurChip ?? this.blurChip,
      blurSheet: blurSheet ?? this.blurSheet,
      tint: tint ?? this.tint,
      border: border ?? this.border,
      bubbleMe: bubbleMe ?? this.bubbleMe,
      bubbleOther: bubbleOther ?? this.bubbleOther,
      chatGradientTop: chatGradientTop ?? this.chatGradientTop,
      chatGradientBottom: chatGradientBottom ?? this.chatGradientBottom,
      enableBlur: enableBlur ?? this.enableBlur,
    );
  }

  @override
  AppGlass lerp(ThemeExtension<AppGlass>? other, double t) {
    if (other is! AppGlass) return this;
    return AppGlass(
      blurHeader: lerpDouble(blurHeader, other.blurHeader, t) ?? blurHeader,
      blurInput: lerpDouble(blurInput, other.blurInput, t) ?? blurInput,
      blurChip: lerpDouble(blurChip, other.blurChip, t) ?? blurChip,
      blurSheet: lerpDouble(blurSheet, other.blurSheet, t) ?? blurSheet,
      tint: Color.lerp(tint, other.tint, t) ?? tint,
      border: Color.lerp(border, other.border, t) ?? border,
      bubbleMe: Color.lerp(bubbleMe, other.bubbleMe, t) ?? bubbleMe,
      bubbleOther: Color.lerp(bubbleOther, other.bubbleOther, t) ?? bubbleOther,
      chatGradientTop:
          Color.lerp(chatGradientTop, other.chatGradientTop, t) ??
              chatGradientTop,
      chatGradientBottom:
          Color.lerp(chatGradientBottom, other.chatGradientBottom, t) ??
              chatGradientBottom,
      enableBlur: t < 0.5 ? enableBlur : other.enableBlur,
    );
  }

  static AppGlass of(BuildContext context) {
    return Theme.of(context).extension<AppGlass>() ?? AppGlass.light;
  }
}
