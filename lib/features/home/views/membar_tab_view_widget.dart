import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:secured_calling/core/models/meeting_model.dart';
import 'package:secured_calling/core/services/app_firebase_service.dart';
import 'package:secured_calling/core/services/app_local_storage.dart';
import 'package:secured_calling/core/services/permission_service.dart';
import 'package:secured_calling/core/theme/app_theme.dart';
import 'package:secured_calling/features/home/views/meeting_action_card.dart';
import 'package:secured_calling/features/home/views/meeting_util_service.dart';
import 'package:secured_calling/features/meeting/views/meeting_tile_widget.dart';

class MembarTabViewWidget extends StatelessWidget {
  MembarTabViewWidget({super.key});
  final bool isMember = AppLocalStorage.getUserDetails().isMember;
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
            title: 'Create Meeting',
            icon: Icons.videocam,
            description: 'Set up a new instant or scheduled meeting',
            buttonText: 'Create Meeting',
            onPressed: () async {
              final permissionStatus =
                  await PermissionService.requestPermission(
                    context: context,
                    type: AppPermissionType.microphone,
                  );
              await PermissionService.requestPermission(
                context: context,
                type: AppPermissionType.camera,
              );
              if (permissionStatus) {
                MeetingUtil.createNewMeeting(context: context);
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

              return Column(
                children: List.generate(meetings.length, (index) {
                  final meeting = MeetingModel.fromJson(
                    meetings[index].data() as Map<String, dynamic>,
                  );

                  return MeetingTileWidget(model: meeting);
                }),
              );
            },
          ),
        ],
      ),
    );
  }
}
