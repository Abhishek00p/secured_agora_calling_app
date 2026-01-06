import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:secured_calling/core/services/app_local_storage.dart';
import 'package:secured_calling/core/services/app_user_role_service.dart';
import 'package:secured_calling/core/services/http_service.dart';

class HttpClientWithInterceptor extends http.BaseClient {
  HttpClientWithInterceptor._internal();

  static final HttpClientWithInterceptor _instance = HttpClientWithInterceptor._internal();

  factory HttpClientWithInterceptor() => _instance;

  final http.Client _inner = http.Client();

  bool _isRefreshingToken = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return _sendWithAuthRetry(request);
  }

  /// 🔁 Handles request + 401 retry
  Future<http.StreamedResponse> _sendWithAuthRetry(http.BaseRequest request, {bool retrying = false}) async {
    // 🔐 Attach token
    final token = await fetchToken();
    if (token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.headers['Content-Type'] = 'application/json';

    debugPrint('➡️ REQUEST ${retrying ? "(RETRY)" : ""}');
    debugPrint('URL: ${request.url}');
    debugPrint('METHOD: ${request.method}');
    debugPrint('HEADERS: ${request.headers}');

    if (request is http.Request) {
      debugPrint('BODY: ${request.body}');
    }

    final streamedResponse = await _inner.send(request);

    final responseBody = await streamedResponse.stream.bytesToString();

    debugPrint('⬅️ RESPONSE');
    debugPrint('STATUS: ${streamedResponse.statusCode}');
    debugPrint('BODY: $responseBody');

    // 🔐 If token expired → refresh & retry once
    if (streamedResponse.statusCode == 401 && !retrying) {
      debugPrint('🔄 401 detected, refreshing token...');

      await _refreshTokenSafely();

      // Clone request before retrying
      final newRequest = _cloneRequest(request);

      return _sendWithAuthRetry(newRequest, retrying: true);
    }

    // Return final response
    return http.StreamedResponse(
      Stream.value(utf8.encode(responseBody)),
      streamedResponse.statusCode,
      headers: streamedResponse.headers,
      reasonPhrase: streamedResponse.reasonPhrase,
      request: streamedResponse.request,
    );
  }

  /// 🔄 Ensure only ONE refresh happens at a time
  Future<void> _refreshTokenSafely() async {
    if (_isRefreshingToken) return;

    _isRefreshingToken = true;
    try {
      final newToken = await refreshToken();
      if (newToken.isEmpty) {
        throw Exception('Failed to refresh token');
      }
    } finally {
      _isRefreshingToken = false;
    }
  }

  /// ♻ Clone request (important for retry)
  http.BaseRequest _cloneRequest(http.BaseRequest request) {
    if (request is http.Request) {
      final newRequest = http.Request(request.method, request.url);
      newRequest.headers.addAll(request.headers);
      newRequest.body = request.body;
      return newRequest;
    }

    if (request is http.MultipartRequest) {
      final newRequest = http.MultipartRequest(request.method, request.url);
      newRequest.headers.addAll(request.headers);
      newRequest.fields.addAll(request.fields);
      newRequest.files.addAll(request.files);
      return newRequest;
    }

    throw UnsupportedError('Request type not supported');
  }

  // 🔐 Existing token fetch (reuse)
  Future<String> fetchToken() async {
    final data = await AppHttpService().get(
      'generateLoginToken',
      queryParams: {
        'userId': AppLocalStorage.getUserDetails().userId.toString(),
        'role':
            AppUserRoleService.isAdmin()
                ? 'admin'
                : AppUserRoleService.isMember()
                ? 'member'
                : 'user',
      },
    );
    return data?['token'] ?? '';
  }

  // 🔄 Force refresh token
  Future<String> refreshToken() async {
    final data = await AppHttpService().get('refreshLoginToken', queryParams: {'userId': AppLocalStorage.getUserDetails().userId.toString()});
    return data?['token'] ?? '';
  }
}
