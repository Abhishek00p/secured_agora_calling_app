import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:secured_calling/core/services/app_firebase_service.dart';
import 'package:secured_calling/core/services/app_local_storage.dart';
import 'package:secured_calling/core/services/firebase_function_logger.dart';
import 'package:secured_calling/utils/app_tost_util.dart';
import 'package:flutter/foundation.dart';

class AppHttpService {
  static final AppHttpService _instance = AppHttpService._internal();

  factory AppHttpService() {
    return _instance;
  }

  AppHttpService._internal();

  /// Get the appropriate Firebase Function URL based on platform and environment
  String get firebaseFunctionUrl {
    // if (kDebugMode) {
    //   // Use local emulator in debug mode
    //   if (Platform.isAndroid) {
        return 'http://192.168.31.126:5001/secure-calling-2025/us-central1/';
    //   } else if (Platform.isIOS || Platform.isMacOS || Platform.isAndroid) {
    //     return 'http://127.0.0.1:5001/secure-calling-2025/us-central1/';
    //   } else {
    //     return 'http://localhost:4000/secure-calling-2025/us-central1/';
    //   }
    // } else {
    // Use production URL in release mode
    // return 'https://us-central1-secure-calling-2025.cloudfunctions.net/';
    // }
  }

  /// Request interceptor that adds Bearer token to headers
  Map<String, String> _getHeaders({bool includeAuth = true}) {
    final headers = {'Content-Type': 'application/json'};

    if (includeAuth) {
      final token = AppLocalStorage.getToken();
      if (token != null && token.isNotEmpty) {
        print('Bearer token before api call : $token');
        headers['Authorization'] = 'Bearer $token';
      } else {
        print("No auth token found in local storage, while calling api");
      }
    }

    return headers;
  }

  /// Generic GET request
  Future<Map<String, dynamic>?> get(
    String endpoint, {
    Map<String, String>? queryParams,
    bool includeAuth = true,
  }) async {
    try {
      final uri = Uri.parse('$firebaseFunctionUrl$endpoint');
      final finalUri = queryParams != null ? uri.replace(queryParameters: queryParams) : uri;

      final response = await FirebaseFunctionLogger.instance.logFunctionCall(
        functionName: endpoint,
        method: 'GET',
        url: finalUri.toString(),
        headers: _getHeaders(includeAuth: includeAuth),
        body: '',
        httpCall: () => http.get(finalUri, headers: _getHeaders(includeAuth: includeAuth)),
      );

      return _handleResponse(response);
    } on SocketException {
      AppToastUtil.showErrorToast('No Internet connection');
      rethrow;
    } catch (e) {
      print('GET request error for $endpoint: $e');
      AppToastUtil.showErrorToast('Request failed: $e');
      rethrow;
    }
  }

  /// Generic POST request
  Future<Map<String, dynamic>?> post(String endpoint, {Map<String, dynamic>? body, bool includeAuth = true}) async {
    try {
      final uri = Uri.parse('$firebaseFunctionUrl$endpoint');
      final requestBody = body != null ? jsonEncode(body) : '';

      final response = await FirebaseFunctionLogger.instance.logFunctionCall(
        functionName: endpoint,
        method: 'POST',
        url: uri.toString(),
        headers: _getHeaders(includeAuth: includeAuth),
        body: requestBody,
        httpCall: () => http.post(uri, headers: _getHeaders(includeAuth: includeAuth), body: requestBody),
      );

      return _handleResponse(response);
    } on SocketException {
      AppToastUtil.showErrorToast('No Internet connection');
      rethrow;
    } catch (e) {
      print('POST request error for $endpoint: $e');
      AppToastUtil.showErrorToast('Request failed: $e');
      rethrow;
    }
  }

  /// Generic PUT request
  Future<Map<String, dynamic>?> put(String endpoint, {Map<String, dynamic>? body, bool includeAuth = true}) async {
    try {
      final uri = Uri.parse('$firebaseFunctionUrl$endpoint');
      final requestBody = body != null ? jsonEncode(body) : '';

      final response = await FirebaseFunctionLogger.instance.logFunctionCall(
        functionName: endpoint,
        method: 'PUT',
        url: uri.toString(),
        headers: _getHeaders(includeAuth: includeAuth),
        body: requestBody,
        httpCall: () => http.put(uri, headers: _getHeaders(includeAuth: includeAuth), body: requestBody),
      );

      return _handleResponse(response);
    } on SocketException {
      AppToastUtil.showErrorToast('No Internet connection');
      rethrow;
    } catch (e) {
      print('PUT request error for $endpoint: $e');
      AppToastUtil.showErrorToast('Request failed: $e');
      rethrow;
    }
  }

  /// Generic DELETE request
  Future<Map<String, dynamic>?> delete(String endpoint, {Map<String, dynamic>? body, bool includeAuth = true}) async {
    try {
      final uri = Uri.parse('$firebaseFunctionUrl$endpoint');
      final requestBody = body != null ? jsonEncode(body) : '';

      final response = await FirebaseFunctionLogger.instance.logFunctionCall(
        functionName: endpoint,
        method: 'DELETE',
        url: uri.toString(),
        headers: _getHeaders(includeAuth: includeAuth),
        body: requestBody,
        httpCall: () => http.delete(uri, headers: _getHeaders(includeAuth: includeAuth), body: requestBody),
      );

      return _handleResponse(response);
    } on SocketException {
      AppToastUtil.showErrorToast('No Internet connection');
      rethrow;
    } catch (e) {
      print('DELETE request error for $endpoint: $e');
      AppToastUtil.showErrorToast('Request failed: $e');
      rethrow;
    }
  }

