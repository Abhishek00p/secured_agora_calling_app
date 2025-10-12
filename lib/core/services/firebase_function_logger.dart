import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:secured_calling/utils/app_logger.dart';

/// Comprehensive Firebase Function Call Logger
/// Tracks all Firebase function calls with detailed logging for debugging
class FirebaseFunctionLogger {
  static final FirebaseFunctionLogger _instance = FirebaseFunctionLogger._();
  static FirebaseFunctionLogger get instance => _instance;

  // Private constructor
  FirebaseFunctionLogger._();

  // Log storage - in production, you might want to use a proper logging service
  final List<FunctionCallLog> _logs = [];

  /// Log a Firebase function call
  Future<http.Response> logFunctionCall({
    required String functionName,
    required String method,
    required String url,
    required Map<String, String> headers,
    required String body,
    required Future<http.Response> Function() httpCall,
  }) async {
    final startTime = DateTime.now();
    final requestId = _generateRequestId();

    // Create request log
    final requestLog = FunctionCallLog(
      requestId: requestId,
      functionName: functionName,
      method: method,
      url: url,
      headers: headers,
      requestBody: body,
      startTime: startTime,
      status: 'pending',
    );

    _logs.add(requestLog);

    // Log request details
    _logRequest(requestLog);

    try {
      // Make the actual HTTP call
      final response = await httpCall();

      // Update log with response
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);

      requestLog.endTime = endTime;
      requestLog.duration = duration;
      requestLog.statusCode = response.statusCode;
      requestLog.responseBody = response.body;
      requestLog.status = response.statusCode >= 200 && response.statusCode < 300 ? 'success' : 'error';

      // Log response details
      _logResponse(requestLog);

      return response;
    } catch (e) {
      // Update log with error
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);

      requestLog.endTime = endTime;
      requestLog.duration = duration;
      requestLog.status = 'error';
      requestLog.error = e.toString();

      // Log error details
      _logError(requestLog);

