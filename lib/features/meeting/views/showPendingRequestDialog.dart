import 'package:flutter/material.dart';
import 'package:get/state_manager.dart';
import 'package:secured_calling/core/services/app_firebase_service.dart';
import 'package:secured_calling/features/meeting/views/live_meeting_controller.dart';

void showPendingRequestsDialog(BuildContext context) {
  showDialog(
    context: context,
    builder:
        (context) => GetBuilder<MeetingController>(
          builder: (controller) {
            return FutureBuilder(
              future: AppFirebaseService.instance.getMeetingData(
                controller.meetingId,
              ),
              builder: (context, snapshot) {
                final result = snapshot.data;
                return AlertDialog(
                  title: const Text('Meeting Info'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SelectableText('Meeting Id  : ${result?['meet_id']}'),
                      SelectableText('Password  : ${result?['password']}'),
                      SizedBox(height: 12),
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
