import 'package:flutter/material.dart';
import '../../../../core/extensions/string_extensions.dart';
import '../../../../core/constants/error_messages.dart';
import 'text_input.dart';

class EmailInput extends StatelessWidget {
  final String label;
  final String? placeholder;
  final String? helperText;
  final String? errorText;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSubmitted;

  const EmailInput({
    Key? key,
    required this.label,
    this.placeholder = 'user@example.com',
    this.helperText,
    this.errorText,
    this.controller,
    this.focusNode,
    this.enabled = true,
    this.onChanged,
    this.onSubmitted,
  }) : super(key: key);

  String? _validator(String? value) {
    if (value == null || value.isEmpty) {
      return ErrorMessages.emptyEmail;
    }
    if (!value.isValidEmail) {
      return ErrorMessages.invalidEmail;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return TextInput(
      label: label,
      placeholder: placeholder,
      helperText: helperText,
      errorText: errorText,
      controller: controller,
      focusNode: focusNode,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      enabled: enabled,
      onChanged: onChanged,
      validator: _validator,
    );
  }
}