  /// Handle HTTP response and return standardized format
  Map<String, dynamic>? _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        return jsonDecode(response.body);
      } catch (e) {
        AppToastUtil.showErrorToast('Invalid JSON response: $e');
      }
    } else {
      try {
        final errorData = jsonDecode(response.body);
        final errorMessage =
            errorData['error_message'] ?? errorData['message'] ?? 'Request failed with status ${response.statusCode}';
        return {'success': false, 'error_message': errorMessage};
      } catch (e) {
        AppToastUtil.showErrorToast('Request failed with status ${response.statusCode}: ${response.reasonPhrase}');
      }
    }
  }

  /// Get token for a user
  Future<String?> fetchAgoraToken({
    required String channelName,
    required int uid,

    /// 0 = SUBSCRIBER, 1 = PUBLISHER
    int userRole = 0,
  }) async {
    try {
      final doesTokenExist = await doesTokenAlreadyExistInFirebase(channelName: channelName, uid: uid);
      if (doesTokenExist['exists'] == true) {
        return doesTokenExist['token'];
      }

      // Use the new CRUD function
      final response = await post(
        'generateToken',
        body: {'channelName': channelName, 'uid': uid, 'userRole': userRole},
      );
      if (response == null) {
        AppToastUtil.showErrorToast('Something went wrong, please try again');
        return null;
      }

      if (response['success'] == true && response['token'] != null) {
        print('token generated successfully from Agora');
        // Store the token in Firebase
        await storeTokenInFirebase(
          channelName: channelName,
          uid: uid,
          token: response['token'],
          expiryTime: response['expireTime'] ?? DateTime.now().add(Duration(hours: 40)).millisecondsSinceEpoch,
        );
        return response['token'];
      } else {
        AppToastUtil.showErrorToast(response['error_message'] ?? "Token not found in response");
      }
    } on SocketException {
      AppToastUtil.showErrorToast('No Internet connection');
      return null;
    } catch (e) {
      print('Error fetching token: $e');
      AppToastUtil.showErrorToast('Error fetching token: $e');
      return null;
    }
  }

  /// verify token for a user
  Future<String?> verifyAgoraToken({required String channelName, required int uid, required String userRole}) async {
    try {
      // Use the new CRUD function
      final response = await post('verifyToken', body: {'channelName': channelName, 'uid': uid, 'userRole': userRole});
      if (response == null) {
        AppToastUtil.showErrorToast('Something went wrong, please try again');
        return null;
      }

      if (response['success'] == true) {
        print('Token verified successfully');
        return response['token'];
      } else {
        AppToastUtil.showErrorToast(response['error_message'] ?? "Token not found in response");
      }
    } on SocketException {
      AppToastUtil.showErrorToast('No Internet connection');
      return null;
    } catch (e) {
      print('Error verifying token: $e');
      AppToastUtil.showErrorToast('Error verifying token: $e');
      return null;
    }
  }

  //store token in firebase
  Future<void> storeTokenInFirebase({
    required String channelName,
    required int uid,
    required String token,
    required int expiryTime,
  }) async {
    try {
      final meetingData = await AppFirebaseService.instance.getMeetingData(channelName);
      if (meetingData == null) {
        AppToastUtil.showErrorToast('No meeting data found for the channel');
        return;
      }
      final tokens = meetingData['tokens'] ?? {};
      tokens['$uid'] = {'token': token, 'expiry_time': expiryTime};
      await AppFirebaseService.instance.meetingsCollection.doc(channelName).update({'tokens': tokens});
      AppToastUtil.showSuccessToast('Token stored successfully');
    } on SocketException {
      AppToastUtil.showErrorToast('No Internet connection');
    } catch (e) {
      AppToastUtil.showErrorToast('Error storing token: $e');
    }
  }

  Future<Map<String, dynamic>> doesTokenAlreadyExistInFirebase({required String channelName, required int uid}) async {
    try {
      final meetingData = await AppFirebaseService.instance.getMeetingData(channelName);
      if (meetingData == null || meetingData['tokens'] == null || meetingData['tokens']['$uid'] == null) {
        return {'exists': false}; // No meeting data found for the channel
      }
      final expiryTime = meetingData['tokens']['$uid']['expiry_time'];
      if (expiryTime == null) {
        return {'exists': false}; // Token or expiry time not found
      }
      final token = meetingData['tokens']['$uid']['token'];
      if (token == null || token.isEmpty) {
        return {'exists': false}; // Token not found
      }
      final expiryDate = DateTime.fromMillisecondsSinceEpoch(expiryTime);
      if (expiryDate.isBefore(DateTime.now())) {
        return {'exists': false}; // Token has expired
      } else {
        return {'exists': true, 'token': token}; // Token exists and is valid
      }
    } on SocketException {
      AppToastUtil.showErrorToast('No Internet connection');
      return {'exists': false}; // No internet connection
    } catch (e) {
      AppToastUtil.showErrorToast('Error checking token existence: $e');
      return {'exists': false}; // Error occurred
    }
  }

  /// send Notification to user
  Future<void> sendPushNotification({
    required String fcmToken,
    required String title,
    required String body,
    Map<String, dynamic>? payload,
  }) async {
    try {
      final response = await post(
        'sendNotification',
        body: {'fcmToken': fcmToken, 'title': title, 'body': body, 'payload': payload ?? {}},
      );

      print('Notification sent: $response');
    } catch (e) {
      print('Error sending notification: $e');
    }
  }
}
