import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Shows or hides the persistent "In call" notification on Android.
/// User can tap the notification to return to the app; closing PIP does not end the meeting.
class CallNotificationService {
  static const MethodChannel _channel =
      MethodChannel('com.example.secured_calling/call_notification');

  /// Show persistent ongoing call notification. Pass [meetingName] for the subtitle.
  static Future<void> startOngoingCallNotification({
    String meetingName = 'Meeting',
  }) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('startOngoingCallNotification', {
        'meetingName': meetingName,
      });
    } on PlatformException catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('CallNotificationService: start failed: ${e.message}');
      }
    }
  }

  /// Remove the ongoing call notification (e.g. when user leaves the meeting).
  static Future<void> stopOngoingCallNotification() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('stopOngoingCallNotification');
    } on PlatformException catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('CallNotificationService: stop failed: ${e.message}');
      }
    }
  }
}
