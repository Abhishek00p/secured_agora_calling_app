import 'package:flutter/material.dart';
import 'package:get/state_manager.dart';
import 'package:secured_calling/features/meeting/views/live_meeting_controller.dart';

void showPendingRequestsDialog(BuildContext context) {
  showDialog(
    context: context,
    builder:
        (context) => GetBuilder<MeetingController>(
          builder: (controller) {
            return AlertDialog(
              title: const Text(
                'Meeting Info',
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SelectableText('Meeting Id  : ${controller.meetingId}'),
                  SizedBox(height: 12,),
                  controller.pendingRequests.isEmpty
                      ? const Center(child: Text('No pending requests...'))
                      : ListView.builder(
                        shrinkWrap: true,
                        itemCount: controller.pendingRequests.length,
                        itemBuilder: (context, index) {
                          final request = controller.pendingRequests[index];
                          return ListTile(
                            title: Text(request['name']),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.check,
                                    color: Colors.green,
                                  ),
                                  onPressed: () {
                                    Navigator.pop(context);
                                    // controller.approveJoinRequest(request['userId']);
                                    // TODO:
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.close,
                                    color: Colors.red,
                                  ),
                                  onPressed: () {
                                    Navigator.pop(context);
                                    controller.rejectJoinRequest(
                                      request['userId'],
                                    );
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
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
        ),
  );
}
