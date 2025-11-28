import 'package:flutter/material.dart';
import '../../../../core/constants/error_messages.dart';
import '../../../../core/theme/app_colors.dart';
import 'text_input.dart';

class PasswordInput extends StatefulWidget {
  final String label;
  final String? placeholder;
  final String? helperText;
  final String? errorText;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSubmitted;

  const PasswordInput({
    Key? key,
    required this.label,
    this.placeholder = 'Enter your password',
    this.helperText,
    this.errorText,
    this.controller,
    this.focusNode,
    this.enabled = true,
    this.onChanged,
    this.onSubmitted,
  }) : super(key: key);

  @override
  State<PasswordInput> createState() => _PasswordInputState();
}

class _PasswordInputState extends State<PasswordInput> {
  bool _obscureText = true;

  String? _validator(String? value) {
    if (value == null || value.isEmpty) {
      return ErrorMessages.emptyPassword;
    }
    if (value.length < 8) {
      return ErrorMessages.passwordTooShort;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return TextInput(
      label: widget.label,
      placeholder: widget.placeholder,
      helperText: widget.helperText,
      errorText: widget.errorText,
      controller: widget.controller,
      focusNode: widget.focusNode,
      keyboardType: TextInputType.visiblePassword,
      obscureText: _obscureText,
      enabled: widget.enabled,
      onChanged: widget.onChanged,
      suffixIcon: GestureDetector(
        onTap: () => setState(() => _obscureText = !_obscureText),
        child: Icon(
          _obscureText ? Icons.visibility_off : Icons.visibility,
          color: AppColors.textSecondary,
        ),
      ),
      validator: _validator,
    );
  }
}
