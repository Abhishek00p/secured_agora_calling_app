// login_register_controller.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:secured_calling/app_tost_util.dart';
import 'package:secured_calling/core/services/app_firebase_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:secured_calling/core/services/app_local_storage.dart';

class LoginRegisterState {
  final bool isLoading;
  final bool obscureLoginPassword;
  final bool obscureRegisterPassword;
  final String? errorMessage;

  const LoginRegisterState({
    this.isLoading = false,
    this.obscureLoginPassword = true,
    this.obscureRegisterPassword = true,
    this.errorMessage,
  });

  LoginRegisterState copyWith({
    bool? isLoading,
    bool? obscureLoginPassword,
    bool? obscureRegisterPassword,
    String? errorMessage,
  }) {
    return LoginRegisterState(
      isLoading: isLoading ?? this.isLoading,
      obscureLoginPassword: obscureLoginPassword ?? this.obscureLoginPassword,
      obscureRegisterPassword:
          obscureRegisterPassword ?? this.obscureRegisterPassword,
      errorMessage: errorMessage,
    );
  }
}

class LoginRegisterController extends StateNotifier<LoginRegisterState> {
  LoginRegisterController() : super(const LoginRegisterState());

  void setLoading(bool loading) {
    state = state.copyWith(isLoading: loading);
  }

  void setError(String? error) {
    state = state.copyWith(errorMessage: error);
  }

  void toggleLoginPasswordVisibility() {
    state = state.copyWith(obscureLoginPassword: !state.obscureLoginPassword);
  }

  void toggleRegisterPasswordVisibility() {
    state = state.copyWith(
      obscureRegisterPassword: !state.obscureRegisterPassword,
    );
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  Future<String?> login(
    String email,
    String password, {
    required BuildContext context,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final result = await AppFirebaseService.instance
          .signInWithEmailAndPassword(email: email.trim(), password: password);
      AppToastUtil.showSuccessToast(context, 'Success ${result.user != null}');
      if (result.user != null) {
        await AppFirebaseService.instance.getLoggedInUserDataAsModel().then((
          e,
        ) {
          if (!e.isEmpty) {
            AppLocalStorage.storeUserDetails(e);
          }
        });
      }
      AppLocalStorage.setLoggedIn(result.user != null);

      return null;
    } on FirebaseAuthException catch (e) {
      debugPrint("firebase error while logging in :${e.code}");

      
    late LoginError errorType;

    switch (e.code) {
      case 'network-request-failed':
        errorType = LoginError.network;
        break;
      case 'invalid-credential':
        errorType = LoginError.invalidCredential;
        break;
      case 'user-not-found':
        errorType = LoginError.userNotFound;
        break;
      case 'wrong-password':
        errorType = LoginError.wrongPassword;
        break;
      case 'invalid-email':
        errorType = LoginError.invalidEmail;
        break;
      default:
        errorType = LoginError.unknown;
    }

    state = state.copyWith(errorMessage: errorType.message);
    return errorType.message;
    } catch (e) {
      debugPrint("error while logging in :$e");
      state = state.copyWith(
        errorMessage: 'An unexpected error occurred. Please try again.',
      );
      return 'Something went wrong..';
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<bool> register(String name, String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await AppFirebaseService.instance.signUpWithEmailAndPassword(
        name: name.trim(),
        email: email.trim(),
        password: password,
      );
      return true;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          state = state.copyWith(
            errorMessage: 'An account already exists with this email.',
          );
          break;
        case 'weak-password':
          state = state.copyWith(
            errorMessage: 'Password is too weak. Use at least 6 characters.',
          );
          break;
        case 'invalid-email':
          state = state.copyWith(errorMessage: 'Invalid email format.');
          break;
        default:
          state = state.copyWith(errorMessage: 'Error: ${e.message}');
      }
    } catch (_) {
      state = state.copyWith(
        errorMessage: 'An unexpected error occurred. Please try again.',
      );
    } finally {
      state = state.copyWith(isLoading: false);
    }
    return false;
  }
}

final loginRegisterControllerProvider =
    StateNotifierProvider<LoginRegisterController, LoginRegisterState>(
      (ref) => LoginRegisterController(),
    );
final loginEmailControllerProvider = Provider.autoDispose(
  (ref) => TextEditingController(),
);

final loginPasswordControllerProvider = Provider.autoDispose(
  (ref) => TextEditingController(),
);

final registerNameControllerProvider = Provider.autoDispose(
  (ref) => TextEditingController(),
);

final registerEmailControllerProvider = Provider.autoDispose(
  (ref) => TextEditingController(),
);

final registerPasswordControllerProvider = Provider.autoDispose(
  (ref) => TextEditingController(),
);
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