import 'package:secured_calling/core/services/firebase_function_logger.dart';
import 'package:secured_calling/utils/app_logger.dart';

/// Debug utility for Firebase function calls
/// Use this during testing to easily access and view Firebase function logs
class FirebaseDebugUtil {
  static final FirebaseDebugUtil _instance = FirebaseDebugUtil._();
  static FirebaseDebugUtil get instance => _instance;
  
  // Private constructor
  FirebaseDebugUtil._();
  
  /// Print all Firebase function call logs
  static void printAllLogs() {
    AppLogger.print('🔍 ALL FIREBASE FUNCTION LOGS');
    AppLogger.print('================================');
    
    final logs = FirebaseFunctionLogger.instance.getAllLogs();
    if (logs.isEmpty) {
      AppLogger.print('No logs available');
      return;
    }
    
    for (final log in logs) {
      _printLogDetails(log);
      AppLogger.print('---');
    }
  }
  
  /// Print logs for a specific function
  static void printLogsForFunction(String functionName) {
    AppLogger.print('🔍 LOGS FOR FUNCTION: $functionName');
    AppLogger.print('================================');
    
    final logs = FirebaseFunctionLogger.instance.getLogsForFunction(functionName);
    if (logs.isEmpty) {
      AppLogger.print('No logs found for function: $functionName');
      return;
    }
    
    for (final log in logs) {
      _printLogDetails(log);
      AppLogger.print('---');
    }
  }
  
  /// Print recent logs (last N calls)
  static void printRecentLogs(int count) {
    AppLogger.print('🔍 RECENT $count FIREBASE FUNCTION LOGS');
    AppLogger.print('================================');
    
    final logs = FirebaseFunctionLogger.instance.getRecentLogs(count);
    if (logs.isEmpty) {
      AppLogger.print('No logs available');
      return;
    }
    
    for (final log in logs) {
      _printLogDetails(log);
      AppLogger.print('---');
    }
  }
  
  /// Print summary of all function calls
  static void printSummary() {
    FirebaseFunctionLogger.instance.printSummary();
  }
  
  /// Print failed requests only
  static void printFailedRequests() {
    AppLogger.print('❌ FAILED FIREBASE FUNCTION REQUESTS');
    AppLogger.print('================================');
    
    final logs = FirebaseFunctionLogger.instance.getAllLogs();
    final failedLogs = logs.where((log) => log.status == 'error').toList();
    
    if (failedLogs.isEmpty) {
      AppLogger.print('No failed requests found');
      return;
    }
    
    for (final log in failedLogs) {
      _printLogDetails(log);
      AppLogger.print('---');
    }
  }
  
  /// Print slow requests (requests taking more than specified milliseconds)
  static void printSlowRequests(int thresholdMs) {
    AppLogger.print('🐌 SLOW FIREBASE FUNCTION REQUESTS (>${thresholdMs}ms)');
    AppLogger.print('================================');
    
    final logs = FirebaseFunctionLogger.instance.getAllLogs();
    final slowLogs = logs.where((log) => 
      log.duration != null && log.duration!.inMilliseconds > thresholdMs
    ).toList();
    
    if (slowLogs.isEmpty) {
      AppLogger.print('No slow requests found');
      return;
    }
    
    for (final log in slowLogs) {
      _printLogDetails(log);
      AppLogger.print('---');
    }
  }
  
  /// Export logs to JSON string
  static String exportLogsToJson() {
    return FirebaseFunctionLogger.instance.exportLogsToJson();
  }
  
  /// Clear all logs
  static void clearLogs() {
    FirebaseFunctionLogger.instance.clearLogs();
  }
  
  /// Print detailed log information
  static void _printLogDetails(FunctionCallLog log) {
    AppLogger.print('Request ID: ${log.requestId}');
    AppLogger.print('Function: ${log.functionName}');
    AppLogger.print('Method: ${log.method}');
    AppLogger.print('URL: ${log.url}');
    AppLogger.print('Status: ${log.status}');
    AppLogger.print('Start Time: ${log.startTime.toIso8601String()}');
    
    if (log.endTime != null) {
      AppLogger.print('End Time: ${log.endTime!.toIso8601String()}');
    }
    
    if (log.duration != null) {
      AppLogger.print('Duration: ${log.duration!.inMilliseconds}ms');
    }
    
    if (log.statusCode != null) {
      AppLogger.print('Status Code: ${log.statusCode}');
    }
    
    if (log.error != null) {
      AppLogger.print('Error: ${log.error}');
    }
    
    AppLogger.print('Headers: ${log.headers}');
    AppLogger.print('Request Body: ${log.requestBody}');
    
    if (log.responseBody != null) {
      AppLogger.print('Response Body: ${log.responseBody}');
    }
  }
  
  /// Quick debug commands for testing
  static void quickDebug() {
    AppLogger.print('🚀 FIREBASE DEBUG UTILITY - QUICK COMMANDS');
    AppLogger.print('==========================================');
    AppLogger.print('Available commands:');
    AppLogger.print('1. FirebaseDebugUtil.printSummary() - Show summary');
    AppLogger.print('2. FirebaseDebugUtil.printRecentLogs(5) - Show last 5 calls');
    AppLogger.print('3. FirebaseDebugUtil.printFailedRequests() - Show failed calls');
    AppLogger.print('4. FirebaseDebugUtil.printSlowRequests(1000) - Show slow calls');
    AppLogger.print('5. FirebaseDebugUtil.printLogsForFunction("login") - Show login calls');
    AppLogger.print('6. FirebaseDebugUtil.printAllLogs() - Show all calls');
    AppLogger.print('7. FirebaseDebugUtil.clearLogs() - Clear all logs');
    AppLogger.print('==========================================');
  }
}
