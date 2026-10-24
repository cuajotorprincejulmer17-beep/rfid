import 'package:flutter/material.dart';

import '../../core/theme/pulse_theme.dart';
import '../../core/theme/pulse_tokens.dart';

/// A text field that matches the Pulse surfaces.
class PulseTextField extends StatelessWidget {
  const PulseTextField({
    super.key,
    required this.controller,
    this.label,
    this.hint,
    this.errorText,
    this.keyboardType,
    this.maxLines = 1,
    this.textInputAction,
    this.onSubmitted,
    this.enabled = true,
    this.obscureText = false,
    this.autofillHints,
    this.textCapitalization = TextCapitalization.none,
    this.suffix,
  });

  final TextEditingController controller;
  final String? label;
  final String? hint;
  final String? errorText;
  final TextInputType? keyboardType;
  final int maxLines;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;

  /// Hides the text, for passwords.
  final bool obscureText;
  final Iterable<String>? autofillHints;
  final TextCapitalization textCapitalization;

  /// A trailing control inside the field, such as a show-password toggle.
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    final t = context.pulse;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: PulseType.label.copyWith(color: t.textSecondary),
          ),
          const SizedBox(height: PulseSpacing.xs),
        ],
        TextField(
          controller: controller,
          enabled: enabled,
          maxLines: maxLines,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          onSubmitted: onSubmitted,
          obscureText: obscureText,
          autocorrect: !obscureText,
          enableSuggestions: !obscureText,
          autofillHints: autofillHints,
          textCapitalization: textCapitalization,
          style: PulseType.body.copyWith(color: t.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            suffixIcon: suffix,
            hintStyle: PulseType.body.copyWith(color: t.textSecondary),
            errorText: errorText,
            errorStyle: PulseType.caption.copyWith(color: t.error),
            filled: true,
            fillColor: t.surfaceElevated.withValues(alpha: 0.7),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: PulseSpacing.md,
              vertical: PulseSpacing.md,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(PulseRadius.input),
              borderSide: BorderSide(color: t.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(PulseRadius.input),
              borderSide: BorderSide(color: t.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(PulseRadius.input),
              borderSide: BorderSide(color: t.primary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(PulseRadius.input),
              borderSide: BorderSide(color: t.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(PulseRadius.input),
              borderSide: BorderSide(color: t.error, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
