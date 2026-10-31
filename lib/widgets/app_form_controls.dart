import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_colors.dart';

enum AppButtonVariant { primary, secondary, text }

enum InlineNoticeType { error, warning, info, success }

class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.variant = AppButtonVariant.primary,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final AppButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    final callback = loading || onPressed == null
        ? null
        : () {
            HapticFeedback.selectionClick();
            onPressed!();
          };
    final content = loading
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
        : icon == null
        ? null
        : Icon(icon);
    final child = Text(label);

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: switch (variant) {
        AppButtonVariant.primary => FilledButton.icon(
          onPressed: callback,
          icon: content ?? const SizedBox.shrink(),
          label: child,
        ),
        AppButtonVariant.secondary => OutlinedButton.icon(
          onPressed: callback,
          icon: content ?? const SizedBox.shrink(),
          label: child,
        ),
        AppButtonVariant.text => TextButton.icon(
          onPressed: callback,
          icon: content ?? const SizedBox.shrink(),
          label: child,
        ),
      },
    );
  }
}

class AppTextField extends StatelessWidget {
  const AppTextField({
    required this.controller,
    required this.label,
    required this.prefixIcon,
    this.hintText,
    this.helperText,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.suffixIcon,
    this.autofillHints,
    this.onChanged,
    this.onFieldSubmitted,
    this.validator,
    this.enabled = true,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final IconData prefixIcon;
  final String? hintText;
  final String? helperText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final Widget? suffixIcon;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final FormFieldValidator<String>? validator;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          enabled: enabled,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          obscureText: obscureText,
          autofillHints: autofillHints,
          onChanged: onChanged,
          onFieldSubmitted: onFieldSubmitted,
          validator: validator,
          decoration: InputDecoration(
            hintText: hintText,
            helperText: helperText,
            prefixIcon: Icon(prefixIcon),
            suffixIcon: suffixIcon,
            constraints: const BoxConstraints(minHeight: 56),
          ),
        ),
      ],
    );
  }
}

class InlineNotice extends StatelessWidget {
  const InlineNotice({
    required this.type,
    required this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final InlineNoticeType type;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (type) {
      InlineNoticeType.error => scheme.error,
      InlineNoticeType.warning => const Color(0xFFF59E0B),
      InlineNoticeType.info || InlineNoticeType.success => AppColors.primary,
    };
    final icon = switch (type) {
      InlineNoticeType.error => Icons.error_outline_rounded,
      InlineNoticeType.warning => Icons.warning_amber_rounded,
      InlineNoticeType.info => Icons.info_outline_rounded,
      InlineNoticeType.success => Icons.check_circle_outline_rounded,
    };

    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: .38)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 21),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(width: 6),
              TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(
                  foregroundColor: color,
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
