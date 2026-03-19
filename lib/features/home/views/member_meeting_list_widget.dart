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
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Text('Your Meetings', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),

        // Meetings list: all meetings for this member's memberCode, descending order
        StreamBuilder<QuerySnapshot>(
          stream: AppFirebaseService.instance.getUpcomingMeetingsStream(AppLocalStorage.getUserDetails().memberCode),
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
                final doc = meetings[index];
                final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
                data['meet_id'] ??= doc.id;
                final meeting = MeetingModel.fromJson(data);
                return MeetingTileWidget(model: meeting);
              }),
            );
          },
        ),
      ],
    );
  }
}
