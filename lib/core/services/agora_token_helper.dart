import 'dart:io';

import 'package:secured_calling/core/services/app_firebase_service.dart';
import 'package:secured_calling/core/services/http_service.dart';
import 'package:secured_calling/utils/app_logger.dart';
import 'package:secured_calling/utils/app_tost_util.dart';

class AgoraTokenHelper {
  /// Get token for a user
  static Future<String?> fetchAgoraToken({
    required String channelName,
    required int uid,

    /// 0 = SUBSCRIBER, 1 = PUBLISHER
    int userRole = 0,
  }) async {
    try {
      final doesTokenExist = await doesTokenAlreadyExistInFirebase(channelName: channelName, uid: uid);
      if (doesTokenExist['exists'] == true) {
        return doesTokenExist['token'];
      }

      // Use the new CRUD function
      final response = await AppHttpService().post('api/agora/token', body: {'channelName': channelName, 'uid': uid, 'userRole': userRole});
      if (response == null) {
        AppToastUtil.showErrorToast('Something went wrong, please try again');
        return null;
      }

      if (response['success'] == true && response['data']['token'] != null) {
        AppLogger.print('token generated successfully from Agora');
        // Store the token in Firebase
        await storeTokenInFirebase(
          channelName: channelName,
          uid: uid,
          token: response['data']['token'],
          expiryTime: response['expireTime'] ?? DateTime.now().add(Duration(hours: 40)).millisecondsSinceEpoch,
        );
        return response['data']['token'];
      } else {
        AppToastUtil.showErrorToast(response['error_message'] ?? "Token not found in response");
      }
    } on SocketException {
      AppToastUtil.showErrorToast('No Internet connection');
      return null;
    } catch (e) {
      AppLogger.print('Error fetching token: $e');
      AppToastUtil.showErrorToast('Error fetching token: $e');
      return null;
    }
    return null;
  }

  /// verify token for a user
  static Future<String?> verifyAgoraToken({required String channelName, required int uid, required String userRole}) async {
    try {
      // Use the new CRUD function
      final response = await AppHttpService().post('verifyToken', body: {'channelName': channelName, 'uid': uid, 'userRole': userRole});
      if (response == null) {
        AppToastUtil.showErrorToast('Something went wrong, please try again');
        return null;
      }

      if (response['success'] == true) {
        AppLogger.print('Token verified successfully');
        return response['token'];
      } else {
        AppToastUtil.showErrorToast(response['error_message'] ?? "Token not found in response");
      }
    } on SocketException {
      AppToastUtil.showErrorToast('No Internet connection');
      return null;
    } catch (e) {
      AppLogger.print('Error verifying token: $e');
      AppToastUtil.showErrorToast('Error verifying token: $e');
      return null;
    }
    return null;
  }

  //store token in firebase
  static Future<void> storeTokenInFirebase({required String channelName, required int uid, required String token, required int expiryTime}) async {
    try {
      final meetingData = await AppFirebaseService.instance.getMeetingData(channelName);
      if (meetingData == null) {
        AppToastUtil.showErrorToast('No meeting data found for the channel');
        return;
      }
      final tokens = meetingData['tokens'] ?? {};
      tokens['$uid'] = {'token': token, 'expiry_time': expiryTime};
      await AppFirebaseService.instance.meetingsCollection.doc(channelName).update({'tokens': tokens});
      AppLogger.print('Token stored successfully');
    } on SocketException {
      AppToastUtil.showErrorToast('No Internet connection');
    } catch (e) {
      AppToastUtil.showErrorToast('Error storing token: $e');
    }
  }

  static Future<Map<String, dynamic>> doesTokenAlreadyExistInFirebase({required String channelName, required int uid}) async {
    try {
      final meetingData = await AppFirebaseService.instance.getMeetingData(channelName);
      if (meetingData == null || meetingData['tokens'] == null || meetingData['tokens']['$uid'] == null) {
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
}
