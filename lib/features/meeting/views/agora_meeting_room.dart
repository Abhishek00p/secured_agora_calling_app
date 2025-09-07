import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:secured_calling/core/extensions/app_color_extension.dart';
import 'package:secured_calling/core/models/participant_model.dart';
import 'package:secured_calling/core/services/app_firebase_service.dart';
import 'package:secured_calling/core/services/app_local_storage.dart';
import 'package:secured_calling/utils/app_logger.dart';
import 'package:secured_calling/core/extensions/app_int_extension.dart';
import 'package:secured_calling/features/meeting/views/join_request_widget.dart';
import 'package:secured_calling/features/meeting/bindings/live_meeting_controller.dart';
import 'package:secured_calling/features/meeting/views/show_meeting_info.dart';
import 'package:secured_calling/widgets/speaker_ripple_effect.dart';
import 'package:secured_calling/utils/app_tost_util.dart';

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

class _AgoraMeetingRoomState extends State<AgoraMeetingRoom> with WidgetsBindingObserver {
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

  final meetingController = Get.find<MeetingController>();
  final currentUser = AppLocalStorage.getUserDetails();
  static const platform = MethodChannel('com.example.secured_calling/pip');

  Future<void> enterPipMode() async {
    try {
      await platform.invokeMethod('enterPipMode');
    } on PlatformException catch (e) {
      debugPrint("Failed to enter PIP mode: '${e.message}'.");
    }
  }


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppLogger.print('meeting id before init  :${widget.meetingId}');
    meetingController.initializeMeeting(
      meetingId: widget.meetingId,
      isUserHost: widget.isHost,
      context: context,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused && meetingController.isJoined.value) {
      enterPipMode();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<MeetingController>(
      builder: (meetingController) {
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (!didPop) {
              if (meetingController.isJoined.value) {
                enterPipMode();
              } else {
                Navigator.pop(context);
              }
            }
          },
          child: Scaffold(
            backgroundColor: Colors.black12,
            appBar: AppBar(
              backgroundColor: Colors.black,
              iconTheme: const IconThemeData(color: Colors.white),
              actions: [
                IconButton(
                  onPressed: () async {
                    // await fetchPendingRequests();
                    meetingController.fetchPendingRequests();

                    showMeetingInfo(context);
                  },
                  icon: Icon(Icons.settings),
                ),
              ],
              title: Obx(
                () => Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      meetingController.meetingModel.value.meetingName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (meetingController.remainingSeconds >= 0) ...[
                      Text(
                        'Time remaining: ${meetingController.remainingSeconds.formatDuration}',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.red),
                      ),
                    ],
                  ],
                ),
              ),
              //
            ),
            // bottomNavigationBar:
            body: GetBuilder<MeetingController>(
              builder: (meetingController) {
                if (!meetingController.meetingModel.value.isEmpty) {
                  AppFirebaseService.instance
                      .getMeetingData(widget.meetingId);
                } else {
                  AppLogger.print('Meeting Model is empty');
                }
                return SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Column(
                      children: [
                        meetingController.isLoading.value
                            ? const Center(
                                child: CircularProgressIndicator())
                            : !meetingController.agoraInitialized
                                ? Center(
                                    child: Text(
                                        'Agora not intialized yet...!'),
                                  )
                                : Expanded(
                                    child: meetingController.isHost
                                        ? _buildHostView(meetingController)
                                        : _buildParticipantView(
                                            meetingController,
                                          ),
                                  ),
                        if (meetingController.isHost) ...[
                          JoinRequestWidget()
                        ],
                        Padding(
                          padding: const EdgeInsets.only(bottom: 30.0),
                          child: Wrap(
                            runSpacing: 24,
                            alignment: WrapAlignment.spaceEvenly,
                            children: [
                              if (meetingController.isHost) ...[
                                GestureDetector(
                                  onTap: () {
                                    if (meetingController.isMuted.value) {
                                      meetingController.startPtt();
                                    } else {
                                      meetingController.stopPtt();
                                    }
                                  },
                                  child: Obx(() {
                                    final isPttActive = meetingController
                                        .pttUsers
                                        .contains(
                                          meetingController
                                              .currentUser.userId,
                                        );
                                    return CircleAvatar(
                                      radius: 60,
                                      backgroundColor: isPttActive
                                          ? Colors.green
                                          : Colors.white.withAppOpacity(
                                              0.2,
                                            ),
                                      child: Icon(
                                        isPttActive
                                            ? Icons.mic
                                            : Icons.mic_off,
                                        color: Colors.white,
                                        size: 50,
                                      ),
                                    );
                                    // );
                                  }),
                                ),
                              ],
                              if (!meetingController.isHost) ...[
                                GestureDetector(
                                  onLongPressStart: (_) {
                                    meetingController.startPtt();
                                  },
                                  onLongPressEnd: (_) {
                                    meetingController.stopPtt();
                                  },
                                  child: Obx(() {
                                    final isPttActive = meetingController
                                        .pttUsers
                                        .contains(
                                          meetingController
                                              .currentUser.userId,
                                        );
                                    return CircleAvatar(
                                      radius: 60,
                                      backgroundColor: isPttActive
                                          ? Colors.green
                                          : Colors.white
                                              .withAppOpacity(0.2),
                                      child: Icon(
                                        isPttActive
                                            ? Icons.mic
                                            : Icons.mic_off,
                                        color: Colors.white,
                                        size: 50,
                                      ),
                                    );
                                    // );
                                  }),
                                ),
                              ],
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  Obx(
                                    () => OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(
                                          color: meetingController
                                                  .isOnSpeaker.value
                                              ? Colors.green
                                              : Colors.white,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        padding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                      ),
                                      onPressed: meetingController
                                          .toggleSpeaker,
                                      child: Column(
                                        children: [
                                          Icon(
                                            meetingController
                                                    .isOnSpeaker.value
                                                ? Icons.volume_up
                                                : Icons.volume_off,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            meetingController
                                                    .isOnSpeaker.value
                                                ? 'Speaker On'
                                                : 'Speaker Off',
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  _buildEndCallButton(
                                    context: context,
                                    isHost: meetingController.isHost,
                                    onEndCallForAll:
                                        meetingController.endMeetForAll,
                                    onLeaveMeeting:
                                        meetingController.endMeeting,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        40.h,
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

  Widget _buildParticipantTile(
    ParticipantModel user,
    MeetingController meetingController,
  ) {
    return Container(
      margin: EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: user.color),
      ),
      child: Stack(
        children: [
          Obx(
            () =>
         meetingController.pttUsers.contains(user.userId)
                    ? Positioned.fill(child: WaterRipple(color: user.color))
                    : SizedBox.shrink(),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(
              child: Text(
                user.userId == meetingController.currentUser.userId
                    ? 'You'
                    : user.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: TextStyle(fontSize: 20, color: user.color),
              ),
            ),
          ),
          Positioned(
            bottom: 8,
            left: 8,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  // user.isUserMuted
                  !(meetingController.pttUsers.contains(user.userId))
                      ? Icons.mic_off
                      : Icons.mic,
                  color:
                      !(meetingController.pttUsers.contains(user.userId))
                          ? Colors.red
                          : Colors.white,
                  size: 20,
                ),
                // if (user.isUserSpeaking && !user.isUserMuted)
                if (meetingController.pttUsers.contains(user.userId)) ...[
                  const SizedBox(width: 4),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Obx(() {
            if (meetingController.pttUsers.contains(user.userId)) {
              return Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.8),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.mic, color: Colors.white, size: 14),
                ),
              );
            }
            return SizedBox.shrink();
          }),
        ],
      ),
    );
  }

  Widget _buildHostView(MeetingController meetingController) {
    return GridView.builder(
      itemCount: meetingController.participants.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.0,
      ),
      itemBuilder: (context, index) {
        final user = meetingController.participants[index];
        return _buildParticipantTile(user, meetingController);
      },
    );
  }

  Widget _buildParticipantView(MeetingController meetingController) {
    final host = meetingController.participants.firstWhereOrNull(
      (p) => p.userId == meetingController.meetingModel.value.hostUserId,
    );
    final self = meetingController.participants.firstWhereOrNull(
      (p) => p.userId == meetingController.currentUser.userId,
    );

    final List<ParticipantModel> viewParticipants = [];
    if (host != null) viewParticipants.add(host);
    if (self != null && self.userId != host?.userId) viewParticipants.add(self);

    return ListView.builder(
      itemCount: viewParticipants.length,
      itemBuilder: (context, index) {
        final user = viewParticipants[index];
        return SizedBox(
          height: 200, // Give a fixed height to the list items
          child: _buildParticipantTile(user, meetingController),
        );
      },
    );
  }

  Widget speakerRippleEffect({
    required int userId,
    required int activeSpeakerUid,
    required Color color,
  }) {
    return Obx(() {
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
    });
  }
}
