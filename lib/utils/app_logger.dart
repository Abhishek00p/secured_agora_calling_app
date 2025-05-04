import 'package:flutter/foundation.dart';

class AppLogger {
  static void print(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }
}
