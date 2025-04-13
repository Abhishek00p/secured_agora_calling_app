import 'package:flutter/material.dart';
import 'package:secured_calling/app_tost_util.dart';
import 'package:secured_calling/core/routes/app_router.dart';
import 'package:secured_calling/core/services/app_firebase_service.dart';

class MeetingUtil {
  static final AppFirebaseService firebaseService = AppFirebaseService.instance;
  static Future<void> createNewMeeting({
    required BuildContext context,
    required bool instant,
  }) async {
    final now = DateTime.now();
    final meetingName = 'Meeting ${now.hour}:${now.minute}';

    try {
      final docRef = await firebaseService.createMeeting(
        hostId: firebaseService.currentUser!.uid,
        meetingName: meetingName,
        scheduledStartTime: now,
        duration: 60, // 1 hour meeting
      );

      final doc = await docRef.get();
      final meetingData = doc.data() as Map<String, dynamic>;

      if (instant) {
        await firebaseService.startMeeting(doc.id);

        if (context.mounted) {
          Navigator.pushNamed(
            context,
            AppRouter.meetingRoomRoute,
            arguments: {
              'channelName': meetingData['channelName'] ?? 'default_channel',
              'isHost': true,
            },
          );
        }
      } else {
        if (context.mounted) {
          AppToastUtil.showErrorToast(
            context,
            'Meeting "$meetingName" scheduled successfully',
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error creating meeting: $e')));
      }
    }
  }

  static Future<void> startScheduledMeeting({
    required BuildContext context,
    required String meetingId,
    required String channelName,
  }) async {
    try {
      await firebaseService.startMeeting(meetingId);

      if (context.mounted) {
        Navigator.pushNamed(
          context,
          AppRouter.meetingRoomRoute,
          arguments: {'channelName': channelName, 'isHost': true},
        );
      }
    } catch (e) {
      if (context.mounted) {
        AppToastUtil.showErrorToast(context, 'Error starting meeting: $e');
      }
    }
  }
}
