import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AppToastUtil {
  static void showSuccessToast(String message) {
    _showToast(message, title: 'Success', bgColor: Colors.green, icon: Icons.check_circle_outline);
  }

  static void showErrorToast(String message) {
    _showToast(message, title: 'Error', bgColor: Colors.red, icon: Icons.error_outline);
  }

  static void showInfoToast(String message, {String? title}) {
    _showToast(message, title: title, bgColor: Colors.blueGrey, icon: Icons.info_outline);
  }

  static void _showToast(String message, {String? title, required Color bgColor, required IconData icon}) {
    // Close any existing snackbar
    if (Get.isSnackbarOpen) {
      Get.closeCurrentSnackbar();
    }

    Get.snackbar(
      title ??  '',
      message,
      backgroundColor: bgColor,
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 3),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      borderRadius: 8,
      barBlur: 0,
      isDismissible: true,
      forwardAnimationCurve: Curves.easeOutCubic,
      reverseAnimationCurve: Curves.easeInCubic,
      titleText: const SizedBox.shrink(),
      messageText: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      boxShadows: [
        BoxShadow(
          color: bgColor.withOpacity(0.3),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
      animationDuration: const Duration(milliseconds: 300),
      overlayBlur: 0,
      shouldIconPulse: false,
    );
  }
}
