import 'package:flutter/material.dart';
import 'package:get/state_manager.dart';
import 'package:secured_calling/core/services/app_firebase_service.dart';
import 'package:secured_calling/core/services/app_local_storage.dart';
import 'package:secured_calling/features/meeting/bindings/live_meeting_controller.dart';
import 'package:secured_calling/features/meeting/widgets/extend_meeting_dialog.dart';
import 'package:secured_calling/utils/app_tost_util.dart';

void showMeetingInfo(BuildContext context) {
  showDialog(
    context: context,
    builder:
        (context) => GetBuilder<MeetingController>(
          builder: (controller) {
            final currentUser = AppLocalStorage.getUserDetails();
            final isHost =
                controller.meetingModel.value.hostId ==
                currentUser.firebaseUserId;

            return FutureBuilder(
              future: AppFirebaseService.instance.getMeetingData(
                controller.meetingId,
              ),
              builder: (context, snapshot) {
                final result = snapshot.data;
                return AlertDialog(
                  title: const Text('Meeting Settings'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Meeting Info Section
                      const Text(
                        'Meeting Information',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SelectableText('Meeting Id: ${result?['meet_id']}'),
                      SelectableText('Password: ${result?['password']}'),

                      const SizedBox(height: 16),

                      // Host Controls Section
                      if (isHost) ...[
                        const Text(
                          'Host Controls',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context); // Close current dialog
                              _showExtendMeetingDialog(context, controller);
                            },
                            icon: const Icon(Icons.schedule),
                            label: const Text('Extend Meeting'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                );
              },
            );
          },
        ),
  );
}

void _showExtendMeetingDialog(
  BuildContext context,
  MeetingController controller,
) {
  showDialog(
    context: context,
    builder:
        (context) => ExtendMeetingDialog(
          meetingId: controller.meetingId,
          meetingTitle: controller.meetingModel.value.meetingName,
          onExtend: (additionalMinutes, reason) async {
            try {
              await controller.extendMeetingWithOptions(
                additionalMinutes: additionalMinutes,
                reason: reason,
              );
              return true;
            } catch (e) {
              AppToastUtil.showErrorToast('Failed to extend meeting: $e');
              return false;
            }
          },
        ),
  );
}
