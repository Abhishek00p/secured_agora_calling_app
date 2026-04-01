import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:secured_calling/core/config/app_config.dart';
import 'package:secured_calling/core/services/app_local_storage.dart';
import 'package:secured_calling/core/services/firebase_function_logger.dart';
import 'package:secured_calling/utils/app_tost_util.dart';

import '../../utils/app_logger.dart';

class AppHttpService {
  static final AppHttpService _instance = AppHttpService._internal();

  factory AppHttpService() {
    return _instance;
  }

  AppHttpService._internal();

  /// Set from [main] so this layer does not depend on [AppAuthService] (avoids import cycles).
  static Future<void> Function()? _sessionExpiredHandler;

  static void setSessionExpiredHandler(Future<void> Function()? handler) {
    _sessionExpiredHandler = handler;
  }

  /// Call after a successful login so a later 401 can trigger a new session-expired flow.
  static void resetSessionExpiredState() {
    _sessionExpiredFuture = null;
  }

  static Future<void>? _sessionExpiredFuture;

  /// Get the appropriate Firebase Function URL based on platform and environment
  String get firebaseFunctionUrl {
    // if (kDebugMode) {
    //   // Use local emulator in debug mode
    //   if (Platform.isAndroid) {
    // return 'http://192.168.31.226:3000/';
    return AppConfig.baseUrl;
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
        AppLogger.print('Bearer token before api call : $token');
        headers['Authorization'] = 'Bearer $token';
      } else {
        AppLogger.print("No auth token found in local storage, while calling api");
      }
    }

    return headers;
  }

  /// Generic GET request.
  Future<Map<String, dynamic>?> get(String endpoint, {Map<String, String>? queryParams, bool includeAuth = true}) async {
    try {
      final uri = Uri.parse('$firebaseFunctionUrl$endpoint');
      final finalUri = queryParams != null ? uri.replace(queryParameters: queryParams) : uri;

      final response = await _executeRequest(
        functionName: endpoint,
        method: 'GET',
        url: finalUri.toString(),
        body: '',
        includeAuth: includeAuth,
        call: (h) => http.get(finalUri, headers: h),
      );

      return _handleResponse(response);
    } on SocketException {
      AppToastUtil.showErrorToast('No Internet connection');
      rethrow;
    }
  }

  /// Generic POST request
  Future<Map<String, dynamic>?> post(String endpoint, {Map<String, dynamic>? body, bool includeAuth = true}) async {
    try {
      final uri = Uri.parse('$firebaseFunctionUrl$endpoint');
      final requestBody = body != null ? jsonEncode(body) : '';
      final response = await _executeRequest(
        functionName: endpoint,
        method: 'POST',
        url: uri.toString(),
        body: requestBody,
        includeAuth: includeAuth,
        call: (h) => http.post(uri, headers: h, body: requestBody),
      );

      return _handleResponse(response);
    } on SocketException {
      AppToastUtil.showErrorToast('No Internet connection');
      rethrow;
    } catch (e) {
      AppLogger.print('POST request error for $endpoint: $e');
      AppToastUtil.showErrorToast('Request failed: $e');
      rethrow;
    }
  }

  /// Generic PUT request
  Future<Map<String, dynamic>?> put(String endpoint, {Map<String, dynamic>? body, bool includeAuth = true}) async {
    try {
      final uri = Uri.parse('$firebaseFunctionUrl$endpoint');
      final requestBody = body != null ? jsonEncode(body) : '';

      final response = await _executeRequest(
        functionName: endpoint,
        method: 'PUT',
        url: uri.toString(),
        body: requestBody,
        includeAuth: includeAuth,
        call: (h) => http.post(uri, headers: h, body: requestBody),
      );

      return _handleResponse(response);
    } on SocketException {
      AppToastUtil.showErrorToast('No Internet connection');
      rethrow;
    } catch (e) {
      AppLogger.print('PUT request error for $endpoint: $e');
      AppToastUtil.showErrorToast('Request failed: $e');
      rethrow;
    }
  }

  /// Generic DELETE request
  Future<Map<String, dynamic>?> delete(String endpoint, {Map<String, dynamic>? body, bool includeAuth = true}) async {
    try {
      final uri = Uri.parse('$firebaseFunctionUrl$endpoint');
      final requestBody = body != null ? jsonEncode(body) : '';

      final response = await _executeRequest(
        functionName: endpoint,
        method: 'DELETE',
        url: uri.toString(),
        body: requestBody,
        includeAuth: includeAuth,
        call: (h) => http.post(uri, headers: h, body: requestBody),
      );

      return _handleResponse(response);
    } on SocketException {
      AppToastUtil.showErrorToast('No Internet connection');
      rethrow;
    } catch (e) {
      AppLogger.print('DELETE request error for $endpoint: $e');
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
        final errorMessage = errorData['error_message'] ?? errorData['message'] ?? 'Request failed with status ${response.statusCode}';
        return {'success': false, 'error_message': errorMessage, 'statusCode': response.statusCode};
      } catch (e) {
        AppToastUtil.showErrorToast('Request failed with status ${response.statusCode}: ${response.reasonPhrase}');
      }
    }
    return null;
  }

  /// Single HTTP call; on 401 with auth, runs session-expired logout (no refresh, no retry).
  Future<http.Response> _executeRequest({
    required String functionName,
    required String method,
    required String url,
    required String body,
    required bool includeAuth,
    required Future<http.Response> Function(Map<String, String> headers) call,
  }) async {
    final headers = _getHeaders(includeAuth: includeAuth);

    final http.Response response = await AppApiFunctionLogger.instance.logFunctionCall(
      functionName: functionName,
      method: method,
      url: url,
      headers: headers,
      body: body,
      httpCall: () => call(headers),
    );

    if (response.statusCode == 401 && includeAuth) {
      await _runSessionExpiredOnce();
    }

    return response;
  }

  /// Ensures only one session-expired flow (toast, clear, navigate) for concurrent 401s.
  Future<void> _runSessionExpiredOnce() {
    if (_sessionExpiredFuture != null) {
      return _sessionExpiredFuture!;
    }
    _sessionExpiredFuture = _performSessionExpired();
    return _sessionExpiredFuture!;
  }

  Future<void> _performSessionExpired() async {
    final handler = _sessionExpiredHandler;
    if (handler != null) {
      await handler();
    } else {
      AppLogger.print('Session expired but no handler registered; clearing local token only.');
      AppLocalStorage.clearToken();
      AppLocalStorage.clearUserDetails();
      AppLocalStorage.setLoggedIn(false);
    }
  }

}
