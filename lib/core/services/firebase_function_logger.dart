import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:secured_calling/utils/app_logger.dart';

class AppApiFunctionLogger {
  static final AppApiFunctionLogger _instance = AppApiFunctionLogger._();
  static AppApiFunctionLogger get instance => _instance;

  AppApiFunctionLogger._();

  final List<FunctionCallLog> _logs = [];

  Future<http.Response> logFunctionCall({
    required String functionName,
    required String method,
    required String url,
    required Map<String, String> headers,
    required String body,
    required Future<http.Response> Function() httpCall,
    bool showInConsole = true,
  }) async {
    final startTime = DateTime.now();
    final requestId = _generateRequestId();

    final requestLog = FunctionCallLog(
      requestId: requestId,
      functionName: functionName,
      method: method,
      url: url,
      headers: headers,
      requestBody: body,
      startTime: startTime,
      curl: _generateCurl(method, url, headers, body),
      status: 'pending',
    );

    _logs.insert(0, requestLog);

    if (showInConsole) _logRequest(requestLog);

    try {
      final response = await httpCall();

      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);

      requestLog.endTime = endTime;
      requestLog.duration = duration;
      requestLog.timeTakenMs = duration.inMilliseconds;
      requestLog.statusCode = response.statusCode;
      requestLog.responseBody = response.body;
      requestLog.status = response.statusCode >= 200 && response.statusCode < 300 ? 'success' : 'error';

      if (showInConsole) _logResponse(requestLog);

      return response;
    } catch (e) {
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);

      requestLog.endTime = endTime;
      requestLog.duration = duration;
      requestLog.timeTakenMs = duration.inMilliseconds;
      requestLog.status = 'error';
      requestLog.error = e.toString();

      if (showInConsole) _logError(requestLog);

      rethrow;
    }
  }

  String _generateRequestId() {
    return 'req_${DateTime.now().millisecondsSinceEpoch}_${_logs.length}';
  }

  void _logRequest(FunctionCallLog log) {
    AppLogger.print('🚀 API REQUEST');
    AppLogger.print('${log.method} ${log.url}');
    AppLogger.print('Headers: ${_sanitizeHeaders(log.headers)}');
    AppLogger.print('Body: ${_sanitizeBody(log.requestBody)}');
    AppLogger.print('cURL: ${log.curl}');
    AppLogger.print('---');
  }

  void _logResponse(FunctionCallLog log) {
    AppLogger.print('✅ API RESPONSE');
    AppLogger.print('Status: ${log.statusCode}');
    AppLogger.print('Time: ${log.timeTakenMs}ms');
    AppLogger.print('Response: ${_sanitizeBody(log.responseBody ?? '')}');
    AppLogger.print('---');
  }

  void _logError(FunctionCallLog log) {
    AppLogger.print('❌ API ERROR');
    AppLogger.print('Time: ${log.timeTakenMs}ms');
    AppLogger.print('Error: ${log.error}');
    AppLogger.print('---');
  }

  Map<String, String> _sanitizeHeaders(Map<String, String> headers) {
    final sanitized = Map<String, String>.from(headers);
    if (sanitized.containsKey('Authorization')) {
      sanitized['Authorization'] = 'Bearer [REDACTED]';
    }
    return sanitized;
  }

  String _sanitizeBody(String body) {
    if (body.isEmpty) return body;
    try {
      final Map<String, dynamic> jsonBody = jsonDecode(body);
      final sanitized = Map<String, dynamic>.from(jsonBody);

      if (sanitized.containsKey('password')) sanitized['password'] = '[REDACTED]';
      if (sanitized.containsKey('token')) sanitized['token'] = '[REDACTED]';

      return jsonEncode(sanitized);
    } catch (_) {
      return body;
    }
  }

  String _generateCurl(String method, String url, Map<String, String> headers, String body) {
    final buffer = StringBuffer();
    buffer.write("curl -X $method '$url'");
    headers.forEach((k, v) {
      buffer.write(" -H '$k: $v'");
    });
    if (body.isNotEmpty) {
      final escaped = body.replaceAll("'", r"'\''");
      buffer.write(" -d '$escaped'");
    }
    return buffer.toString();
  }

  List<FunctionCallLog> getAllLogs() => List.unmodifiable(_logs);
  void clearLogs() => _logs.clear();
}

class FunctionCallLog {
  final String requestId;
  final String functionName;
  final String method;
  final String url;
  final Map<String, String> headers;
  final String requestBody;
  final DateTime startTime;
  final String curl;

  DateTime? endTime;
  Duration? duration;
  int? timeTakenMs;
  int? statusCode;
  String? responseBody;
  String? error;
  String status;

  FunctionCallLog({
    required this.requestId,
    required this.functionName,
    required this.method,
    required this.url,
    required this.headers,
    required this.requestBody,
    required this.startTime,
    required this.curl,
    this.status = 'pending',
  });
}
