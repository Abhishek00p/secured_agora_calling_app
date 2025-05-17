import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:secured_calling/core/extensions/date_time_extension.dart';
import 'package:secured_calling/core/models/meeting_model.dart';
import 'package:secured_calling/core/routes/app_router.dart';
import 'package:secured_calling/core/services/app_firebase_service.dart';
import 'package:secured_calling/core/services/app_local_storage.dart';
import 'package:secured_calling/core/theme/app_theme.dart';
import 'package:secured_calling/utils/app_logger.dart';

class ViewAllMeetingList extends StatelessWidget {
  ViewAllMeetingList({super.key, required this.meetings, this.listener});
  final List<MeetingModel> meetings;

  StreamSubscription<DocumentSnapshot>? listener;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('View All Meetings')),
      body: meetings.isNotEmpty
              ? ListView.builder(
                itemCount: meetings.length,
                itemBuilder: (context, index) {
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
                                meeting.scheduledStartTime.differenceInMinutes <
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

                      if (meeting.scheduledStartTime.differenceInMinutes < 0) {
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
                                  requuestMeetingApproval(context, meeting);
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
}
