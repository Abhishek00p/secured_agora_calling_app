import 'dart:convert';
import 'dart:io';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:http/http.dart' as http;
import 'package:secured_calling/core/services/app_firebase_service.dart';
import 'package:secured_calling/core/services/app_auth_service.dart';
import 'package:secured_calling/core/services/firebase_function_logger.dart';
import 'package:secured_calling/utils/app_tost_util.dart';

class AppHttpService {
  static final AppHttpService _instance = AppHttpService._internal();

  factory AppHttpService() {
    return _instance;
  }

  AppHttpService._internal();

  /// Replace this with your actual Firebase Function URL
  final String firebaseFunctionUrl = 
  // 'http://10.0.2.2:5001/secure-calling-2025/us-central1';

      'https://us-central1-secure-calling-2025.cloudfunctions.net';

  /// Get token for a user
  Future<String?> fetchAgoraToken({
    required String channelName,
    required int uid,

    /// 0 = SUBSCRIBER, 1 = PUBLISHER
    int userRole = 0,
  }) async {
    try {
      final doesTokenExist = await doesTokenAlreadyExistInFirebase(
        channelName: channelName,
        uid: uid,
      );
      if (doesTokenExist['exists'] == true) {
        return doesTokenExist['token'];
      }

      // Get authentication token
      final authToken = await _getAuthToken();
      if (authToken == null) {
        throw Exception('User not authenticated');
      }

      final uri = Uri.parse('$firebaseFunctionUrl/generateToken');
      final requestBody = jsonEncode({
        'channelName': channelName,
        'uid': uid,
        'userRole': userRole,
      });

      final response = await FirebaseFunctionLogger.instance.logFunctionCall(
        functionName: 'generateToken',
        method: 'POST',
        url: uri.toString(),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: requestBody,
        httpCall: () => http.post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $authToken',
          },
          body: requestBody,
        ),
      );

      if (response.statusCode == 200) {
        print('token generated successfully from Agora');
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['token'] != null) {
          // Store the token in Firebase
          await storeTokenInFirebase(
            channelName: channelName,
            uid: uid,
            token: data['token'],
            expiryTime: data['expireTime'] ?? 
                DateTime.now().add(Duration(hours: 40)).millisecondsSinceEpoch,
          );
          return data['token'];
        } else {
          throw Exception(data['error_message'] ?? "Token not found in response");
        }
      } else {
        print('Not 200 response: ${response.body}');
        final errorData = jsonDecode(response.body);
        throw Exception(
          "Failed: ${errorData['error_message'] ?? response.reasonPhrase}",
        );
      }
    } on SocketException {
      AppToastUtil.showErrorToast('No Internet connection');
      return null;
    } catch (e) {
      print('Error fetching token: $e');
      AppToastUtil.showErrorToast('Error fetching token: $e');
      return null;
    }
  }

  /// Get authentication token from AppAuthService
  Future<String?> _getAuthToken() async {
    try {
      return AppAuthService.instance.currentToken;
    } catch (e) {
      print('Error getting auth token: $e');
      return null;
    }
  }

  //store token in firebase
  Future<void> storeTokenInFirebase({
    required String channelName,
    required int uid,
    required String token,
    required int expiryTime,
  }) async {
    try {
      final meetingData = await AppFirebaseService.instance.getMeetingData(
        channelName,
      );
      if (meetingData == null) {
        AppToastUtil.showErrorToast('No meeting data found for the channel');
        return;
      }
      final tokens = meetingData['tokens'] ?? {};
      tokens['$uid'] = {'token': token, 'expiry_time': expiryTime};
      await AppFirebaseService.instance.meetingsCollection
          .doc(channelName)
          .update({'tokens': tokens});
      AppToastUtil.showSuccessToast('Token stored successfully');
    } on SocketException {
      AppToastUtil.showErrorToast('No Internet connection');
    } catch (e) {
      AppToastUtil.showErrorToast('Error storing token: $e');
    }
  }

  Future<Map<String, dynamic>> doesTokenAlreadyExistInFirebase({
    required String channelName,
    required int uid,
  }) async {
    try {
      final meetingData = await AppFirebaseService.instance.getMeetingData(
        channelName,
      );
      if (meetingData == null ||
          meetingData['tokens'] == null ||
          meetingData['tokens']['$uid'] == null) {
        return {'exists': false}; // No meeting data found for the channel
      }
      final expiryTime = meetingData['tokens']['$uid']['expiry_time'];
      if (expiryTime == null) {
        return {'exists': false}; // Token or expiry time not found
      }
      final token = meetingData['tokens']['$uid']['token'];
      if (token == null || token.isEmpty) {
        return {'exists': false}; // Token not found
      }
      final expiryDate = DateTime.fromMillisecondsSinceEpoch(expiryTime);
      if (expiryDate.isBefore(DateTime.now())) {
        return {'exists': false}; // Token has expired
      } else {
        return {'exists': true, 'token': token}; // Token exists and is valid
      }
    } on SocketException {
      AppToastUtil.showErrorToast('No Internet connection');
      return {'exists': false}; // No internet connection
    } catch (e) {
      AppToastUtil.showErrorToast('Error checking token existence: $e');
      return {'exists': false}; // Error occurred
    }
  }

  /// send Notification to user

  Future<void> sendPushNotification({
    required String fcmToken,
    required String title,
    required String body,
    Map<String, dynamic>? payload,
  }) async {
    try {
      final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable(
        'sendNotification',
      );

      final response = await callable.call({
        'fcmToken': fcmToken,
        'title': title,
        'body': body,
        'payload': payload ?? {},
      });

      print('Notification sent: ${response.data}');
    } catch (e) {
      print('Error sending notification: $e');
    }
  }
}
