import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:secured_calling/utils/app_logger.dart';
import 'package:secured_calling/utils/app_tost_util.dart';
import 'package:secured_calling/core/services/app_auth_service.dart';

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
      final result = await AppAuthService.instance
          .login(email: loginEmailController.text.trim(), password: loginPasswordController.text)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              AppToastUtil.showErrorToast(
                'Login request timed out. Please check your internet connection and try again.',
              );
            },
          );
      if (result == null) {
        AppToastUtil.showErrorToast('Failed to login. Please try again.');
        return null;
      }

      AppLogger.print("login successful: ${result['user']}");
      AppToastUtil.showSuccessToast('Login successful');

      return null;
    } on Exception catch (e) {
      AppLogger.print("error while logging in: $e");
      String errorMessage = e.toString();

      // Handle specific error types
      if (errorMessage.contains('timeout')) {
        errorMessage = 'Request timed out. Please check your internet connection.';
      } else if (errorMessage.contains('SocketException') || errorMessage.contains('NetworkException')) {
        errorMessage = 'No internet connection. Please check your network and try again.';
      } else if (errorMessage.contains('Failed with status')) {
        errorMessage = 'Server error. Please try again later.';
      }

      setError(errorMessage);
      return errorMessage;
    } catch (e) {
      AppLogger.print("unexpected error while logging in: $e");
      setError('An unexpected error occurred. Please try again.');
      return 'An unexpected error occurred. Please try again.';
    } finally {
      setLoading(false);
      update();
    }
  }

  /// Test method for simulating different login scenarios (for debugging)
  Future<void> testLoginScenarios() async {
    AppLogger.print('🧪 Testing login scenarios...');

    // Test 1: Simulate loading state
    AppLogger.print('Test 1: Simulating loading state');
    setLoading(true);
    await Future.delayed(const Duration(seconds: 2));
    setLoading(false);

    // Test 2: Simulate timeout
    AppLogger.print('Test 2: Simulating timeout');
    setLoading(true);
    await Future.delayed(const Duration(seconds: 1));
    setError('Request timed out. Please check your internet connection.');
    setLoading(false);

    // Test 3: Simulate network error
    AppLogger.print('Test 3: Simulating network error');
    await Future.delayed(const Duration(seconds: 1));
    setError('No internet connection. Please check your network and try again.');

    // Test 4: Simulate server error
    AppLogger.print('Test 4: Simulating server error');
    await Future.delayed(const Duration(seconds: 1));
    setError('Server error. Please try again later.');

    // Test 5: Clear errors
    AppLogger.print('Test 5: Clearing errors');
    await Future.delayed(const Duration(seconds: 1));
    clearError();

    AppLogger.print('✅ Login scenario testing completed');
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

enum LoginError { network, userNotFound, wrongPassword, invalidEmail, invalidCredential, unknown }

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
