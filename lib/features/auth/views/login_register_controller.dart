import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:secured_calling/utils/app_logger.dart';
import 'package:secured_calling/utils/app_tost_util.dart';
import 'package:secured_calling/core/services/app_auth_service.dart';
import 'package:secured_calling/core/services/app_local_storage.dart';

class LoginRegisterController extends GetxController {
  // State Variables
  var isLoading = false.obs;
  var obscureLoginPassword = true.obs;
  var obscureRegisterPassword = true.obs;
  var errorMessage = RxnString(); // nullable String

  // TextEditingControllers
  final loginEmailController = TextEditingController();
  final loginPasswordController = TextEditingController();
  final registerNameController = TextEditingController();
  final registerMemberCodeController = TextEditingController();
  final registerEmailController = TextEditingController();
  final registerPasswordController = TextEditingController();

  // Actions
  void setLoading(bool loading) {
    isLoading.value = loading;
  }

  void setError(String? error) {
    errorMessage.value = error;
    update();
  }

  void clearError() {
    errorMessage.value = null;
    update();
  }

  void toggleLoginPasswordVisibility() {
    obscureLoginPassword.toggle();
    update();
  }

  void toggleRegisterPasswordVisibility() {
    obscureRegisterPassword.toggle();
    update();
  }

  Future<String?> login({required BuildContext context}) async {
    setLoading(true);
    clearError();
    update();
    try {
      final result = await AppAuthService.instance.login(
        email: loginEmailController.text.trim(),
        password: loginPasswordController.text,
      );

      AppLogger.print("login successful: ${result['user']}");
      AppToastUtil.showSuccessToast('Login successful');

      return null;
    } catch (e) {
      AppLogger.print("error while logging in :$e");
      setError(e.toString());
      return e.toString();
    } finally {
      setLoading(false);
      update();
    }
  }

  @override
  void onClose() {
    loginEmailController.dispose();
    loginPasswordController.dispose();
    registerNameController.dispose();
    registerEmailController.dispose();
    registerPasswordController.dispose();
    super.onClose();
  }
}

// --- ENUMs

enum LoginError {
  network,
  userNotFound,
  wrongPassword,
  invalidEmail,
  invalidCredential,
  unknown,
}

extension LoginErrorMessage on LoginError {
  String get message {
    switch (this) {
      case LoginError.network:
        return 'No Internet Connection Available.';
      case LoginError.userNotFound:
        return 'No user found with this email.';
      case LoginError.wrongPassword:
        return 'Incorrect password.';
      case LoginError.invalidEmail:
        return 'Invalid email format.';
      case LoginError.invalidCredential:
        return 'Invalid email or password.';
      case LoginError.unknown:
        return 'An unexpected error occurred. Please try again.';
    }
  }
}
