import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:secured_calling/core/extensions/app_color_extension.dart';
import 'package:secured_calling/core/models/participant_model.dart';
import 'package:secured_calling/core/services/app_firebase_service.dart';
import 'package:secured_calling/core/services/app_local_storage.dart';
import 'package:secured_calling/utils/app_logger.dart';
import 'package:secured_calling/utils/app_tost_util.dart';
import 'package:secured_calling/core/extensions/app_int_extension.dart';
import 'package:secured_calling/features/meeting/views/join_request_widget.dart';
import 'package:secured_calling/features/meeting/bindings/live_meeting_controller.dart';
import 'package:secured_calling/features/meeting/views/show_meeting_info.dart';
import 'package:secured_calling/widgets/blinking_text.dart';
import 'package:secured_calling/widgets/speaker_ripple_effect.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class AgoraMeetingRoom extends StatefulWidget {
  final String meetingId;
  final String channelName;
  final bool isHost;
  const AgoraMeetingRoom({super.key, required this.meetingId, required this.channelName, required this.isHost});

  @override
  State<AgoraMeetingRoom> createState() => _AgoraMeetingRoomState();
}

class _AgoraMeetingRoomState extends State<AgoraMeetingRoom> with WidgetsBindingObserver {
  Widget _buildEndCallButton({
    required BuildContext context,
    required bool isHost,
    required VoidCallback onEndCallForAll,
    required Future<void> Function() onLeaveMeeting,
  }) {
    return InkWell(
      onTap: () {
        showDialog(
          context: context,
          builder:
              (dialogContext) => AlertDialog(
                title: const Text('Confirmation', textAlign: TextAlign.center),
                content: Text(isHost ? 'Do you want to end the call for everyone or just leave the meeting?' : 'Do you want to leave the meeting?'),
                actions: [
                  TextButton(
                    onPressed: () async {
                      // Close dialog first
                      Navigator.of(dialogContext).pop();

                      // Show loading indicator
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (loadingContext) {
                          // Store the loading context for later use
                          final loadingDialogContext = loadingContext;

                          // Call the async endMeeting function
                          onLeaveMeeting()
                              .then((_) {
                                // Close loading dialog
                                if (loadingDialogContext.mounted) {
                                  Navigator.of(loadingDialogContext).pop();
                                }

                                // Navigation is handled by endMeeting() function
                                // No need to manually pop here
                              })
                              .catchError((e) {
                                // Close loading dialog
                                if (loadingDialogContext.mounted) {
                                  Navigator.of(loadingDialogContext).pop();
                                }

                                // Show error message
                                if (context.mounted) {
                                  ScaffoldMessenger.of(
                                    context,
                                  ).showSnackBar(SnackBar(content: Text('Error leaving meeting: $e'), backgroundColor: Colors.red));
                                }
                              });

                          return const AlertDialog(
                            content: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [CircularProgressIndicator(), SizedBox(width: 16), Text('Leaving meeting...')],
                            ),
                          );
                        },
                      );
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
                  TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
                ],
              ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        height: 50,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: Colors.red),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Text('End Call', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            SizedBox(width: 10),
            Icon(Icons.call_end, color: Colors.white),
          ],
        ),
      ),
    );
  }

