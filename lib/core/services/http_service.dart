import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:secured_calling/core/config/app_config.dart';
import 'package:secured_calling/core/services/app_local_storage.dart';
import 'package:secured_calling/core/services/firebase_function_logger.dart';
import 'package:secured_calling/utils/app_logger.dart';
import 'package:secured_calling/utils/app_tost_util.dart';

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
    // return 'http://192.168.31.226:3000/';
    return AppConfig.baseUrl.isEmpty ? 'https://18b4247dda9c.ngrok-free.app/' : AppConfig.baseUrl;
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
  Future<Map<String, dynamic>?> get(String endpoint, {Map<String, String>? queryParams, bool includeAuth = true}) async {
    try {
      final uri = Uri.parse('$firebaseFunctionUrl$endpoint');
      final finalUri = queryParams != null ? uri.replace(queryParameters: queryParams) : uri;

      final response = await _executeWithRefresh(
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
      final response = await _executeWithRefresh(
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

      final response = await _executeWithRefresh(
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

      final response = await _executeWithRefresh(
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
        final errorMessage = errorData['error_message'] ?? errorData['message'] ?? 'Request failed with status ${response.statusCode}';
        return {'success': false, 'error_message': errorMessage};
      } catch (e) {
        AppToastUtil.showErrorToast('Request failed with status ${response.statusCode}: ${response.reasonPhrase}');
      }
    }
  }

  bool _isRefreshing = false;
  Future<void>? _refreshFuture;

  Future<http.Response> _executeWithRefresh({
    required String functionName,
    required String method,
    required String url,
    required String body,
    required bool includeAuth,
    required Future<http.Response> Function(Map<String, String> headers) call,
  }) async {
    Map<String, String> headers = _getHeaders(includeAuth: includeAuth);

    http.Response response = await AppApiFunctionLogger.instance.logFunctionCall(
      functionName: functionName,
      method: method,
      url: url,
      headers: headers,
      body: body,
      httpCall: () => call(headers),
    );

    if (response.statusCode != 401 || !includeAuth) {
      return response;
    }

    // Token expired → refresh
    await _refreshTokenOnce();

    // Retry once with new token
    headers = _getHeaders(includeAuth: includeAuth);

    return AppApiFunctionLogger.instance.logFunctionCall(
      functionName: '$functionName (retry)',
      method: method,
      url: url,
      headers: headers,
      body: body,
      httpCall: () => call(headers),
    );
  }

  Future<void> _refreshTokenOnce() async {
    if (_isRefreshing) {
      await _refreshFuture;
      return;
    }

    _isRefreshing = true;
    _refreshFuture = _refreshToken();

    try {
      await _refreshFuture;
    } finally {
      _isRefreshing = false;
    }
  }

  Future<void> _refreshToken() async {
    final response = await get('api/auth/refreshLoginToken', queryParams: {'userId': AppLocalStorage.getUserDetails().userId.toString()});

    if (response != null && response['success'] != true) {
      throw Exception('Session expired');
    }

    final newToken = response?['token'] ?? '';

    if (newToken == null || newToken.isEmpty) {
      throw Exception('Invalid refresh response');
    }

    AppLocalStorage.storeToken(newToken);
  }
}
