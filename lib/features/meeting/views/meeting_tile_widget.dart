import 'package:flutter/material.dart';
import 'package:secured_calling/core/extensions/app_string_extension.dart';
import 'package:secured_calling/core/extensions/date_time_extension.dart';
import 'package:secured_calling/core/models/meeting_model.dart';
import 'package:secured_calling/core/routes/app_router.dart';
import 'package:secured_calling/core/services/app_local_storage.dart';
import 'package:secured_calling/core/theme/app_theme.dart';

class MeetingTileWidget extends StatefulWidget {
  MeetingTileWidget({super.key, required this.model});
  MeetingModel model;
  @override
  State<MeetingTileWidget> createState() => _MeetingTileWidgetState();
}

class _MeetingTileWidgetState extends State<MeetingTileWidget> {
  List<Color> cardColors = AppTheme.cardBackgroundColors.toList();
  Color theCardColor = AppTheme.cardBackgroundColors[0];
  @override
  void initState() {
    super.initState();
    cardColors.shuffle();
    theCardColor = cardColors[0];
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: theCardColor,
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
                    style: TextStyle(fontSize: 8, fontWeight: FontWeight.w500),
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
                    style: TextStyle(fontSize: 8, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              widget.model.meetingName,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.model.scheduledStartTime.meetStartTime,
                  style: TextStyle(color: Colors.black54, fontSize: 12),
                ),
                Text(
                  widget.model.hostName.sentenceCase,
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
                        '${widget.model.participants.length}+',
                        style: TextStyle(color: Colors.white, fontSize: 8),
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
                ElevatedButton(
                  onPressed:
                      (widget.model.participants.isNotEmpty ||
                              (DateTime.now().isAfter(
                                    widget.model.scheduledStartTime,
                                  ) ||
                                  (widget.model.scheduledStartTime.isToday &&
                                      widget.model.hostId ==
                                          AppLocalStorage.getUserDetails()
                                              .firebaseUserId)))
                          ? () {
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
                          : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4C5FE2),
                    disabledBackgroundColor: Colors.grey,
                    disabledForegroundColor: Colors.white,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: Text(
                    '${widget.model.participants.isNotEmpty
                        ? 'Join'
                        : (widget.model.hostId == AppLocalStorage.getUserDetails().firebaseUserId && widget.model.scheduledStartTime.isToday)
                        ? 'Start'
                        : 'Join'} Now',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
