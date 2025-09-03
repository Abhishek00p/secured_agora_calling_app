import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:secured_calling/core/models/app_user_model.dart';
import 'package:secured_calling/core/services/app_local_storage.dart';
import 'package:secured_calling/utils/app_logger.dart';
import 'package:secured_calling/utils/app_tost_util.dart';

class AppAuthService {
  static final AppAuthService _instance = AppAuthService._();
  static AppAuthService get instance => _instance;
  String baseUrl = "https://us-central1-secure-calling-2025.cloudfunctions.net";
  // String baseUrl = 'http://10.0.2.2:5001/secure-calling-2025/us-central1'; // For local testing
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  String? _currentToken;
  AppUser? _currentUser;

  // Private constructor
  AppAuthService._();

  // Getters
  String? get currentToken => _currentToken;
  AppUser? get currentUser => _currentUser;
  bool get isUserLoggedIn => _currentToken != null && _currentUser != null;

  // /// Login user using Firebase Functions
  // Future<Map<String, dynamic>> login({
  //   required String email,
  //   required String password,
  // }) async {
  //   try {
  //     AppLogger.print('Attempting login for: $email');

  //     // Call Firebase Function
  //     final callable = _functions.httpsCallable('login');
  //     final result = await callable.call({
  //       'email': email.trim().toLowerCase(),
  //       'password': password,
  //     });

  //     // Handle type conversion safely
  //     Map<String, dynamic> response;
  //     if (result.data is Map) {
  //       response = Map<String, dynamic>.from(result.data as Map);
  //     } else {
  //       throw Exception('Invalid response format from server');
  //     }

  //     // Check if response has standardized format
  //     if (response.containsKey('success')) {
  //       AppLogger.print("the data recieved from api is : $response");
  //       if (response['success'] == true) {  
  //         // Extract data from standardized response
  //         final encodedJson = json.encode(response['data']);
  //         final data =response['data']!=null?  Map<String, dynamic>.from(json.decode(encodedJson)):{};
          
  //         // Store token and user data
  //         _currentToken = data['token'];
  //         _currentUser = AppUser.fromJson(data['user']);

  //         // Store in local storage
  //         AppLocalStorage.storeUserDetails(_currentUser!);
  //         AppLocalStorage.setLoggedIn(true);
  //         AppLocalStorage.storeToken(_currentToken!);

  //         AppLogger.print('Login successful for user: ${_currentUser!.name}');
  //         return {
  //           'success': true,
  //           'user': _currentUser,
  //           'token': _currentToken,
  //         };
  //       } else {
  //         // Handle error from standardized response
  //         final errorMessage = response['error_message'] ?? 'Login failed';
  //         throw Exception(errorMessage);
  //       }
  //     } else {
  //       // Fallback for non-standardized responses
  //       throw Exception('Invalid response format from server');
  //     }
  //   } on FirebaseFunctionsException catch (e) {
  //     AppLogger.print('Firebase Functions error: ${e.code} - ${e.message}');
  //     String errorMessage = 'Login failed';
      
  //     switch (e.code) {
  //       case 'not-found':
  //         errorMessage = 'User not found';
  //         break;
  //       case 'unauthenticated':
  //         errorMessage = 'Invalid password';
  //         break;
  //       case 'permission-denied':
  //         errorMessage = 'Account is deactivated';
  //         break;
  //       case 'invalid-argument':
  //         errorMessage = 'Invalid email or password format';
  //         break;
  //       default:
  //         errorMessage = e.message ?? 'Login failed';
  //     }
      
  //     throw Exception(errorMessage);
  //   } catch (e) {
  //     AppLogger.print(' Login error in login func of appauthservice.dart: $e');
  //     throw Exception('Login failed in login funcs: $e');
  //   }
  // }

  /// Login user using Firebase Functions (HTTP)
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      AppLogger.print('Attempting login for: $email');

      // Firebase Function HTTP endpoint
      final url = Uri.parse(
        "$baseUrl/login",
      );

