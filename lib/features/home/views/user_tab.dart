import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:secured_calling/core/models/meeting_model.dart';
import 'package:secured_calling/core/routes/app_router.dart';
import 'package:secured_calling/core/services/app_firebase_service.dart';
import 'package:secured_calling/core/services/app_local_storage.dart';
import 'package:secured_calling/core/services/join_request_service.dart';
import 'package:secured_calling/core/utils/responsive_utils.dart';
import 'package:secured_calling/features/home/views/meeting_action_card.dart';
import 'package:secured_calling/features/meeting/views/join_meeting_dialog.dart';

class UserTab extends StatefulWidget {
  const UserTab({super.key});
  @override
  State<UserTab> createState() => _UserTabState();
}

class _UserTabState extends State<UserTab> {
  StreamSubscription<DocumentSnapshot>? _listener;

  final firebaseService = AppFirebaseService.instance;
  final joinRequestService = JoinRequestService();

  final ValueNotifier<List<MeetingModel>> upcomingMeetings = ValueNotifier([]);

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final padding = responsivePadding(context);
    return Padding(
      padding: EdgeInsets.all(padding),
      child: Column(
        children: [
          // Join existing meeting card
          ActionCard(
            title: 'Join a Meeting',
            icon: Icons.group_add,
            description: 'Enter a meeting ID to join an existing call',
            buttonText: 'Join',
            onPressed: () {
              showDialog(context: context, barrierDismissible: false, builder: (context) => JoinMeetingDialog());
            },
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void requuestMeetingApproval(BuildContext context, MeetingModel meeting) async {
    if (!context.mounted) return;

    // Use centralized join request service
    await joinRequestService.requestToJoinMeeting(
      context: context,
      meeting: meeting,
      onStateChanged: (isWaiting, errorMessage) {
        // This implementation uses the old listener approach
        // but we can still use the centralized service for consistency
      },
    );
  }

  void listenForParticipantAddition(MeetingModel meeting, int userId, BuildContext context) {
    _listener = FirebaseFirestore.instance.collection('meetings').doc(meeting.meetId).snapshots().listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        final List<dynamic> participants = data['participants'] ?? [];

        if (participants.contains(userId)) {
          // User has been added to the participants list, stop listening
          _listener?.cancel(); // Stop listening to prevent further triggers

          Navigator.pushNamed(
            context,
            AppRouter.meetingRoomRoute,
            arguments: {
              'channelName': meeting.channelName,
              'isHost': meeting.hostId == AppLocalStorage.getUserDetails().userId,
              'meetingId': meeting.meetId,
            },
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _listener?.cancel();
    _listener = null;
    joinRequestService.stopListening();
    super.dispose();
  }
}
