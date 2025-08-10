import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:secured_calling/core/extensions/app_color_extension.dart';
import 'package:secured_calling/core/services/app_firebase_service.dart';
import 'package:secured_calling/core/services/app_local_storage.dart';
import 'package:secured_calling/utils/app_logger.dart';
import 'package:secured_calling/core/extensions/app_int_extension.dart';
import 'package:secured_calling/features/meeting/views/join_request_widget.dart';
import 'package:secured_calling/features/meeting/bindings/live_meeting_controller.dart';
import 'package:secured_calling/features/meeting/views/show_meeting_info.dart';
import 'package:secured_calling/widgets/speaker_ripple_effect.dart';

class AgoraMeetingRoom extends StatefulWidget {
  final String meetingId;
  final String channelName;
  final bool isHost;
  const AgoraMeetingRoom({
    super.key,
    required this.meetingId,
    required this.channelName,
    required this.isHost,
  });

  @override
  State<AgoraMeetingRoom> createState() => _AgoraMeetingRoomState();
}

class _AgoraMeetingRoomState extends State<AgoraMeetingRoom> {
  Widget _buildEndCallButton({
    required BuildContext context,
    required bool isHost,
    required VoidCallback onEndCallForAll,
    required VoidCallback onLeaveMeeting,
  }) {
    return InkWell(
      onTap: () {
        showDialog(
          context: context,
          builder:
              (_) => AlertDialog(
                title: const Text('Confirmation', textAlign: TextAlign.center),
                content: Text(
                  isHost
                      ? 'Do you want to end the call for everyone or just leave the meeting?'
                      : 'Do you want to leave the meeting?',
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onLeaveMeeting();
                      Navigator.of(context).pop();
                    },
                    child: const Text('Leave Meeting'),
                  ),
                  // if (isHost)
                  //   TextButton(
                  //     onPressed: () {
                  //       Navigator.of(context).pop();
                  //       onEndCallForAll();
                  //       Navigator.of(context).pop();
                  //     },
                  //     child: const Text(
                  //       'End Call for All',
                  //       style: TextStyle(color: Colors.red),
                  //     ),
                  //   ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        height: 50,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.red,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Text(
              'End Call',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 10),
            Icon(Icons.call_end, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: color),

            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlBar(MeetingController meetingController) {
    return SizedBox(
      // height: 70,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (meetingController.isHost)
              Obx(
                () => _buildControlButton(
                  icon:
                      meetingController.isMuted.value
                          ? Icons.mic_off
                          : Icons.mic,
                  label: meetingController.isMuted.value ? 'Unmute' : 'Mute',
                  color:
                      meetingController.isMuted.value
                          ? Colors.red
                          : Colors.white,
                  onPressed: meetingController.toggleMute,
                ),
              ),
            if (!meetingController.isHost)
              Obx(
                () => _buildControlButton(
                  icon:
                      meetingController.hasRequestedToSpeak.value
                          ? Icons.cancel
                          : Icons.record_voice_over,
                  label:
                      meetingController.hasRequestedToSpeak.value
                          ? 'Cancel Request'
                          : 'Request to Speak',
                  color:
                      meetingController.hasRequestedToSpeak.value
                          ? Colors.orange
                          : Colors.white,
                  onPressed: () {
                    if (meetingController.hasRequestedToSpeak.value) {
                      meetingController.cancelRequestToSpeak();
                    } else {
                      meetingController.requestToSpeak();
                    }
                  },
                ),
              ),
            Obx(
              () => _buildControlButton(
                icon:
                    meetingController.isOnSpeaker.value
                        ? Icons.volume_up
                        : Icons.volume_off,
                label: 'Speaker',
                color:
                    !meetingController.isOnSpeaker.value
                        ? Colors.red
                        : Colors.white,
                onPressed: meetingController.toggleSpeaker,
              ),
            ),

            // _buildControlButton(
            //   icon: _isVideoEnabled ? Icons.videocam : Icons.videocam_off,
            //   label: _isVideoEnabled ? 'Stop Video' : 'Start Video',
            //   color: _isVideoEnabled ? Colors.white : Colors.red,
            //   onPressed: _toggleVideo,
            // ),
          ],
        ),
      ),
    );
  }

  final meetingController = Get.find<MeetingController>();
  final currentUser = AppLocalStorage.getUserDetails();

  void onPopInvoked() async {
    if (!meetingController.isMeetEneded) {
      await meetingController.endMeeting();
    }
    if (mounted) {
      AppLogger.print("popping context from meeting room.....");
      Navigator.pop(context);
    }
  }

  @override
  void initState() {
    AppLogger.print('meeting id before init  :${widget.meetingId}');
    meetingController.initializeMeeting(
      meetingId: widget.meetingId,
      isUserHost: widget.isHost,
      context: context,
    );
    super.initState();
  }

