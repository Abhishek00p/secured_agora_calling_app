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
import 'package:secured_calling/features/meeting/views/meeting_tile_widget.dart';

class UserTab extends StatefulWidget {
  UserTab({super.key});

  @override
  State<UserTab> createState() => _UserTabState();
}

class _UserTabState extends State<UserTab> {
  StreamSubscription<DocumentSnapshot>? _listener;

  final firebaseService = AppFirebaseService.instance;
  final joinRequestService = JoinRequestService();

  final ValueNotifier<List<MeetingModel>> upcomingMeetings = ValueNotifier([]);

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
    final padding = responsivePadding(context);
    final useGrid = context.layoutType != AppLayoutType.mobile;
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

          Column(
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
                    if (useGrid) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: context.layoutType == AppLayoutType.laptop ? 3 : 2,
                              childAspectRatio: 1.4,
                              crossAxisSpacing: padding,
                              mainAxisSpacing: padding,
                            ),
                            itemCount: toShow.length,
                            itemBuilder: (context, index) => MeetingTileWidget(model: toShow[index]),
                          ),
                          if (meetings.length > 10)
                            TextButton(
                              onPressed: () {
                                Navigator.pushNamed(
                                  context,
                                  AppRouter.meetingViewAllRoute,
                                  arguments: meetings,
                                );
                              },
                              child: const Text('View All'),
                            ),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        ...List.generate(toShow.length, (index) => MeetingTileWidget(model: toShow[index])),
                        if (meetings.length > 10)
                          TextButton(
                            onPressed: () {
                              Navigator.pushNamed(
                                context,
                                AppRouter.meetingViewAllRoute,
                                arguments: meetings,
                              );
                            },
                            child: const Text('View All'),
                          ),
                      ],
                    );
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

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