      // Send POST request
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          'email': email.trim().toLowerCase(),
          'password': password,
        }),
      );

      // Validate status code
      if (response.statusCode != 200) {
        throw Exception("Login failed with status ${response.statusCode}");
      }

      // Parse response
      final Map<String, dynamic> responseBody = jsonDecode(response.body);

      if (responseBody.containsKey('success')) {
        AppLogger.print("the data received from api is : $responseBody");

        if (responseBody['success'] == true) {
          // Extract token + user
          final data = responseBody['data'] != null
              ? Map<String, dynamic>.from(responseBody['data'])
              : {};

          _currentToken = data['token'];
          _currentUser = AppUser.fromJson(data['user']);

          // Save locally
           AppLocalStorage.storeUserDetails(_currentUser!);
           AppLocalStorage.setLoggedIn(true);
           AppLocalStorage.storeToken(_currentToken!);

          AppLogger.print('Login successful for user: ${_currentUser!.name}');
          return {
            'success': true,
            'user': _currentUser,
            'token': _currentToken,
          };
        } else {
          final errorMessage =
              responseBody['error_message'] ?? 'Login failed';
          throw Exception(errorMessage);
        }
      } else {
        throw Exception("Invalid response format from server");
      }
    } catch (e) {
      AppLogger.print('Login error: $e');
      throw Exception('Login failed: $e');
    }
  }


  // /// Create new user (called by members)
  // Future<bool> createUser({
  //   required String name,
  //   required String email,
  //   required String password,
  //   required String memberCode,
  // }) async {
  //   try {
  //     if (!isUserLoggedIn) {
  //       throw Exception('User not logged in');
  //     }

  //     AppLogger.print('Creating user: $email under member code: $memberCode');

  //     // Call Firebase Function
  //     final callable = _functions.httpsCallable('createUser',);
  //     final result = await callable.call({
  //       'name': name.trim(),
  //       'email': email.trim().toLowerCase(),
  //       'password': password,
  //       'memberCode': memberCode,
  //     });

  //     // Handle type conversion safely
  //     Map<String, dynamic> response;
  //     if (result.data is Map) {
  //       response = Map<String, dynamic>.from(result.data as Map);
  //     } else {
  //       throw Exception('Invalid response format from server');
  //     }

  //     // Check if response has standardized format
  //     if (response.containsKey('success')) {
  //       if (response['success'] == true) {
  //         AppToastUtil.showSuccessToast('User created successfully');
  //         return true;
  //       } else {
  //         final errorMessage = response['error_message'] ?? 'Failed to create user';
  //         throw Exception(errorMessage);
  //       }
  //     } else {
  //       throw Exception('Invalid response format from server');
  //     }
  //   } on FirebaseFunctionsException catch (e) {
  //     AppLogger.print('Create user error: ${e.code} - ${e.message}');
  //     String errorMessage = 'Failed to create user';
      
  //     switch (e.code) {
  //       case 'permission-denied':
  //         errorMessage = 'You do not have permission to create users';
  //         break;
  //       case 'already-exists':
  //         errorMessage = 'User with this email already exists';
  //         break;
  //       case 'invalid-argument':
  //         errorMessage = 'Invalid input data';
  //         break;
  //       default:
  //         errorMessage = e.message ?? 'Failed to create user';
  //     }
      
  //     AppToastUtil.showErrorToast(errorMessage);
  //     return false;
  //   } catch (e) {
  //     AppLogger.print('Create user error: $e');
  //     AppToastUtil.showErrorToast('Failed to create user: $e');
  //     return false;
  //   }
  // }

  /// Create new user (called by members)
  Future<bool> createUser({
    required String name,
    required String email,
    required String password,
    required String memberCode,
  }) async {
    try {
      if (!isUserLoggedIn) {
        throw Exception('User not logged in');
      }

      AppLogger.print('Creating user: $email under member code: $memberCode');

      final url = Uri.parse(
        "$baseUrl/createUser",
      );

      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $_currentToken", // Pass JWT
        },
        body: jsonEncode({
          'name': name.trim(),
          'email': email.trim().toLowerCase(),
          'password': password,
          'memberCode': memberCode,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception("Failed with status ${response.statusCode}");
      }

      final Map<String, dynamic> result = jsonDecode(response.body);

      if (result['success'] == true) {
        AppToastUtil.showSuccessToast('User created successfully');
        return true;
      } else {
        final errorMessage = result['error_message'] ?? 'Failed to create user';
        throw Exception(errorMessage);
      }
    } catch (e) {
      AppLogger.print('Create user error: $e');
      AppToastUtil.showErrorToast('Failed to create user: $e');
      return false;
    }
  }

  // /// Create new member (called by admins)
  // Future<bool> createMember({
  //   required String name,
  //   required String email,
  //   required String password,
  //   required String memberCode,
  //   required DateTime purchaseDate,
  //   required int planDays,
  //   required int maxParticipantsAllowed,
  // }) async {
  //   try {
  //     if (!isUserLoggedIn) {
  //       throw Exception('User not logged in');
  //     }

  //     AppLogger.print('Creating member: $email with member code: $memberCode');

  //     // Call Firebase Function
  //     final callable = _functions.httpsCallable('createMember');
  //     final result = await callable.call({
  //       'name': name.trim(),
  //       'email': email.trim().toLowerCase(),
  //       'password': password,
  //       'memberCode': memberCode,
  //       'purchaseDate': purchaseDate.toIso8601String(),
  //       'planDays': planDays,
  //       'maxParticipantsAllowed': maxParticipantsAllowed,
  //     });

  //     // Handle type conversion safely
  //     Map<String, dynamic> response;
  //     if (result.data is Map) {
  //       response = Map<String, dynamic>.from(result.data as Map);
  //     } else {
  //       throw Exception('Invalid response format from server');
  //     }

  //     // Check if response has standardized format
  //     if (response.containsKey('success')) {
  //       if (response['success'] == true) {
  //         AppToastUtil.showSuccessToast('Member created successfully');
  //         return true;
  //       } else {
  //         final errorMessage = response['error_message'] ?? 'Failed to create member';
  //         throw Exception(errorMessage);
  //       }
  //     } else {
  //       throw Exception('Invalid response format from server');
  //     }
  //   } on FirebaseFunctionsException catch (e) {
  //     AppLogger.print('Create member error: ${e.code} - ${e.message}');
  //     String errorMessage = 'Failed to create member';
      
  //     switch (e.code) {
  //       case 'permission-denied':
  //         errorMessage = 'You do not have permission to create members';
  //         break;
  //       case 'already-exists':
  //         errorMessage = 'User or member code already exists';
  //         break;
  //       case 'invalid-argument':
  //         errorMessage = 'Invalid input data';
  //         break;
  //       default:
  //         errorMessage = e.message ?? 'Failed to create member';
  //     }
      
  //     AppToastUtil.showErrorToast(errorMessage);
  //     return false;
  //   } catch (e) {
  //     AppLogger.print('Create member error: $e');
  //     AppToastUtil.showErrorToast('Failed to create member: $e');
  //     return false;
  //   }
  // }
  /// Create new member (called by admins)
  Future<bool> createMember({
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
        throw Exception('User not logged in');
      }

      AppLogger.print('Creating member: $email with member code: $memberCode');

      final url = Uri.parse(
        "$baseUrl/createMember",
      );

      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $_currentToken", // Pass JWT
        },
        body: jsonEncode({
          'name': name.trim(),
          'email': email.trim().toLowerCase(),
          'password': password,
          'memberCode': memberCode,
          'purchaseDate': purchaseDate.toIso8601String(),
          'planDays': planDays,
          'maxParticipantsAllowed': maxParticipantsAllowed,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception("Failed with status ${response.statusCode}");
      }

      final Map<String, dynamic> result = jsonDecode(response.body);

      if (result['success'] == true) {
        AppToastUtil.showSuccessToast('Member created successfully');
        return true;
      } else {
        final errorMessage = result['error_message'] ?? 'Failed to create member';
        throw Exception(errorMessage);
      }
    } catch (e) {
      AppLogger.print('Create member error: $e');
      AppToastUtil.showErrorToast('Failed to create member: $e');
      return false;
    }
  }

  // /// Reset user password
  // Future<bool> resetPassword({
  //   required String targetEmail,
  //   required String newPassword,
  // }) async {
  //   try {
  //     if (!isUserLoggedIn) {
  //       throw Exception('User not logged in');
  //     }

  //     AppLogger.print('Resetting password for: $targetEmail');

  //     // Call Firebase Function
  //     final callable = _functions.httpsCallable('resetPassword');
  //     final result = await callable.call({
  //       'targetEmail': targetEmail.trim().toLowerCase(),
  //       'newPassword': newPassword,
  //     });

  //     // Handle type conversion safely
  //     Map<String, dynamic> response;
  //     if (result.data is Map) {
  //       response = Map<String, dynamic>.from(result.data as Map);
  //     } else {
  //       throw Exception('Invalid response format from server');
  //     }

  //     // Check if response has standardized format
  //     if (response.containsKey('success')) {
  //       if (response['success'] == true) {
  //         AppToastUtil.showSuccessToast('Password reset successfully');
  //         return true;
  //       } else {
  //         final errorMessage = response['error_message'] ?? 'Failed to reset password';
  //         throw Exception(errorMessage);
  //       }
  //     } else {
  //       throw Exception('Invalid response format from server');
  //     }
  //   } on FirebaseFunctionsException catch (e) {
  //     AppLogger.print('Reset password error: ${e.code} - ${e.message}');
  //     String errorMessage = 'Failed to reset password';
      
  //     switch (e.code) {
  //       case 'permission-denied':
  //         errorMessage = 'You do not have permission to reset this password';
  //         break;
  //       case 'not-found':
  //         errorMessage = 'User not found';
  //         break;
  //       case 'invalid-argument':
  //         errorMessage = 'Invalid input data';
  //         break;
  //       default:
  //         errorMessage = e.message ?? 'Failed to reset password';
  //     }
      
  //     AppToastUtil.showErrorToast(errorMessage);
  //     return false;
  //   } catch (e) {
  //     AppLogger.print('Reset password error: $e');
  //     AppToastUtil.showErrorToast('Failed to reset password: $e');
  //     return false;
  //   }
  // }

  /// Reset user password
  Future<bool> resetPassword({
    required String targetEmail,
    required String newPassword,
  }) async {
    try {
      if (!isUserLoggedIn) throw Exception('User not logged in');

      AppLogger.print('Resetting password for: $targetEmail');

      final url = Uri.parse(
        "$baseUrl/resetPassword",
      );

      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $_currentToken",
        },
        body: jsonEncode({
          'targetEmail': targetEmail.trim().toLowerCase(),
          'newPassword': newPassword,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception("Failed with status ${response.statusCode}");
      }

      final Map<String, dynamic> result = jsonDecode(response.body);

      if (result['success'] == true) {
        AppToastUtil.showSuccessToast('Password reset successfully');
        return true;
      } else {
        final errorMessage =
            result['error_message'] ?? 'Failed to reset password';
        throw Exception(errorMessage);
      }
    } catch (e) {
      AppLogger.print('Reset password error: $e');
      AppToastUtil.showErrorToast('Failed to reset password: $e');
      return false;
    }
  }

  // /// Get user credentials
  // Future<Map<String, dynamic>?> getUserCredentials(String targetEmail) async {
  //   try {
  //     if (!isUserLoggedIn) {
  //       throw Exception('User not logged in');
  //     }

  //     AppLogger.print('Getting credentials for: $targetEmail');

  //     // Call Firebase Function
  //     final callable = _functions.httpsCallable('getUserCredentials');
  //     final result = await callable.call({
  //       'targetEmail': targetEmail.trim().toLowerCase(),
  //     });

  //     // Handle type conversion safely
  //     Map<String, dynamic> response;
  //     if (result.data is Map) {
  //       response = Map<String, dynamic>.from(result.data as Map);
  //     } else {
  //       throw Exception('Invalid response format from server');
  //     }

  //     // Check if response has standardized format
  //     if (response.containsKey('success')) {
  //       if (response['success'] == true) {
  //         final data = response['data'] as Map<String, dynamic>;
  //         return data['credentials'] as Map<String, dynamic>;
  //       } else {
  //         final errorMessage = response['error_message'] ?? 'Failed to get credentials';
  //         throw Exception(errorMessage);
  //       }
  //     } else {
  //       throw Exception('Invalid response format from server');
  //     }
  //   } on FirebaseFunctionsException catch (e) {
  //     AppLogger.print('Get credentials error: ${e.code} - ${e.message}');
  //     String errorMessage = 'Failed to get credentials';
      
  //     switch (e.code) {
  //       case 'permission-denied':
  //         errorMessage = 'You do not have permission to view these credentials';
  //         break;
  //       case 'not-found':
  //         errorMessage = 'User not found';
  //         break;
  //       default:
  //         errorMessage = e.message ?? 'Failed to get credentials';
  //     }
      
  //     AppToastUtil.showErrorToast(errorMessage);
  //     return null;
  //   } catch (e) {
  //     AppLogger.print('Get credentials error: $e');
  //     AppToastUtil.showErrorToast('Failed to get credentials: $e');
  //     return null;
  //   }
  // }
  /// Get user credentials
  Future<Map<String, dynamic>?> getUserCredentials(String targetEmail) async {
    try {
      if (!isUserLoggedIn) throw Exception('User not logged in');

      AppLogger.print('Getting credentials for: $targetEmail');

      final url = Uri.parse(
          "$baseUrl/getUserCredentials",
      );

      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $_currentToken",
        },
        body: jsonEncode({
          'targetEmail': targetEmail.trim().toLowerCase(),
        }),
      );

      if (response.statusCode != 200) {
        throw Exception("Failed with status ${response.statusCode}");
      }

      final Map<String, dynamic> result = jsonDecode(response.body);

      if (result['success'] == true) {
        final data = Map<String, dynamic>.from(result['data']);
        return data['credentials'] as Map<String, dynamic>?;
      } else {
        final errorMessage =
            result['error_message'] ?? 'Failed to get credentials';
        throw Exception(errorMessage);
      }
    } catch (e) {
      AppLogger.print('Get credentials error: $e');
      AppToastUtil.showErrorToast('Failed to get credentials: $e');
      return null;
    }
  }

  // /// Get users for password reset
  // Future<List<Map<String, dynamic>>> getUsersForPasswordReset() async {
  //   try {
  //     if (!isUserLoggedIn) {
  //       throw Exception('User not logged in');
  //     }

  //     AppLogger.print('Getting users for password reset');

  //     // Call Firebase Function
  //     final callable = _functions.httpsCallable('getUsersForPasswordReset');
  //     final result = await callable.call({});

  //     // Handle type conversion safely
  //     Map<String, dynamic> response;
  //     if (result.data is Map) {
  //       response = Map<String, dynamic>.from(result.data as Map);
  //     } else {
  //       throw Exception('Invalid response format from server');
  //     }

  //     // Check if response has standardized format
  //     if (response.containsKey('success')) {
  //       if (response['success'] == true) {
  //         final data = response['data'] as Map<String, dynamic>;
  //         return List<Map<String, dynamic>>.from(data['users'] ?? []);
  //       } else {
  //         final errorMessage = response['error_message'] ?? 'Failed to get users';
  //         throw Exception(errorMessage);
  //       }
  //     } else {
  //       throw Exception('Invalid response format from server');
  //     }
  //   } on FirebaseFunctionsException catch (e) {
  //     AppLogger.print('Get users error: ${e.code} - ${e.message}');
  //     AppToastUtil.showErrorToast('Failed to get users: ${e.message}');
  //     return [];
  //   } catch (e) {
  //     AppLogger.print('Get users error: $e');
  //     AppToastUtil.showErrorToast('Failed to get users: $e');
  //     return [];
  //   }
  // }
  /// Get users for password reset
  Future<List<Map<String, dynamic>>> getUsersForPasswordReset() async {
    try {
      if (!isUserLoggedIn) throw Exception('User not logged in');

      AppLogger.print('Getting users for password reset');

      final url = Uri.parse(
        "$baseUrl/getUsersForPasswordReset",
      );

      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $_currentToken",
        },
        body: jsonEncode({}), // No params needed
      );

      if (response.statusCode != 200) {
        throw Exception("Failed with status ${response.statusCode}");
      }

      final Map<String, dynamic> result = jsonDecode(response.body);

      if (result['success'] == true) {
        final data = Map<String, dynamic>.from(result['data']);
        return List<Map<String, dynamic>>.from(data['users'] ?? []);
      } else {
        final errorMessage = result['error_message'] ?? 'Failed to get users';
        throw Exception(errorMessage);
      }
    } catch (e) {
      AppLogger.print('Get users error: $e');
      AppToastUtil.showErrorToast('Failed to get users: $e');
      return [];
    }
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
