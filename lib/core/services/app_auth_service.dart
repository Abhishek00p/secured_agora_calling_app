import 'package:secured_calling/core/models/app_user_model.dart';
import 'package:secured_calling/core/services/app_local_storage.dart';
import 'package:secured_calling/core/services/http_service.dart';
import 'package:secured_calling/utils/app_logger.dart';
import 'package:secured_calling/utils/app_tost_util.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

class AppAuthService {
  static final AppAuthService _instance = AppAuthService._();
  static AppAuthService get instance => _instance;

  /// Get the appropriate base URL based on platform and environment
  String get baseUrl => "https://secured-agora-calling-app.onrender.com/";

  // final FirebaseFunctions _functions = FirebaseFunctions.instance; // Not used in HTTP implementation
  String? _currentToken;
  AppUser? _currentUser;
  final AppHttpService _httpService = AppHttpService();

  // Private constructor
  AppAuthService._();

  // Getters
  String? get currentToken => _currentToken;
  AppUser? get currentUser => _currentUser;
  bool get isUserLoggedIn => AppLocalStorage.getLoggedInStatus();

  /// Login user using Firebase Functions (HTTP)
  Future<Map<String, dynamic>?> login({required String email, required String password}) async {
    try {
      AppLogger.print('Attempting login for: $email');

      // Use the new CRUD function with includeAuth: false for login
      final response = await _httpService.post(
        'api/auth/login',
        body: {'email': email.trim().toLowerCase(), 'password': password},
        includeAuth: false, // Don't include auth token for login
      );
      if (response == null) {
        AppToastUtil.showErrorToast('Something went wrong, please try again');
        return null;
      }

      if (response.containsKey('success')) {
        AppLogger.print("the data received from api is : $response");

        if (response['success'] == true) {
          // Extract token + user
          final data = response['data'] != null ? Map<String, dynamic>.from(response['data']) : {};
          AppLogger.print("the token received from api is : ${data['token']}");
          _currentToken = data['token'];
          _currentUser = AppUser.fromJson(data['user']);

          // Save locally
          AppLocalStorage.storeUserDetails(_currentUser!);
          AppLocalStorage.setLoggedIn(true);
          AppLocalStorage.storeToken(_currentToken!);

          AppLogger.print('Login successful for user: ${_currentUser!.name}');
          return {'success': true, 'user': _currentUser, 'token': _currentToken};
        } else {
          final errorMessage = response['error_message'] ?? 'Login failed';
          AppToastUtil.showErrorToast(errorMessage);
        }
      } else {
        AppToastUtil.showErrorToast("Invalid response format from server");
      }
    } catch (e) {
      AppLogger.print('Login error: $e');
      AppToastUtil.showErrorToast('Login failed: $e');
    }
    return null;
  }

  /// Create new user (called by members)
  Future<bool?> createUser({required String name, required String email, required String password, required String memberCode}) async {
    try {
      if (!isUserLoggedIn) {
        AppToastUtil.showErrorToast('User not logged in');
      }

      AppLogger.print('Creating user: $email under member code: $memberCode');

      // Use the new CRUD function (auth token will be added automatically)
      final response = await _httpService.post(
        'api/auth/create-user',
        body: {
          'name': name.trim(),
          'email': email.trim().toLowerCase(),
          'password': password,
          'memberCode': memberCode,
          'memberUserId': AppLocalStorage.getUserDetails().userId,
        },
      );

      if (response == null) {
        AppToastUtil.showErrorToast('Something went wrong, please try again');
        return null;
      }

      if (response['success'] == true) {
        AppToastUtil.showSuccessToast('User created successfully');
        return true;
      } else {
        final errorMessage = response['error_message'] ?? 'Failed to create user';
        AppToastUtil.showErrorToast(errorMessage);
      }
    } catch (e) {
      AppLogger.print('Create user error: $e');
      AppToastUtil.showErrorToast('Failed to create user: $e');
      return false;
    }
    return null;
  }

  /// Update user details (endpoint to be provided by backend; bound till repo for now)
  Future<bool?> updateUser({
    required int userId,
    required String name,
    required String email,
    String? newPassword,
    required String memberCode,
  }) async {
    try {
      if (!isUserLoggedIn) {
        AppToastUtil.showErrorToast('User not logged in');
        return null;
      }

      AppLogger.print('Updating user: $userId ($email)');

      final body = <String, dynamic>{
        'userId': userId,
        'name': name.trim(),
        'email': email.trim().toLowerCase(),
        'memberCode': memberCode,
        'memberUserId': AppLocalStorage.getUserDetails().userId,
      };
      if (newPassword != null && newPassword.isNotEmpty) {
        body['password'] = newPassword;
      }

      final response = await _httpService.post('api/auth/update-user', body: body);

      if (response == null) {
        AppToastUtil.showErrorToast('Something went wrong, please try again');
        return null;
      }

      if (response['success'] == true) {
        AppToastUtil.showSuccessToast('User updated successfully');
        return true;
      } else {
        final errorMessage = response['error_message'] ?? 'Failed to update user';
        AppToastUtil.showErrorToast(errorMessage);
      }
    } catch (e) {
      AppLogger.print('Update user error: $e');
      AppToastUtil.showErrorToast('Failed to update user: $e');
      return false;
    }
    return null;
  }

