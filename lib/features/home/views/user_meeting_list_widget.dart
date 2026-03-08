import 'package:flutter/material.dart';
import 'package:secured_calling/core/models/meeting_model.dart';
import 'package:secured_calling/core/routes/app_router.dart';
import 'package:secured_calling/core/services/app_firebase_service.dart';
import 'package:secured_calling/core/services/app_local_storage.dart';
import 'package:secured_calling/features/meeting/views/meeting_tile_widget.dart';

class UserMeetingListWidget extends StatefulWidget {
  const UserMeetingListWidget({super.key});

  @override
  State<UserMeetingListWidget> createState() => _UserMeetingListWidgetState();
}

class _UserMeetingListWidgetState extends State<UserMeetingListWidget> {
  final firebaseService = AppFirebaseService.instance;

  Widget _buildNoMeetingsPlaceholder(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.history, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text('No recent meetings', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('Meetings you join will appear here', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AppLocalStorage.getUserDetails();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Recent Meetings', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 16),

        // Meetings user participated in + all meetings for their member code (so they can join easily)
        StreamBuilder<List<MeetingModel>>(
          stream: firebaseService.getRecentAndUpcomingMeetingsForUserStream(user.userId, user.memberCode),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const Center(child: Text('Error loading meetings'));
            }
            final meetings = snapshot.data ?? [];
            if (meetings.isEmpty) {
              return _buildNoMeetingsPlaceholder(context);
            }
            final displayCount = meetings.length > 10 ? 10 : meetings.length;
            final toShow = meetings.take(displayCount).toList();
            return Column(
              children: [
                ...List.generate(toShow.length, (index) => MeetingTileWidget(model: toShow[index])),
                if (meetings.length > 10)
                  TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, AppRouter.meetingViewAllRoute, arguments: meetings);
                    },
                    child: const Text('View All'),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