      rethrow;
    }
  }

  /// Generate unique request ID
  String _generateRequestId() {
    return 'req_${DateTime.now().millisecondsSinceEpoch}_${_logs.length}';
  }

  /// Log request details
  void _logRequest(FunctionCallLog log) {
    AppLogger.print('🚀 FIREBASE FUNCTION REQUEST');
    AppLogger.print('Request ID: ${log.requestId}');
    AppLogger.print('Function: ${log.functionName}');
    AppLogger.print('Method: ${log.method}');
    AppLogger.print('URL: ${log.url}');
    AppLogger.print('Headers: ${_sanitizeHeaders(log.headers)}');
    AppLogger.print('Request Body: ${_sanitizeBody(log.requestBody)}');
    AppLogger.print('Start Time: ${log.startTime.toIso8601String()}');
    AppLogger.print('---');
  }

  /// Log response details
  void _logResponse(FunctionCallLog log) {
    AppLogger.print('✅ FIREBASE FUNCTION RESPONSE');
    AppLogger.print('Request ID: ${log.requestId}');
    AppLogger.print('Function: ${log.functionName}');
    AppLogger.print('Status Code: ${log.statusCode}');
    AppLogger.print('Duration: ${log.duration?.inMilliseconds}ms');
    AppLogger.print('Response Body: ${_sanitizeBody(log.responseBody ?? '')}');
    AppLogger.print('End Time: ${log.endTime?.toIso8601String()}');
    AppLogger.print('Status: ${log.status}');
    AppLogger.print('---');
  }

  /// Log error details
  void _logError(FunctionCallLog log) {
    AppLogger.print('❌ FIREBASE FUNCTION ERROR');
    AppLogger.print('Request ID: ${log.requestId}');
    AppLogger.print('Function: ${log.functionName}');
    AppLogger.print('Duration: ${log.duration?.inMilliseconds}ms');
    AppLogger.print('Error: ${log.error}');
    AppLogger.print('End Time: ${log.endTime?.toIso8601String()}');
    AppLogger.print('Status: ${log.status}');
    AppLogger.print('---');
  }

  /// Sanitize headers to remove sensitive information
  Map<String, String> _sanitizeHeaders(Map<String, String> headers) {
    final sanitized = Map<String, String>.from(headers);

    // Remove or mask sensitive headers
    if (sanitized.containsKey('Authorization')) {
      final auth = sanitized['Authorization']!;
      if (auth.startsWith('Bearer ')) {
        sanitized['Authorization'] = 'Bearer [REDACTED]';
      }
    }

    return sanitized;
  }

  /// Sanitize request/response body to remove sensitive information
  String _sanitizeBody(String body) {
    if (body.isEmpty) return body;

    try {
      final Map<String, dynamic> jsonBody = jsonDecode(body);
      final sanitized = Map<String, dynamic>.from(jsonBody);

      // Remove or mask sensitive fields
      if (sanitized.containsKey('password')) {
        sanitized['password'] = '[REDACTED]';
      }
      if (sanitized.containsKey('token')) {
        sanitized['token'] = '[REDACTED]';
      }
      if (sanitized.containsKey('newPassword')) {
        sanitized['newPassword'] = '[REDACTED]';
      }

      return jsonEncode(sanitized);
    } catch (e) {
      // If not JSON, return as is
      return body;
    }
  }

  /// Get all logs (for debugging purposes)
  List<FunctionCallLog> getAllLogs() {
    return List.from(_logs);
  }

  /// Get logs for a specific function
  List<FunctionCallLog> getLogsForFunction(String functionName) {
    return _logs.where((log) => log.functionName == functionName).toList();
  }

  /// Get recent logs (last N logs)
  List<FunctionCallLog> getRecentLogs(int count) {
    final startIndex = _logs.length - count;
    return startIndex >= 0 ? _logs.sublist(startIndex) : _logs;
  }

  /// Clear all logs
  void clearLogs() {
    _logs.clear();
    AppLogger.print('🧹 Firebase function logs cleared');
  }

  /// Export logs to JSON string (for debugging)
  String exportLogsToJson() {
    final logsJson = _logs.map((log) => log.toJson()).toList();
    return jsonEncode(logsJson);
  }

  /// Print summary of recent function calls
  void printSummary() {
    AppLogger.print('📊 FIREBASE FUNCTION CALLS SUMMARY');
    AppLogger.print('Total calls: ${_logs.length}');

    if (_logs.isEmpty) {
      AppLogger.print('No function calls recorded');
      return;
    }

    // Group by function name
    final functionStats = <String, int>{};
    final errorStats = <String, int>{};

    for (final log in _logs) {
      functionStats[log.functionName] = (functionStats[log.functionName] ?? 0) + 1;
      if (log.status == 'error') {
        errorStats[log.functionName] = (errorStats[log.functionName] ?? 0) + 1;
      }
    }

    AppLogger.print('Function call counts:');
    functionStats.forEach((function, count) {
      final errorCount = errorStats[function] ?? 0;
      final successRate = ((count - errorCount) / count * 100).toStringAsFixed(1);
      AppLogger.print('  $function: $count calls (${successRate}% success)');
    });

    // Average response time
    final successfulLogs = _logs.where((log) => log.duration != null && log.status == 'success').toList();
    if (successfulLogs.isNotEmpty) {
      final avgDuration =
          successfulLogs.map((log) => log.duration!.inMilliseconds).reduce((a, b) => a + b) / successfulLogs.length;
      AppLogger.print('Average response time: ${avgDuration.toStringAsFixed(0)}ms');
    }

    AppLogger.print('---');
  }
}

/// Data class for function call logs
class FunctionCallLog {
  final String requestId;
  final String functionName;
  final String method;
  final String url;
  final Map<String, String> headers;
  final String requestBody;
  final DateTime startTime;

  DateTime? endTime;
  Duration? duration;
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
    this.status = 'pending',
  });

  Map<String, dynamic> toJson() {
    return {
      'requestId': requestId,
      'functionName': functionName,
      'method': method,
      'url': url,
      'headers': headers,
      'requestBody': requestBody,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'duration': duration?.inMilliseconds,
      'statusCode': statusCode,
      'responseBody': responseBody,
      'error': error,
      'status': status,
    };
  }
}
