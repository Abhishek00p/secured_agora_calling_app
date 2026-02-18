import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:secured_calling/core/routes/app_router.dart';
import 'package:secured_calling/core/theme/app_theme.dart';
import 'package:secured_calling/features/meeting/bindings/live_meeting_controller.dart';

/// A persistent bar shown when the user is in an active call but not on the
/// meeting screen. Allows returning to the call or ending it.
class PersistentCallBar extends StatelessWidget {
  const PersistentCallBar({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<MeetingController>()) {
      return const SizedBox.shrink();
    }

    final controller = Get.find<MeetingController>();
    return Obx(() {
      if (!controller.isJoined.value || controller.meetingId.isEmpty) {
        return const SizedBox.shrink();
      }

      final meetingName = controller.meetingModel.value.meetingName;
      final displayName = meetingName.isNotEmpty ? meetingName : 'Ongoing call';

      return Material(
        elevation: 4,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withOpacity(0.3),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: SafeArea(
            // top: false,
            child: Row(
              children: [
                const Icon(Icons.call, color: Colors.white, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'In call',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                      Text(
                        displayName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Get.toNamed(
                      AppRouter.meetingRoomRoute,
                      arguments: {
                        'channelName': controller.channelName,
                        'isHost': controller.isHost,
                        'meetingId': controller.meetingId,
                      },
                    );
                  },
                  child: const Text(
                    'Return',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => _showEndCallConfirmation(context, controller),
                  child: const Text(
                    'End',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  void _showEndCallConfirmation(BuildContext context, MeetingController controller) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('End call?'),
        content: const Text(
          'Do you want to leave the meeting? You can rejoin from the meeting list if needed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await controller.endMeeting();
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('Leave meeting'),
          ),
        ],
      ),
    );
  }
}
