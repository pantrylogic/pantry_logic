import 'package:flutter/material.dart';
import '../core/theme.dart';

class AuthTextField extends StatelessWidget {
  const AuthTextField({
    super.key,
    required this.controller,
    required this.placeholder,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.textCapitalization = TextCapitalization.none,
    this.textAlign = TextAlign.start,
    this.style,
    this.autofocus = false,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String placeholder;
  final TextInputType keyboardType;
  final bool obscureText;
  final TextCapitalization textCapitalization;
  final TextAlign textAlign;
  final TextStyle? style;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.borderDm : AppColors.border;
    final fillColor = isDark ? AppColors.surfaceDm : AppColors.surface;
    final textColor = isDark ? AppColors.textPrimaryDm : AppColors.textPrimary;
    final mutedColor = isDark ? AppColors.textMutedDm : AppColors.textMuted;
    final focusColor = isDark ? AppColors.primaryDm : AppColors.primary;

    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      textCapitalization: textCapitalization,
      textAlign: textAlign,
      autofocus: autofocus,
      onSubmitted: onSubmitted,
      style: style ??
          nsSans(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: textColor,
          ),
      decoration: InputDecoration(
        hintText: placeholder,
        hintStyle: nsSans(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: mutedColor,
        ),
        filled: true,
        fillColor: fillColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: focusColor, width: 1.5),
        ),
      ),
    );
  }
}
