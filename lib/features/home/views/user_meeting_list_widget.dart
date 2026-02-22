import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:secured_calling/core/models/meeting_model.dart';
import 'package:secured_calling/core/routes/app_router.dart';
import 'package:secured_calling/core/services/app_firebase_service.dart';
import 'package:secured_calling/core/services/app_local_storage.dart';
import 'package:secured_calling/core/services/join_request_service.dart';
import 'package:secured_calling/features/meeting/views/meeting_tile_widget.dart';

class UserMeetingListWidget extends StatefulWidget {
  const UserMeetingListWidget({super.key});

  @override
  State<UserMeetingListWidget> createState() => _UserMeetingListWidgetState();
}

class _UserMeetingListWidgetState extends State<UserMeetingListWidget> {
  final firebaseService = AppFirebaseService.instance;
  final joinRequestService = JoinRequestService();

  final ValueNotifier<List<MeetingModel>> upcomingMeetings = ValueNotifier([]);

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

  List<MeetingModel> getSortedMeetingList(List<QueryDocumentSnapshot<Object?>> meetings) {
    final modelList =
        meetings.map((meeting) {
          return MeetingModel.fromJson(meeting.data() as Map<String, dynamic>? ?? {});
        }).toList();

    return modelList;
  }

  void loadUpcomingMeetings() {
    final currentUser = AppLocalStorage.getUserDetails();
    if (currentUser.memberCode.isNotEmpty) {
      // Members see all upcoming meetings for their member code
      firebaseService.getUpcomingMeetingsStream(currentUser.memberCode).listen((snapshot) {
        final meetings =
            snapshot.docs.map((doc) {
              return MeetingModel.fromJson(doc.data() as Map<String, dynamic>);
            }).toList();
        upcomingMeetings.value = meetings;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    loadUpcomingMeetings();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Recent Meetings', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            IconButton(
              onPressed: () {
                loadUpcomingMeetings();
              },
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Placeholder for call history
        StreamBuilder<QuerySnapshot>(
          stream: AppFirebaseService.instance.getUpcomingMeetingsStream(AppLocalStorage.getUserDetails().memberCode),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return const Center(child: Text('Error loading meetings'));
            } else if (snapshot.hasData && snapshot.data!.docs.isEmpty) {
              return _buildNoMeetingsPlaceholder(context);
            } else {
              final meetings = getSortedMeetingList(snapshot.data!.docs);
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
            }
          },
        ),
      ],
    );
  }
}
