import 'dart:convert';
import 'package:http/http.dart' as http;

class PushNotificationSender {
  final String serverKey = 'YOUR_FIREBASE_SERVER_KEY'; // ⚠️ DON'T EXPOSE IN PRODUCTION

  Future<void> sendNotification({
    required String fcmToken,
    required String title,
    required String body,
    Map<String, String>? dataPayload,
  }) async {
    final url = Uri.parse('https://fcm.googleapis.com/fcm/send');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json', 'Authorization': 'key=$serverKey'},
      body: jsonEncode({
        'to': fcmToken,
        'notification': {'title': title, 'body': body},
        'data': dataPayload ?? {},
      }),
    );

    if (response.statusCode == 200) {
      print('✅ Notification sent: ${response.body}');
    } else {
      print('❌ Failed to send notification: ${response.statusCode} - ${response.body}');
    }
  }
}
