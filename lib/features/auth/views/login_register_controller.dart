import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:secured_calling/utils/app_logger.dart';
import 'package:secured_calling/utils/app_tost_util.dart';
import 'package:secured_calling/core/services/app_firebase_service.dart';
import 'package:secured_calling/core/services/app_local_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  }

  void clearError() {
    errorMessage.value = null;
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
      final result = await AppFirebaseService.instance
          .signInWithEmailAndPassword(
            email: loginEmailController.text.trim(),
            password: loginPasswordController.text,
          );
          final isEmailVerified =  AppFirebaseService.instance.auth.currentUser?.emailVerified??false;
            
            if (!isEmailVerified) {
              if (context.mounted) {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => AlertDialog(
                    title: const Text('Email Verification Required'),
                    content: const Text(
                      'Please verify your email before logging in. Would you like to resend the verification email?'
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () async {
                          try {
                            await AppFirebaseService.instance.auth.currentUser?.sendEmailVerification();
                            if (context.mounted) {
                              Navigator.pop(context);
                              AppToastUtil.showSuccessToast(
                                context,
                                'Verification email sent. Please check your inbox.',
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              Navigator.pop(context);
                              AppToastUtil.showErrorToast(
                                context,
                                'Failed to send verification email. Please try again.',
                              );
                            }
                          }
                        },
                        child: const Text('Resend Email'),
                      ),
                    ],
                  ),
                );
              }
              return 'Please verify your email before logging in.';
            }
      AppLogger.print("login button presed :  ${result.user}");
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
      AppLogger.print("firebase error while logging in :${e.code}");

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

      setError(errorType.message);
      return errorType.message;
    } catch (e) {
      AppLogger.print("error while logging in :$e");
      setError('An unexpected error occurred. Please try again.');
      return 'Something went wrong..';
    } finally {
      setLoading(false);
      update();
    }
  }

  Future<bool> register() async {
    setLoading(true);
    update();
    clearError();
    try {
      // First validate if member code exists (case-insensitive)
      final inputCode = registerMemberCodeController.text.trim().toUpperCase();
      final memberSnapshot = await FirebaseFirestore.instance
          .collection('members')
          .where('isActive', isEqualTo: true)
          .get();

      QueryDocumentSnapshot? matchingDoc;
      try {
        matchingDoc = memberSnapshot.docs.firstWhere(
          (doc) => (doc['memberCode'] as String).toUpperCase() == inputCode,
        );
      } catch (_) {
        matchingDoc = null;
      }

      if (matchingDoc == null) {
        setError('Invalid or inactive member code. Please check and try again.');
        setLoading(false);
        update();
        return false;
      }

      final resp = await AppFirebaseService.instance.signUpWithEmailAndPassword(
        name: registerNameController.text.trim(),
        email: registerEmailController.text.trim(),
        password: registerPasswordController.text.trim(),
        memberCode: registerMemberCodeController.text.trim().toUpperCase(),
      );
      
      setLoading(false);
      update();
      return resp;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          setError('An account already exists with this email.');
          break;
        case 'weak-password':
          setError('Password is too weak. Use at least 6 characters.');
          break;
        case 'invalid-email':
          setError('Invalid email format.');
          break;
        default:
          setError('Error: ${e.message}');
      }
    } catch (e) {
      setError(e.toString());
    } finally {
      setLoading(false);
      update();
    }
    return false;
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