  final meetingController = Get.find<MeetingController>();
  final currentUser = AppLocalStorage.getUserDetails();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable();
    AppLogger.print('meeting id before init  :${widget.meetingId}');
    // Re-entry: already in this meeting, no need to initialize again
    final alreadyInThisMeeting = meetingController.isJoined.value &&
        meetingController.meetingId == widget.meetingId;
    if (!alreadyInThisMeeting) {
      meetingController.initializeMeeting(
        meetingId: widget.meetingId,
        channelName: widget.channelName,
        isUserHost: widget.isHost,
        context: context,
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // AppLifecycleManager will handle app termination cleanup automatically
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<MeetingController>(
      builder: (meetingController) {
        return PopScope(
          canPop: true,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop && meetingController.isJoined.value && context.mounted) {
              AppToastUtil.showInfoToast('Call continues in background. Tap the bar to return.');
            }
          },
          child: Scaffold(
            backgroundColor: Colors.black12,
            appBar: AppBar(
              backgroundColor: Colors.black,
              iconTheme: const IconThemeData(color: Colors.white),
              actions: [
                if (meetingController.isHost)
                  Row(
                    children: [
                      IconButton(
                        onPressed: () async {
                          // await fetchPendingRequests();
                          meetingController.toggleMixRecordingButton();
                        },
                        icon: Obx(
                          () => Icon(
                            meetingController.isRecordingOn.value ? Icons.stop_circle_rounded : Icons.fiber_manual_record_rounded,
                            size: 24,
                            color: Colors.red,
                          ),
                        ),
                      ),
                      Obx(() {
                        if (meetingController.isRecordingOn.value && meetingController.isHost) {
                          return Row(
                            children: [
                              BlinkingText(text: 'Rec', style: TextStyle(fontSize: 14, color: Colors.redAccent, fontWeight: FontWeight.w500)),
                            ],
                          );
                        } else {
                          return SizedBox.shrink();
                        }
                      }),
                    ],
                  ),
                Obx(() {
                  return meetingController.isRecordingOn.value && !meetingController.isHost
                      ? Row(
                        children: [
                          Icon(Icons.fiber_manual_record_rounded, size: 24, color: Colors.red),
                          SizedBox(width: 4),
                          BlinkingText(text: 'Rec', style: TextStyle(fontSize: 14, color: Colors.redAccent, fontWeight: FontWeight.w500)),
                        ],
                      )
                      : SizedBox.shrink();
                }),

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
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (meetingController.remainingSeconds >= 0) ...[
                      Text(
                        'Time remaining: ${meetingController.remainingSeconds.formatDuration}',
                        style: const TextStyle(fontSize: 12, color: Colors.red),
                      ),
                      // Show extension indicator if meeting was extended
                      // if (meetingController.meetingModel.value.totalExtensions != null &&
                      //     meetingController.meetingModel.value.totalExtensions! > 0) ...[
                      //   const SizedBox(height: 4),
                      //   Container(
                      //     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      //     decoration: BoxDecoration(
                      //       color: Colors.green.withAppOpacity(0.2),
                      //       borderRadius: BorderRadius.circular(12),
                      //       border: Border.all(color: Colors.green, width: 1),
                      //     ),
                      //     child: Text(
                      //       'Extended ${meetingController.meetingModel.value.totalExtensions} time(s)',
                      //       style: const TextStyle(
                      //         fontSize: 10,
                      //         color: Colors.green,
                      //         fontWeight: FontWeight.w500,
                      //       ),
                      //     ),
                      //   ),
                      // ],
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
                  AppFirebaseService.instance.getMeetingData(widget.meetingId);
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
                            ? Center(child: Text('Agora not intialized yet...!'))
                            : Expanded(
                              child: meetingController.isHost ? _buildHostView(meetingController) : _buildParticipantView(meetingController),
                            ),
                        if (meetingController.isHost) ...[
                          JoinRequestWidget(),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 30.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              // runSpacing: 24,
                              // alignment: WrapAlignment.spaceEvenly,
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    if (meetingController.isMuted.value) {
                                      meetingController.startPtt();
                                    } else {
                                      meetingController.stopPtt();
                                    }
                                  },
                                  child: Obx(() {
                                    final isPttActive = meetingController.pttUsers.contains(meetingController.currentUser.userId);
                                    return CircleAvatar(
                                      radius: 60,
                                      backgroundColor: isPttActive ? Colors.green : Colors.white.withAppOpacity(0.2),
                                      child: Icon(isPttActive ? Icons.mic : Icons.mic_off, color: Colors.white, size: 50),
                                    );
                                    // );
                                  }),
                                ),

                                Column(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    Obx(
                                      () => SizedBox(
                                        height: 50,

                                        child: OutlinedButton(
                                          style: OutlinedButton.styleFrom(
                                            side: BorderSide(color: meetingController.isOnSpeaker.value ? Colors.green : Colors.white),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                          ),
                                          onPressed: meetingController.toggleSpeaker,
                                          child: Row(
                                            children: [
                                              Icon(meetingController.isOnSpeaker.value ? Icons.volume_up : Icons.volume_off),
                                              const SizedBox(width: 8),
                                              Text(
                                                meetingController.isOnSpeaker.value ? 'Speaker On' : 'Speaker Off',
                                                style: const TextStyle(fontSize: 12),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    16.h,
                                    _buildEndCallButton(
                                      context: context,
                                      isHost: meetingController.isHost,
                                      onEndCallForAll: meetingController.endMeetForAll,
                                      onLeaveMeeting: meetingController.endMeeting,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (!meetingController.isHost) ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 30.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              // runSpacing: 24,
                              // alignment: WrapAlignment.spaceEvenly,
                              children: [
                                GestureDetector(
                                  onLongPressStart: (_) {
                                    meetingController.startPtt();
                                  },
                                  onLongPressEnd: (_) {
                                    meetingController.stopPtt();
                                  },
                                  child: Obx(() {
                                    final isPttActive = meetingController.pttUsers.contains(meetingController.currentUser.userId);
                                    return CircleAvatar(
                                      radius: 75,
                                      backgroundColor: isPttActive ? Colors.green : Colors.white.withAppOpacity(0.2),
                                      child: Icon(isPttActive ? Icons.mic : Icons.mic_off, color: Colors.white, size: 65),
                                    );
                                    // );
                                  }),
                                ),
                                16.h,
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    Obx(
                                      () => SizedBox(
                                        height: 50,
                                        child: OutlinedButton(
                                          style: OutlinedButton.styleFrom(
                                            side: BorderSide(color: meetingController.isOnSpeaker.value ? Colors.green : Colors.white),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                          ),
                                          onPressed: meetingController.toggleSpeaker,
                                          child: Row(
                                            children: [
                                              Icon(meetingController.isOnSpeaker.value ? Icons.volume_up : Icons.volume_off),
                                              const SizedBox(width: 4),
                                              Text(
                                                meetingController.isOnSpeaker.value ? 'Speaker On' : 'Speaker Off',
                                                style: const TextStyle(fontSize: 12),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    16.h,
                                    _buildEndCallButton(
                                      context: context,
                                      isHost: meetingController.isHost,
                                      onEndCallForAll: meetingController.endMeetForAll,
                                      onLeaveMeeting: meetingController.endMeeting,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
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

  Widget _buildParticipantTile(ParticipantModel user, MeetingController meetingController) {
    return Container(
      margin: EdgeInsets.all(8),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: user.color)),
      child: Stack(
        children: [
          Obx(() => meetingController.pttUsers.contains(user.userId) ? Positioned.fill(child: WaterRipple(color: user.color)) : SizedBox.shrink()),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(
              child: Text(
                user.userId == meetingController.currentUser.userId ? 'You' : user.name,
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
                  user.isUserMuted || !(meetingController.pttUsers.contains(user.userId)) ? Icons.mic_off : Icons.mic,
                  color: user.isUserMuted || !(meetingController.pttUsers.contains(user.userId)) ? Colors.red : Colors.white,
                  size: 20,
                ),
                // if (user.isUserSpeaking && !user.isUserMuted)
                if (meetingController.pttUsers.contains(user.userId)) ...[
                  const SizedBox(width: 4),
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
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
                  decoration: BoxDecoration(color: Colors.green.withOpacity(0.8), shape: BoxShape.circle),
                  child: Icon(Icons.mic, color: Colors.white, size: 14),
                ),
              );
            }
            return SizedBox.shrink();
          }),
          // Host-only remove button
          if (meetingController.isHost && user.userId != meetingController.currentUser.userId)
            Positioned(
              top: 8,
              left: 8,
              child: PopupMenuButton<String>(
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (value) {
                  if (value == 'remove') {
                    _showRemoveParticipantDialog(context, user, meetingController);
                  }
                  // else if (value == 'mute') {
                  //   if (user.isUserMuted) {
                  //     meetingController.unMuteThisParticipantsForAllUser(user);
                  //   } else {
                  //     meetingController.muteThisParticipantsForAllUser(user);
                  //   }
                  // }
                },
                itemBuilder:
                    (context) => [
                      PopupMenuItem(
                        value: 'remove',
                        child: Row(children: const [Icon(Icons.close, color: Colors.red, size: 18), SizedBox(width: 8), Text("Remove")]),
                      ),
                      // PopupMenuItem(
                      //   value: 'mute',
                      //   child: Row(
                      //     children: [
                      //       Icon(
                      //         user.isUserMuted ? Icons.volume_up : Icons.volume_off,
                      //         color: Colors.blue,
                      //         size: 18,
                      //       ),
                      //       SizedBox(width: 8),
                      //       Text(user.isUserMuted ? "Unmute" : "Mute"),
                      //     ],
                      //   ),
                      // ),
                    ],
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), shape: BoxShape.circle),
                  child: const Icon(Icons.more_vert, color: Colors.white, size: 16),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHostView(MeetingController meetingController) {
    return GridView.builder(
      itemCount: meetingController.participants.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 1.0),
      itemBuilder: (context, index) {
        final user = meetingController.participants[index];
        return _buildParticipantTile(user, meetingController);
      },
    );
  }

  Widget _buildParticipantView(MeetingController meetingController) {
    final host = meetingController.participants.firstWhereOrNull((p) => p.userId == meetingController.meetingModel.value.hostUserId);
    final self = meetingController.participants.firstWhereOrNull((p) => p.userId == meetingController.currentUser.userId);

    final List<ParticipantModel> viewParticipants = [];
    if (host != null) viewParticipants.add(host);
    if (self != null && self.userId != host?.userId) viewParticipants.add(self);

    return ListView.builder(
      itemCount: viewParticipants.length,
      itemBuilder: (context, index) {
        final user = viewParticipants[index];
        return SizedBox(
          height: 180, // Give a fixed height to the list items
          child: _buildParticipantTile(user, meetingController),
        );
      },
    );
  }

  Widget speakerRippleEffect({required int userId, required int activeSpeakerUid, required Color color}) {
    return Obx(() {
      if (userId == activeSpeakerUid) {
        return Container(
          decoration: BoxDecoration(shape: BoxShape.circle, color: color.withAppOpacity(0.5)),
          child: const CircularProgressIndicator(),
        );
      } else {
        return Container();
      }
    });
  }

  /// Show confirmation dialog for removing participant
  void _showRemoveParticipantDialog(BuildContext context, ParticipantModel participant, MeetingController meetingController) {
    showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Remove Participant'),
            content: Text('Are you sure you want to remove "${participant.name}" from the meeting?'),
            actions: [
              TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
              TextButton(
                onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  await meetingController.removeParticipantForcefully(participant.userId);
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Remove'),
              ),
            ],
          ),
    );
  }
}
