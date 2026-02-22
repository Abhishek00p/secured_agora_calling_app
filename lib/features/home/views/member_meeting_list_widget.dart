import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:secured_calling/core/models/meeting_model.dart';
import 'package:secured_calling/core/services/app_firebase_service.dart';
import 'package:secured_calling/core/services/app_local_storage.dart';
import 'package:secured_calling/features/meeting/views/meeting_tile_widget.dart';

class MemberMeetingListWidget extends StatelessWidget {
  const MemberMeetingListWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('Your Meetings', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),

        // Meetings list
        StreamBuilder<QuerySnapshot>(
          stream: AppFirebaseService.instance.getHostMeetingsStream(AppLocalStorage.getUserDetails().userId),
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
                      const Icon(Icons.event_busy, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text('No meetings yet', style: Theme.of(context).textTheme.titleMedium),
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
                final meeting = MeetingModel.fromJson(meetings[index].data() as Map<String, dynamic>);
                return MeetingTileWidget(model: meeting);
              }),
            );
          },
        ),
      ],
    );
  }
}
