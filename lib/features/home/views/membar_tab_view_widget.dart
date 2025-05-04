import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:secured_calling/core/extensions/date_time_extension.dart';
import 'package:secured_calling/core/models/meeting_model.dart';
import 'package:secured_calling/core/services/app_firebase_service.dart';
import 'package:secured_calling/core/services/permission_service.dart';
import 'package:secured_calling/core/theme/app_theme.dart';
import 'package:secured_calling/features/home/views/meeting_action_card.dart';
import 'package:secured_calling/features/home/views/meeting_util_service.dart';

class MembarTabViewWidget extends StatelessWidget {
  const MembarTabViewWidget({super.key, required this.isMember});
  final bool isMember;
  @override
  Widget build(BuildContext context) {
    if (!isMember) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.workspace_premium,
                size: 72,
                color: AppTheme.secondaryColor,
              ),
              const SizedBox(height: 24),
              Text(
                'Premium Features',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(
                'Upgrade to a premium account to host your own meetings with extended features.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  // Upgrade membership logic would go here
                  // For demo, we'll just set the user as a member
                  // _simulateUpgrade();
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                ),
                child: const Text('Upgrade Now'),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // New meeting action card
          ActionCard(
            title: 'New Meeting',
            icon: Icons.videocam,
            description: 'Start an instant meeting Only Audio',
            buttonText: 'Start Now',
            onPressed: () async {
              final _permissionStatus =
                  await PermissionService.requestPermission(
                    context: context,
                    type: AppPermissionType.microphone,
                  );
              await PermissionService.requestPermission(
                context: context,
                type: AppPermissionType.camera,
              );
              if (_permissionStatus) {
                MeetingUtil.createNewMeeting(context: context, instant: true);
              }
            },
          ),

          // Schedule meeting card
          // ActionCard(
          //   title: 'Schedule Meeting',
          //   icon: Icons.schedule,
          //   description: 'Plan a meeting for later with invites',
          //   buttonText: 'Schedule',
          //   onPressed:
          //       () => MeetingUtil.createNewMeeting(
          //         context: context,
          //         instant: false,
          //       ),
          // ),
          const SizedBox(height: 24),
          Text(
            'Your Meetings',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // Meetings list
          StreamBuilder<QuerySnapshot>(
            stream: AppFirebaseService.instance.getHostMeetingsStream(
              AppFirebaseService.instance.currentUser!.uid,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final meetings = snapshot.data?.docs ?? [];

              if (meetings.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.event_busy,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No meetings yet',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your scheduled and recent meetings will appear here',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: meetings.length,
                itemBuilder: (context, index) {
                  final meeting = MeetingModel.fromJson(
                    meetings[index].data() as Map<String, dynamic>,
                  );
                  final meetingId = meetings[index].id;
                  final status = meeting.status;
                  final isLive = status == 'live';
                  final isScheduled = status == 'scheduled';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      title: Row(
                        children: [
                          Text(
                            meeting.meetingName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  isLive
                                      ? AppTheme.successColor
                                      : isScheduled
                                      ? AppTheme.warningColor
                                      : Colors.grey,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              isLive
                                  ? 'Live'
                                  : isScheduled
                                  ? 'Scheduled'
                                  : 'Ended',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_today,
                                size: 16,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isLive
                                    ? 'Started ${meeting.actualStartTime.formatDateTime}'
                                    : isScheduled
                                    ? 'Scheduled for ${meeting.scheduledStartTime.formatDateTime}'
                                    : 'Ended ${meeting.actualEndTime.formatDateTime}',
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.link,
                                size: 16,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'ID: ${meeting.meetingId}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (isLive) ...[
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.login, size: 16),
                                  label: const Text('Join'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.successColor,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                  ),
                                  onPressed:
                                      () => MeetingUtil.startScheduledMeeting(
                                        channelName: meeting.channelName,
                                        context: context,
                                        meetingId: meetingId,
                                      ),
                                ),
                              ] else if (isScheduled) ...[
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.play_arrow, size: 16),
                                  label: const Text('Start'),
                                  onPressed:
                                      () => MeetingUtil.startScheduledMeeting(
                                        context: context,
                                        meetingId: meetingId,
                                        channelName: meeting.channelName,
                                      ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