  /// Create new member (called by admins)
  Future<bool?> createMember({
    required String name,
    required String email,
    required String password,
    required String memberCode,
    required DateTime purchaseDate,
    required int planDays,
    required int maxParticipantsAllowed,
  }) async {
    try {
      if (!isUserLoggedIn) {
        AppToastUtil.showErrorToast('User not logged in');
      }

      AppLogger.print('Creating member: $email with member code: $memberCode');

      // Use the new CRUD function (auth token will be added automatically)
      final response = await _httpService.post(
        'api/auth/create-member',
        body: {
          'name': name.trim(),
          'email': email.trim().toLowerCase(),
          'password': password,
          'memberCode': memberCode,
          'purchaseDate': purchaseDate.toIso8601String(),
          'planDays': planDays,
          'maxParticipantsAllowed': maxParticipantsAllowed,
          'isMember': true,
          'isActive': true,
        },
      );

      if (response == null) {
        AppToastUtil.showErrorToast('Something went wrong, please try again');
        return null;
      }

      if (response['success'] == true) {
        AppToastUtil.showSuccessToast('Member created successfully');
        return true;
      } else {
        final errorMessage = response['error_message'] ?? 'Failed to create member';
        AppToastUtil.showErrorToast(errorMessage);
      }
    } catch (e) {
      AppLogger.print('Create member error: $e');
      AppToastUtil.showErrorToast('Failed to create member: $e');
      return false;
    }
    return null;
  }

  /// Reset user password
  Future<bool?> resetPassword({required String targetEmail, required String newPassword}) async {
    try {
      if (!isUserLoggedIn) AppToastUtil.showErrorToast('User not logged in');

      AppLogger.print('Resetting password for: $targetEmail');

      // Use the new CRUD function (auth token will be added automatically)
      final response = await _httpService.post('resetPassword', body: {'targetEmail': targetEmail.trim().toLowerCase(), 'newPassword': newPassword});

      if (response == null) {
        AppToastUtil.showErrorToast('Something went wrong, please try again');
        return null;
      }

      if (response['success'] == true) {
        AppToastUtil.showSuccessToast('Password reset successfully');
        return true;
      } else {
        final errorMessage = response['error_message'] ?? 'Failed to reset password';
        AppToastUtil.showErrorToast(errorMessage);
      }
    } catch (e) {
      AppLogger.print('Reset password error: $e');
      AppToastUtil.showErrorToast('Failed to reset password: $e');
      return false;
    }
    return null;
  }

  /// Get user credentials
  Future<Map<String, dynamic>?> getUserCredentials(String userId) async {
    try {
      if (!isUserLoggedIn) AppToastUtil.showErrorToast('User not logged in');

      AppLogger.print('Getting credentials for: $userId');

      // Use the new CRUD function (auth token will be added automatically)
      final response = await _httpService.get('api/auth/user-credentials/$userId');

      if (response == null) {
        AppToastUtil.showErrorToast('Something went wrong, please try again');
        return null;
      }

      if (response['success'] == true) {
        final data = Map<String, dynamic>.from(response['data']);
        return data;
      } else {
        final errorMessage = response['error_message'] ?? 'Failed to get credentials';
        AppToastUtil.showErrorToast(errorMessage);
      }
    } catch (e) {
      AppLogger.print('Get credentials error: $e');
      AppToastUtil.showErrorToast('Failed to get credentials: $e');
      return null;
    }
    return null;
  }

  /// Get users for password reset
  Future<List<Map<String, dynamic>>?> getUsersForPasswordReset() async {
    try {
      if (!isUserLoggedIn) AppToastUtil.showErrorToast('User not logged in');

      AppLogger.print('Getting users for password reset');

      // Use the new CRUD function (auth token will be added automatically)
      final response = await _httpService.post(
        'getUsersForPasswordReset',
        body: {}, // No params needed
      );
      if (response == null) {
        AppToastUtil.showErrorToast('Something went wrong, please try again');
        return null;
      }

      if (response['success'] == true) {
        final data = Map<String, dynamic>.from(response['data']);
        return List<Map<String, dynamic>>.from(data['users'] ?? []);
      } else {
        final errorMessage = response['error_message'] ?? 'Failed to get users';
        AppToastUtil.showErrorToast(errorMessage);
      }
    } catch (e) {
      AppLogger.print('Get users error: $e');
      AppToastUtil.showErrorToast('Failed to get users: $e');
      return [];
    }
    return null;
  }

  /// Logout user
  Future<void> logout() async {
    try {
      _currentToken = null;
      _currentUser = null;

      // Clear local storage
      AppLocalStorage.setLoggedIn(false);
      AppLocalStorage.clearUserDetails();
      AppLocalStorage.clearToken();

      AppLogger.print('User logged out successfully');
    } catch (e) {
      AppLogger.print('Logout error: $e');
    }
  }

  /// Check if token is valid and refresh if needed
  Future<bool> validateToken() async {
    try {
      final token = AppLocalStorage.getToken();
      if (token == null) {
        return false;
      }

      // For now, just check if token exists
      // In production, you might want to validate JWT token expiration
      _currentToken = token;
      _currentUser = AppLocalStorage.getUserDetails();

      return _currentUser != null && !_currentUser!.isEmpty;
    } catch (e) {
      AppLogger.print('Token validation error: $e');
      return false;
    }
  }

  /// Initialize authentication state
  Future<void> initialize() async {
    try {
      final isValid = await validateToken();
      if (isValid) {
        AppLogger.print('User session restored');
      } else {
        AppLogger.print('No valid user session found');
      }
    } catch (e) {
      AppLogger.print('Authentication initialization error: $e');
    }
  }
}
