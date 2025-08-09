import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/routes/app_router.dart';
import '../../core/services/app_firebase_service.dart';
import '../../core/services/app_local_storage.dart';
import '../../utils/app_logger.dart';
import '../../utils/app_tost_util.dart';
import '../../features/home/views/meeting_util_service.dart' as legacy_meeting;
import '../models/webinar_user_model.dart';
import '../views/webinar_entry.dart';

/// Wrapper utilities to create/join meetings with an easy switch between
/// legacy meeting room and the new webinar flow.
class WebinarMeetingUtil {
  static final AppFirebaseService _firebaseService = AppFirebaseService.instance;

  /// Create a meeting using the existing create bottom sheet.
  /// If instant, route to either legacy or webinar room based on [useWebinarFlow].
  static Future<void> createMeeting({
    required BuildContext context,
    required bool useWebinarFlow,
    String? agoraAppId,
    String? functionsBaseUrl,
    WebinarRole hostRole = WebinarRole.host,
  }) async {
    final now = DateTime.now();
    String meetingName = 'Meeting ${now.hour}:${now.minute}';

    final result = await legacy_meeting.MeetingUtil.showMeetCreateBottomSheet();
    if (result == null) return;

    try {
      meetingName = result['title'];
      final docRef = await _firebaseService.createMeeting(
        hostId: _firebaseService.currentUser!.uid,
        hostUserId: AppLocalStorage.getUserDetails().userId,
        hostName: AppLocalStorage.getUserDetails().name,
        meetingName: meetingName,
        scheduledStartTime: result['scheduledStart'] ?? now,
        requiresApproval: result['isApprovalRequired'] ?? false,
        maxParticipants: result['maxParticipants'] ?? 45,
        password: result['password']?.isEmpty ?? true ? null : result['password'],
        duration: result['duration'] ?? 60,
      );

      final doc = await docRef.get();
      final meetingData = doc.data() as Map<String, dynamic>;
      final instant = result['isInstant'] ?? false;
      AppLogger.print('Meeting created: ${doc.id}, Instant: $instant, \n Data: $meetingData');
      if (!instant) {
        AppToastUtil.showInfoToast('Meeting "$meetingName" scheduled successfully');
        return;
      }

      final channelName = meetingData['channelName'] ?? doc.id;
      if (useWebinarFlow) {
        final self = _buildSelfUser(role: hostRole);
        _openWebinar(
          context: context,
          appId: agoraAppId!,
          functionsBaseUrl: functionsBaseUrl!,
          roomId: doc.id,
          channelName: channelName,
          self: self,
        );
      } else {
        Navigator.pushNamed(
          context,
          AppRouter.meetingRoomRoute,
          arguments: {
            'channelName': channelName,
            'isHost': true,
            'meetingId': doc.id,
          },
        );
      }
    } catch (e) {
      AppLogger.print('Error creating meeting: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error creating meeting: $e')));
    }
  }

  /// Join an existing meeting by ID using webinar flow when [useWebinarFlow] is true.
  /// If false, falls back to legacy meeting room route.
  static Future<void> joinMeeting({
    required BuildContext context,
    required String meetingId,
    required bool useWebinarFlow,
    String? agoraAppId,
    String? functionsBaseUrl,
  }) async {
    final doc = await FirebaseFirestore.instance.collection('meetings').doc(meetingId).get();
    if (!doc.exists) {
      AppToastUtil.showErrorToast('Meeting not found');
      return;
    }
    final data = doc.data()!;
    final channelName = data['channelName'] ?? meetingId;
    if (!useWebinarFlow) {
      Get.toNamed(
        AppRouter.meetingRoomRoute,
        arguments: {'channelName': channelName, 'isHost': false, 'meetingId': meetingId},
      );
      return;
    }

    // Determine role: host if current user's userId matches hostUserId, else participant
    final currentUserId = AppLocalStorage.getUserDetails().userId;
    final hostUserId = data['hostUserId'];
    final role = (currentUserId == hostUserId) ? WebinarRole.host : WebinarRole.participant;
    final self = _buildSelfUser(role: role);

    _openWebinar(
      context: context,
      appId: agoraAppId!,
      functionsBaseUrl: functionsBaseUrl!,
      roomId: meetingId,
      channelName: channelName,
      self: self,
    );
  }

  /// Start a scheduled meeting (host only). Switchable to webinar flow.
  static Future<void> startScheduled({
    required BuildContext context,
    required String meetingId,
    required String channelName,
    required bool useWebinarFlow,
    String? agoraAppId,
    String? functionsBaseUrl,
  }) async {
    await _firebaseService.startMeeting(meetingId);
    if (!useWebinarFlow) {
      Navigator.pushNamed(
        context,
        AppRouter.meetingRoomRoute,
        arguments: {'channelName': channelName, 'isHost': true, 'meetingId': meetingId},
      );
      return;
    }
    final self = _buildSelfUser(role: WebinarRole.host);
    _openWebinar(
      context: context,
      appId: agoraAppId!,
      functionsBaseUrl: functionsBaseUrl!,
      roomId: meetingId,
      channelName: channelName,
      self: self,
    );
  }

  static WebinarUserModel _buildSelfUser({required WebinarRole role}) {
    final userDetails = AppLocalStorage.getUserDetails();
    final userIdStr = '${userDetails.userId}';
    final agoraUid = userIdStr.hashCode & 0x7fffffff;
    return WebinarUserModel(
      userId: userIdStr,
      agoraUid: agoraUid,
      displayName: userDetails.name,
      role: role,
      isMicMuted: role == WebinarRole.participant,
      canSpeak: role != WebinarRole.participant,
      isKicked: false,
    );
  }

  static void _openWebinar({
    required BuildContext context,
    required String appId,
    required String functionsBaseUrl,
    required String roomId,
    required String channelName,
    required WebinarUserModel self,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WebinarEntryPage(
          appId: appId,
          functionsBaseUrl: functionsBaseUrl,
          roomId: roomId,
          channelName: channelName,
          selfUser: self,
        ),
      ),
    );
  }
}


