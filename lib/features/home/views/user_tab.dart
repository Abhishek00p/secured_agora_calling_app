import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:secured_calling/core/extensions/date_time_extension.dart';
import 'package:secured_calling/core/models/meeting_model.dart';
import 'package:secured_calling/core/routes/app_router.dart';
import 'package:secured_calling/core/services/app_firebase_service.dart';
import 'package:secured_calling/core/services/app_local_storage.dart';
import 'package:secured_calling/core/theme/app_theme.dart';
import 'package:secured_calling/features/home/views/meeting_action_card.dart';
import 'package:secured_calling/features/meeting/views/join_meeting_dialog.dart';
import 'package:secured_calling/utils/app_logger.dart';

class UserTab extends StatelessWidget {
  UserTab({super.key});
  StreamSubscription<DocumentSnapshot>? _listener;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Join existing meeting card
          ActionCard(
            title: 'Join a Meeting',
            icon: Icons.group_add,
            description: 'Enter a meeting ID to join an existing call',
            buttonText: 'Join',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const JoinMeetingDialog(),
              );
            },
          ),

          const SizedBox(height: 24),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Recent Meetings',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // Placeholder for call history
              FutureBuilder(
                future: AppFirebaseService.instance
                    .getAllMeetingsFromCodeStream(
                      AppLocalStorage.getUserDetails().memberCode,
                    ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return const Center(child: Text('Error loading meetings'));
                  } else if (snapshot.hasData && snapshot.data!.docs.isEmpty) {
                    return _buildNoMeetingsPlaceholder(context);
                  } else {
                    // Display the list of meetings

                    final meetings = getSortedMeetingList(snapshot.data!.docs);
                    return Column(
                      children: [
                        ...List.generate(meetings.length > 10 ? 10 : meetings.length, (
                          index,
                        ) {
                          final meeting = meetings[index];
                          return ListTile(
                            title: Text(
                              meeting.meetingName,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'start on: ${meeting.scheduledStartTime.formatDate}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                Text(
                                  'when : ${meeting.scheduledStartTime.formatTime}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                            isThreeLine: true,
                            leading: const Icon(Icons.video_call),
                            trailing:
                                meeting.hostId ==
                                            AppLocalStorage.getUserDetails()
                                                .firebaseUserId &&
                                        meeting
                                                .scheduledStartTime
                                                .differenceInMinutes <
                                            0
                                    ? OutlinedButton(
                                      onPressed: () {
                                             Navigator.pushNamed(
                                    context,
                                    AppRouter.meetingRoomRoute,
                                    arguments: {
                                      'channelName': meeting.channelName,
                                      'isHost':
                                          meeting.hostId ==
                                          AppLocalStorage.getUserDetails()
                                              .firebaseUserId,
                                      'meetingId': meeting.meetId,
                                    },
                                  );
                                      },
                                      child: Text("Start"),
                                    )
                                    : const Icon(Icons.arrow_forward),
                            onTap: () {
                              // Handle meeting tap
                              AppLogger.print(
                                'meeting.scheduledStartTime.differenceInMinutes : ${meeting.scheduledStartTime.differenceInMinutes}',
                              );

                              if (meeting
                                      .scheduledStartTime
                                      .differenceInMinutes <
                                  0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    behavior: SnackBarBehavior.floating,
                                    content: Text('Meeting will start soon...'),
                                  ),
                                );
                                return;
                              } else if (meeting
                                      .scheduledStartTime
                                      .differenceInMinutes >
                                  0) {
                                if (meeting.requiresApproval &&
                                    meeting.hostId !=
                                        AppLocalStorage.getUserDetails()
                                            .firebaseUserId) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Meeting Requires approval from the host.',
                                      ),
                                      behavior: SnackBarBehavior.floating,

                                      action: SnackBarAction(
                                        label: 'Send Request',
                                        onPressed: () {
                                          requuestMeetingApproval(
                                            context,
                                            meeting,
                                          );
                                        },
                                      ),
                                    ),
                                  );
                                } else {
                                  Navigator.pushNamed(
                                    context,
                                    AppRouter.meetingRoomRoute,
                                    arguments: {
                                      'channelName': meeting.channelName,
                                      'isHost':
                                          meeting.hostId ==
                                          AppLocalStorage.getUserDetails()
                                              .firebaseUserId,
                                      'meetingId': meeting.meetId,
                                    },
                                  );
                                }
                                return;
                              }
                            },
                          
                          );
                        }),

                        TextButton(
                          onPressed: () {
                            // Navigate to the Meeting view all page and pass the full list of meetings
                            Navigator.pushNamed(
                              context,
                              AppRouter
                                  .meetingViewAllRoute, // Ensure this route is defined
                              arguments:
                                  meetings, // Pass the full list of meetings
                            );
                          },
                          child: Text('View All'),
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
          Text(
            'No recent meetings',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Meetings you join will appear here',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  List<MeetingModel> getSortedMeetingList(
    List<QueryDocumentSnapshot<Object?>> meetings,
  ) {
    final modelList =
        meetings.map((meeting) {
          return MeetingModel.fromJson(
            meeting.data() as Map<String, dynamic>? ?? {},
          );
        }).toList();

    modelList.sort((a, b) {
      return a.scheduledStartTime.compareTo(b.scheduledStartTime);
    });
    return modelList;
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
    _listener = FirebaseFirestore.instance
        .collection('meetings')
        .doc(meeting.meetId)
        .snapshots()
        .listen((snapshot) {
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
}
