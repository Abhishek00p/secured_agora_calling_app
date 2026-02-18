import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Central place to request Picture-in-Picture mode.
/// Used when app goes to background during an active call (from meeting screen or any other screen).
class PipService {
  static const MethodChannel _channel = MethodChannel('com.example.secured_calling/pip');

  /// Request the platform to enter Picture-in-Picture mode.
  /// No-op if PIP is not supported (e.g. old Android, iOS has different rules).
  static Future<void> enterPipMode() async {
    try {
      await _channel.invokeMethod('enterPipMode');
    } on PlatformException catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('PipService: enterPipMode failed: ${e.message}');
      }
    }
  }
}