  void _showSpeakRequestsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text('Speak Requests'),
            content: Obx(
              () => Container(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: meetingController.speakRequestUsers.length,
                  itemBuilder: (context, index) {
                    final user = meetingController.speakRequestUsers[index];
                    return ListTile(
                      title: Text(user.name),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.check, color: Colors.green),
                            onPressed: () {
                              meetingController.approveSpeakRequest(
                                user.userId,
                              );
                              Navigator.of(context).pop();
                            },
                          ),
                          IconButton(
                            icon: Icon(Icons.close, color: Colors.red),
                            onPressed: () {
                              meetingController.rejectSpeakRequest(user.userId);
                              Navigator.of(context).pop();
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Close'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<MeetingController>(
      builder: (meetingController) {
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (!didPop) {
              onPopInvoked();
            }
          },
          child: Scaffold(
            backgroundColor: Colors.black12,
            appBar: AppBar(
              backgroundColor: Colors.black,
              iconTheme: const IconThemeData(color: Colors.white),
              actions: [
                if (meetingController.isHost)
                  IconButton(
                    onPressed: () => _showSpeakRequestsDialog(context),
                    icon: Obx(
                      () => Stack(
                        children: [
                          Icon(Icons.speaker_phone),
                          if (meetingController.speakRequests.isNotEmpty)
                            Positioned(
                              right: 0,
                              child: Container(
                                padding: EdgeInsets.all(1),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                constraints: BoxConstraints(
                                  minWidth: 12,
                                  minHeight: 12,
                                ),
                                child: Text(
                                  '${meetingController.speakRequests.length}',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                IconButton(
                  onPressed: () async {
                    // await fetchPendingRequests();
                    meetingController.fetchPendingRequests();

                    showMeetingInfo(context);
                  },
                  icon: Icon(Icons.settings),
                ),
              ],
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'Meeting Room',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),

                  if (meetingController.remainingSeconds >= 0) ...[
                    Text(
                      'Time remaining: ${meetingController.remainingSeconds.formatDuration}',
                      style: const TextStyle(fontSize: 12, color: Colors.red),
                    ),
                  ],
                ],
              ),
              //
            ),
            // bottomNavigationBar:
            body: GetBuilder<MeetingController>(
              builder: (meetingController) {
                if (!meetingController.meetingModel.isEmpty) {
                  AppFirebaseService.instance
                      .getMeetingData(widget.meetingId)
                      .then((v) {
                        AppLogger.print(
                          '\n <----------\nMeeting Model from ui : $v\n---------->\n',
                        );
                      });
                } else {
                  AppLogger.print('Meeting Model is empty');
                }
                return SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Column(
                      children: [
                        meetingController.isLoading.value
                            ? const Center(child: CircularProgressIndicator())
                            : !meetingController.agoraInitialized
                            ? Center(
                              child: Text('Agora not intialized yet...!'),
                            )
                            : Expanded(
                              child: GridView.builder(
                                itemCount:
                                    meetingController.participants.length,
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                    ),
                                itemBuilder: (context, index) {
                                  final user =
                                      meetingController.participants[index];
                                  return Container(
                                    margin: EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: user.color),
                                      // border: Border.all(color:user.isUserMuted? Colors.white:Colors.deepPurple),
                                    ),
                                    child: Stack(
                                      children: [
                                        Obx(()=>
                                        user.userId == meetingController.activeSpeakerUid.value?
                                         Positioned.fill(
                                            child: WaterRipple(
                                              color: user.color,
                                            ),
                                          ):SizedBox.shrink()),
          
                                        Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Center(
                                            child: Text(
                                              user.userId ==
                                                      meetingController
                                                          .currentUser
                                                          .userId
                                                  ? 'You'
                                                  : user.name,
                                              textAlign: TextAlign.center,
                                              maxLines: 2,
                                              style: TextStyle(
                                                fontSize: 20,
                                                color: user.color,
                                              ),
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          bottom: 8,
                                          left: 8,
                                          child: Icon(
                                            user.isUserMuted
                                                ? Icons.mic_off
                                                : Icons.mic,
                                            color: Colors.white,
                                          ),
                                        ),
                                        if (meetingController.isHost &&
                                            meetingController
                                                    .currentUser
                                                    .userId !=
                                                user.userId) ...[
                                          Positioned(
                                            right: 2,
                                            top: 0,
                                            child: PopupMenuButton<String>(
                                              onSelected: (value) {
                                                if (value == 'mute') {
                                                  meetingController
                                                      .muteThisParticipantsForAllUser(
                                                        user,
                                                      );
                                                } else if (value == 'unmute') {
                                                  meetingController
                                                      .unMuteThisParticipantsForAllUser(
                                                        user,
                                                      );
                                                } else if (value ==
                                                    'revoke_speak') {
                                                  meetingController
                                                      .revokeSpeakingPermission(
                                                        user.userId,
                                                      );
                                                }
                                              },
                                              itemBuilder:
                                                  (context) => [
                                                    if (!user.isUserMuted) ...[
                                                      PopupMenuItem(
                                                        value: 'mute',
                                                        child: Text('Mute'),
                                                      ),
                                                    ],
                                                    if (user.isUserMuted) ...[
                                                      PopupMenuItem(
                                                        value: 'unmute',
                                                        child: Text('Unmute'),
                                                      ),
                                                    ],
                                                    if (meetingController
                                                        .approvedSpeakers
                                                        .contains(user.userId))
                                                      PopupMenuItem(
                                                        value: 'revoke_speak',
                                                        child: Text(
                                                          'Revoke Speak Permission',
                                                        ),
                                                      ),
                                                    PopupMenuItem(
                                                      value: 'private_room',
                                                      child: Text(
                                                        'Create Private Room',
                                                      ),
                                                    ),
                                                  ],
                                              icon: Icon(
                                                Icons.more_vert,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                        if (meetingController.isHost) ...[JoinRequestWidget()],
                        Padding(
                          padding: const EdgeInsets.only(bottom: 30.0),
                          child: Wrap(
                            runSpacing: 16,
                            children: [
                              _buildControlBar(meetingController),
                              _buildEndCallButton(
                                context: context,
                                isHost: meetingController.isHost,
                                onEndCallForAll:
                                    meetingController.endMeetForAll,
                                onLeaveMeeting: meetingController.endMeeting,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget speakerRippleEffect({required int userId, required int activeSpeakerUid, required Color color}) {
    return Obx(
      () {
        if (userId == activeSpeakerUid) {
          return Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withAppOpacity(0.5),
            ),
            child: const CircularProgressIndicator(),
          );
        } else {
          return Container();
        }
      },
    );
  }
}
