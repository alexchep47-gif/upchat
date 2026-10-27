import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_glass.dart';

/// Thèmes UpChat — bleu unique, barre système transparente, jetons de verre.
class AppTheme {
  static ThemeData get lightTheme => _build(
        brightness: Brightness.light,
        background: AppColors.backgroundLight,
        surface: AppColors.surfaceLight,
        elevated: const Color(0xFFF8FAFC),
        primaryText: AppColors.textPrimaryLight,
        secondaryText: AppColors.textSecondaryLight,
        divider: AppColors.dividerLight,
        inputFill: const Color(0xFFF1F5F9),
        glass: AppGlass.light,
        iconBrightness: Brightness.dark,
      );

  static ThemeData get darkTheme => _build(
        brightness: Brightness.dark,
        background: AppColors.backgroundDark,
        surface: AppColors.surfaceDark,
        elevated: AppColors.surfaceElevatedDark,
        primaryText: AppColors.textPrimaryDark,
        secondaryText: AppColors.textSecondaryDark,
        divider: AppColors.dividerDark,
        inputFill: AppColors.surfaceElevatedDark,
        glass: AppGlass.dark,
        iconBrightness: Brightness.light,
      );

  static ThemeData get oledTheme => _build(
        brightness: Brightness.dark,
        background: AppColors.oledBackground,
        surface: const Color(0xFF0A0A0A),
        elevated: const Color(0xFF121212),
        primaryText: AppColors.textPrimaryDark,
        secondaryText: AppColors.textSecondaryDark,
        divider: const Color(0xFF1A1A1A),
        inputFill: const Color(0xFF121212),
        glass: AppGlass.oled,
        iconBrightness: Brightness.light,
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color elevated,
    required Color primaryText,
    required Color secondaryText,
    required Color divider,
    required Color inputFill,
    required AppGlass glass,
    required Brightness iconBrightness,
  }) {
    final overlay = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: iconBrightness,
      statusBarBrightness:
          iconBrightness == Brightness.dark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: iconBrightness,
      systemNavigationBarContrastEnforced: false,
      systemStatusBarContrastEnforced: false,
    );

    final scheme = brightness == Brightness.light
        ? ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            secondary: AppColors.primary,
            onSecondary: Colors.white,
            error: AppColors.error,
            onError: Colors.white,
            surface: surface,
            onSurface: primaryText,
            surfaceContainerHighest: elevated,
            onSurfaceVariant: secondaryText,
            outline: divider,
          )
        : ColorScheme.dark(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            secondary: AppColors.primary,
            onSecondary: Colors.white,
            error: AppColors.error,
            onError: Colors.white,
            surface: surface,
            onSurface: primaryText,
            surfaceContainerHighest: elevated,
            onSurfaceVariant: secondaryText,
            outline: divider,
          );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      extensions: <ThemeExtension<dynamic>>[glass],
      visualDensity: VisualDensity.adaptivePlatformDensity,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: primaryText,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: overlay,
        titleTextStyle: TextStyle(
          color: primaryText,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        shadowColor: Colors.transparent,
      ),
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: primaryText, fontSize: 16, height: 1.35),
        bodyMedium: TextStyle(color: primaryText, fontSize: 14, height: 1.35),
        bodySmall: TextStyle(color: secondaryText, fontSize: 12, height: 1.3),
        titleLarge:
            TextStyle(color: primaryText, fontSize: 20, fontWeight: FontWeight.w700),
        titleMedium:
            TextStyle(color: primaryText, fontSize: 16, fontWeight: FontWeight.w600),
        titleSmall:
            TextStyle(color: primaryText, fontSize: 14, fontWeight: FontWeight.w500),
      ),
      dividerTheme: DividerThemeData(color: divider, space: 1, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        hintStyle: TextStyle(color: secondaryText),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      progressIndicatorTheme:
          const ProgressIndicatorThemeData(color: AppColors.primary),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.primary,
        selectionColor: Color(0x662AABEE),
        selectionHandleColor: AppColors.primary,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : secondaryText,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.primary : divider,
        ),
      ),
    );
  }
}
