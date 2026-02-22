import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Moves the app task to background (same as user pressing Home). Does not terminate the app.
/// User can return via recents or the in-call notification / persistent call bar.
class PipService {
  static const MethodChannel _channel = MethodChannel('com.example.secured_calling/pip');

  /// Moves the app task to background. On Android only; no-op on other platforms.
  static Future<void> moveTaskToBack() async {
    try {
      await _channel.invokeMethod('moveTaskToBack');
    } on PlatformException catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('PipService: moveTaskToBack failed: ${e.message}');
      }
    }
  }
}
