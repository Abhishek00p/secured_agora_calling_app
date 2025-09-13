import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:secured_calling/core/models/meeting_model.dart';
import 'package:secured_calling/core/routes/app_router.dart';
import 'package:secured_calling/core/services/app_firebase_service.dart';
import 'package:secured_calling/core/services/app_local_storage.dart';
import 'package:secured_calling/core/theme/app_theme.dart';
import 'package:secured_calling/features/meeting/views/meeting_tile_widget.dart';

class ViewAllMeetingList extends StatefulWidget {
  ViewAllMeetingList({super.key, required this.meetings});
  final List<MeetingModel> meetings;

  @override
  State<ViewAllMeetingList> createState() => _ViewAllMeetingListState();
}

class _ViewAllMeetingListState extends State<ViewAllMeetingList> {
  StreamSubscription<DocumentSnapshot>? listener;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('View All Meetings')),
      body: widget.meetings.isNotEmpty
              ? ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: widget.meetings.length,
                itemBuilder: (context, index) {
                  final meeting = widget.meetings[index];
                  return MeetingTileWidget(model: meeting);
                },
              )
              : Center(
                child: Text(
                  'No meetings available',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
    );
  }

  void requuestMeetingApproval(
    BuildContext context,
    MeetingModel meeting,
  ) async {
    try {
      final userId = AppLocalStorage.getUserDetails().userId;
      await AppFirebaseService.instance.requestToJoinMeeting(
        meeting.meetId,
        userId,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Request sent to join ${meeting.meetingName} meeting',
            ),
            backgroundColor: AppTheme.successColor,
          ),
        );
        // Cancel any existing listener before starting new one
        listener?.cancel();
        listenForParticipantAddition(meeting, userId, context);
      }
    } catch (e) {
      SnackBar(
        content: Text('Error sending request: $e'),
        backgroundColor: AppTheme.errorColor,
      );
    }
  }

  void listenForParticipantAddition(
    MeetingModel meeting,
    int userId,
    BuildContext context,
  ) {
    listener = FirebaseFirestore.instance
        .collection('meetings')
        .doc(meeting.meetId)
        .snapshots()
        .listen((snapshot) {
          if (snapshot.exists) {
            final data = snapshot.data() as Map<String, dynamic>;
            final List<dynamic> participants = data['participants'] ?? [];

            if (participants.contains(userId)) {
              // User has been added to the participants list, stop listening
              listener?.cancel(); // Stop listening to prevent further triggers

              Navigator.pushNamed(
                context,
                AppRouter.meetingRoomRoute,
                arguments: {
                  'channelName': meeting.channelName,
                  'isHost':
                      meeting.hostId ==
                      AppLocalStorage.getUserDetails().firebaseUserId,
                  'meetingId': meeting.meetId,
                },
              );
            }
          }
        });
  }

  @override
  void dispose() {
    listener?.cancel();
    listener = null;
    super.dispose();
  }
}
