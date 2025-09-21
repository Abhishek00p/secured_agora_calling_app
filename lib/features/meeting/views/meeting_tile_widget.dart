import 'package:flutter/material.dart';
import 'package:secured_calling/core/extensions/app_string_extension.dart';
import 'package:secured_calling/core/extensions/date_time_extension.dart';
import 'package:secured_calling/core/models/meeting_model.dart';
import 'package:secured_calling/core/routes/app_router.dart';
import 'package:secured_calling/core/services/app_local_storage.dart';
import 'package:secured_calling/core/services/join_request_service.dart';
import 'package:secured_calling/core/theme/app_theme.dart';
import 'package:secured_calling/utils/helper.dart';

class MeetingTileWidget extends StatefulWidget {
  const MeetingTileWidget({super.key, required this.model});
  final MeetingModel model;
  @override
  State<MeetingTileWidget> createState() => _MeetingTileWidgetState();
}

class _MeetingTileWidgetState extends State<MeetingTileWidget> {
  List<Color> cardColors = AppTheme.cardBackgroundColors.toList();
  Color theCardColor = AppTheme.cardBackgroundColors[0];
  bool isButtonEnabled = false;
  bool isCurrentUserHost = false;
  final JoinRequestService _joinRequestService = JoinRequestService();
  bool _isWaitingForApproval = false;

  String meetingDate = '';
  @override
  void initState() {
    super.initState();
    cardColors.shuffle();
    theCardColor = cardColors[0];
    isButtonEnabled =
        widget.model.scheduledStartTime.isToday &&
        (widget.model.participants.isNotEmpty ||
            (DateTime.now().isAfter(widget.model.scheduledStartTime) ||
                widget.model.hostId ==
                    AppLocalStorage.getUserDetails().firebaseUserId));
    isCurrentUserHost =
        widget.model.hostId == AppLocalStorage.getUserDetails().firebaseUserId;

    if (widget.model.scheduledStartTime.isToday) {
      meetingDate = 'Today';
    } else if (widget.model.scheduledStartTime.isTomorrow) {
      meetingDate = 'Tomorrow';
    } else if (widget.model.scheduledStartTime.isYesterday) {
      meetingDate = 'Yesterday';
    } else {
      meetingDate =
          '${widget.model.scheduledStartTime.day}/${widget.model.scheduledStartTime.month}/${widget.model.scheduledStartTime.year}';
    }
  }

  @override
  void dispose() {
    _joinRequestService.stopListening();
    super.dispose();
  }

  void requuestMeetingApproval(
    BuildContext context,
    MeetingModel meeting,
  ) async {
    if (!context.mounted) return;

    // Use centralized join request service
    await _joinRequestService.requestToJoinMeeting(
      context: context,
      meeting: meeting,
      onStateChanged: (isWaiting, errorMessage) {
        if (mounted) {
          setState(() {
            _isWaitingForApproval = isWaiting;
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.pushNamed(
          context,
          AppRouter.meetingDetailRoute,
          arguments: {'meetingId': widget.model.meetId},
        );
      },
      child: Card(
        elevation: 2,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color:
            widget.model.scheduledStartTime.isToday
                ? theCardColor
                : Colors.grey.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Example ListView or Column
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD8F1F0),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      widget.model.scheduledStartTime.formatDate,
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD8F1F0),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      widget.model.scheduledStartTime.formatTime,
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                widget.model.meetingName.sentenceCase,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.schedule, color: Colors.black54, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        AppHelper.timeDifference(
                          widget.model.scheduledStartTime,
                          widget.model.scheduledEndTime,
                        ),
                        style: TextStyle(color: Colors.black54, fontSize: 12),
                      ),
                    ],
                  ),
                  Text(
                    widget.model.hostName.titleCase,
                    style: TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.black,
                        child: Text(
                          '${widget.model.allParticipants.length}+',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Joined',
                        style: TextStyle(color: Colors.black54, fontSize: 12),
                      ),
                    ],
                  ),

                  const Spacer(),
                  if (!widget.model.scheduledEndTime.isAfter(
                    DateTime.now(),
                  )) ...[
                    Icon(Icons.lock_clock, color: Colors.red, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Ended',
                      style: TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ],
                  if (widget.model.scheduledEndTime.isAfter(DateTime.now()))
                    ElevatedButton(
                      onPressed:
                          _isWaitingForApproval
                              ? null // Disable button while waiting
                              : isButtonEnabled
                              ? () {
                                if (widget.model.requiresApproval &&
                                    !isCurrentUserHost) {
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
                                            widget.model,
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
                                      'channelName': widget.model.channelName,
                                      'isHost':
                                          widget.model.hostId ==
                                          AppLocalStorage.getUserDetails()
                                              .firebaseUserId,
                                      'meetingId': widget.model.meetId,
                                    },
                                  );
                                }
                              }
                              : () {
                                if (widget
                                        .model
                                        .scheduledStartTime
                                        .differenceInMinutes <
                                    0) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      behavior: SnackBarBehavior.floating,
                                      content: Text(
                                        'Meeting will start soon...',
                                      ),
                                    ),
                                  );
                                  return;
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      behavior: SnackBarBehavior.floating,
                                      content: Text(
                                        'Meeting has ended. on or before ${widget.model.scheduledEndTime.formatDate}',
                                      ),
                                    ),
                                  );
                                }
                                setState(() {});
                              },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _isWaitingForApproval
                                ? Colors.orange
                                : isButtonEnabled
                                ? const Color(0xFF4C5FE2)
                                : Colors.grey,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child:
                          _isWaitingForApproval
                              ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Waiting for Approval',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              )
                              : Text(
                                '${widget.model.participants.isNotEmpty
                                    ? 'Join'
                                    : (isCurrentUserHost && widget.model.scheduledStartTime.isToday)
                                    ? 'Start'
                                    : 'Join'} Now',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
