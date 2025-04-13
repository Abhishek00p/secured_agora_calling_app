import 'package:flutter/material.dart';

class AppToastUtil {
  static void showSuccessToast(BuildContext context, String message) {
    _showToast(context, message, Colors.green);
  }

  static void showErrorToast(BuildContext context, String message) {
    _showToast(context, message, Colors.red);
  }

  static void showInfoToast(BuildContext context, String message) {
    _showToast(context, message, Colors.blueGrey);
  }

  static void _showToast(BuildContext context, String message, Color bgColor) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: bgColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    );
  }
}
