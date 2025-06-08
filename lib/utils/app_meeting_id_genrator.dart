import 'dart:math';

import 'package:secured_calling/core/services/app_firebase_service.dart';

class AppMeetingIdGenrator {
  static List<String> _meetingIds = [];
  static Future<bool> _checkIfIdAlreadyExist(String id) async {
    _meetingIds = await AppFirebaseService.instance.getAllMeetDocIds();
    return _meetingIds.contains(id);
  }

  static Future<String> generateMeetingId() async {
    const String chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
        const String digits = '0123456789';

    final Random random = Random();
     // Pattern: [L, L, D, D, L, L]
    final id = [
      chars[random.nextInt(chars.length)],
      chars[random.nextInt(chars.length)],
      digits[random.nextInt(digits.length)],
      digits[random.nextInt(digits.length)],
      chars[random.nextInt(chars.length)],
      chars[random.nextInt(chars.length)],
    ].join();
    final result = await _checkIfIdAlreadyExist(id);
    if (!result) {
      return id;
    } else {
      return generateMeetingId();
    }
  }
}
