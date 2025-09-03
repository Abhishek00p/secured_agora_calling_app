import 'package:flutter/material.dart';

enum AppTextFormFieldType {
  name,
  email,
  password,
  text,
  phoneNumber,
  number,
}

class AppTextFormField extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final AppTextFormFieldType type;
  final String? Function(String?)? validator;
  final String? helperText;
  final IconData? prefixIcon;
  final bool isPasswordRequired;

  const AppTextFormField({
    super.key,
    required this.controller,
    required this.labelText,
    required this.type,
    this.validator,
    this.helperText,
    this.prefixIcon,
    this.isPasswordRequired = true,

  });

  @override
  State<AppTextFormField> createState() => _AppTextFormFieldState();
}

class _AppTextFormFieldState extends State<AppTextFormField> {
  bool _obscureText = false;

  IconData get _prefixIcon {
    switch (widget.type) {
      case AppTextFormFieldType.email:
        return Icons.email;
      case AppTextFormFieldType.password:
        return Icons.lock;
      case AppTextFormFieldType.phoneNumber:
        return Icons.phone;
      case AppTextFormFieldType.number:
        return Icons.numbers;
      case AppTextFormFieldType.text:
        return Icons.text_fields;
      case AppTextFormFieldType.name:
        return Icons.person;
    }
  }

  TextInputType get _keyboardType {
    switch (widget.type) {
      case AppTextFormFieldType.email:
        return TextInputType.emailAddress;
      case AppTextFormFieldType.phoneNumber:
        return TextInputType.phone;
      case AppTextFormFieldType.number:
        return TextInputType.number;
      case AppTextFormFieldType.password:
      case AppTextFormFieldType.text:
        return TextInputType.text;
      case AppTextFormFieldType.name:
        return TextInputType.name;
    }
  }

  String? _defaultValidator(String? value) {
    if(!widget.isPasswordRequired && widget.type==AppTextFormFieldType.password){
      return null;
    }
    if (value == null || value.isEmpty) {
      return 'This field is required';
    }

    switch (widget.type) {
      case AppTextFormFieldType.email:
        final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
        if (!emailRegex.hasMatch(value)) {
          return 'Please enter a valid email address';
        }
        break;
      case AppTextFormFieldType.password:
        if (value.length < 6) {
          return 'Password must be at least 6 characters';
        }
        break;
      case AppTextFormFieldType.phoneNumber:
        final phoneRegex = RegExp(r'^\+?[\d\s-]{10,}$');
        if (!phoneRegex.hasMatch(value)) {
          return 'Please enter a valid phone number';
        }
        break;
      case AppTextFormFieldType.number:
        if (double.tryParse(value) == null) {
          return 'Please enter a valid number';
        }
        break;
      case AppTextFormFieldType.text:
        // No specific validation for text
        break;
      case AppTextFormFieldType.name:
        // No specific validation for name
        break;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // Wrap in try-catch to handle disposed controllers gracefully
    try {
      return TextFormField(
        controller: widget.controller,
      decoration: InputDecoration(
        isDense: true,
        labelText: widget.labelText,
        prefixIcon: Icon(widget.prefixIcon??_prefixIcon),
        errorStyle: const TextStyle(color: Colors.red,fontSize: 8),
        suffixIcon: widget.type == AppTextFormFieldType.password
            ? IconButton(
                icon: Icon(
                  _obscureText ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () {
                  setState(() {
                    _obscureText = !_obscureText;
                  });
                },
              )
            : null,
        helperText: widget.helperText,
        helperMaxLines: 2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade400),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade400),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      
        obscureText: widget.type == AppTextFormFieldType.password ? _obscureText : false,
        keyboardType: _keyboardType,
        validator: widget.validator ?? _defaultValidator,
      );
    } catch (e) {
      // If controller is disposed, return a placeholder widget
      return Container(
        height: 56,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            widget.labelText,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
        ),
      );
    }
  }
}
