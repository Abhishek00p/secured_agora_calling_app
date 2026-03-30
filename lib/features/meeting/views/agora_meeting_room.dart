import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:secured_calling/core/extensions/app_color_extension.dart';
import 'package:secured_calling/core/models/participant_model.dart';
import 'package:secured_calling/core/services/app_firebase_service.dart';
import 'package:secured_calling/core/services/app_local_storage.dart';
import 'package:secured_calling/core/utils/responsive_utils.dart';
import 'package:secured_calling/utils/app_logger.dart';
import 'package:secured_calling/utils/app_tost_util.dart';
import 'package:secured_calling/core/extensions/app_int_extension.dart';
import 'package:secured_calling/features/meeting/views/join_request_widget.dart';
import 'package:secured_calling/features/meeting/bindings/live_meeting_controller.dart';
import 'package:secured_calling/features/meeting/views/show_meeting_info.dart';
import 'package:secured_calling/widgets/blinking_text.dart';
import 'package:secured_calling/widgets/speaker_ripple_effect.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

// ─────────────────────────────────────────────
// Breakpoints
// ─────────────────────────────────────────────
class _Breakpoint {
  static bool isMobile(double width) => width < 600;
  static bool isTablet(double width) => width >= 600 && width < 1024;
  static bool isLaptop(double width) => width >= 1024;
}

// ─────────────────────────────────────────────
// Responsive scale helpers
// ─────────────────────────────────────────────
class _Scale {
  final double fontSize;
  final double iconSize;
  final double padding;
  final double borderRadius;
  final double topIconSize;
  final double indicatorDotSize;
  final double controlButtonHeight;
  final double controlHorizontalPadding;
  final double micRadius;
  final double bodyHorizontalPadding;
  final double bottomSpacerHeight;
  final double appBarFontSize;
  final double appBarSubFontSize;

  const _Scale({
    required this.fontSize,
    required this.iconSize,
    required this.padding,
    required this.borderRadius,
    required this.topIconSize,
    required this.indicatorDotSize,
    required this.controlButtonHeight,
    required this.controlHorizontalPadding,
    required this.micRadius,
    required this.bodyHorizontalPadding,
    required this.bottomSpacerHeight,
    required this.appBarFontSize,
    required this.appBarSubFontSize,
  });

  static _Scale fromWidth(double width) {
    if (_Breakpoint.isMobile(width)) {
      return const _Scale(
        fontSize: 20,
        iconSize: 20,
        padding: 8,
        borderRadius: 8,
        topIconSize: 14,
        indicatorDotSize: 8,
        controlButtonHeight: 50,
        controlHorizontalPadding: 16,
        micRadius: 60,
        bodyHorizontalPadding: 8,
        bottomSpacerHeight: 20,
        appBarFontSize: 16,
        appBarSubFontSize: 12,
      );
    } else if (_Breakpoint.isTablet(width)) {
      return const _Scale(
        fontSize: 22,
        iconSize: 24,
        padding: 12,
        borderRadius: 10,
        topIconSize: 17,
        indicatorDotSize: 10,
        controlButtonHeight: 58,
        controlHorizontalPadding: 24,
        micRadius: 60,
        bodyHorizontalPadding: 20,
        bottomSpacerHeight: 20,
        appBarFontSize: 18,
        appBarSubFontSize: 13,
      );
    } else {
      // Laptop
      return const _Scale(
        fontSize: 26,
        iconSize: 28,
        padding: 16,
        borderRadius: 12,
        topIconSize: 20,
        indicatorDotSize: 12,
        controlButtonHeight: 64,
        controlHorizontalPadding: 32,
        micRadius: 60,
        bodyHorizontalPadding: 40,
        bottomSpacerHeight: 20,
        appBarFontSize: 20,
        appBarSubFontSize: 14,
      );
    }
  }
}

// ─────────────────────────────────────────────
// Widget
// ─────────────────────────────────────────────
class AgoraMeetingRoom extends StatefulWidget {
  final String meetingId;
  final String channelName;
  final bool isHost;

  const AgoraMeetingRoom({super.key, required this.meetingId, required this.channelName, required this.isHost});

  @override
  State<AgoraMeetingRoom> createState() => _AgoraMeetingRoomState();
}

class _AgoraMeetingRoomState extends State<AgoraMeetingRoom> with WidgetsBindingObserver {
  final meetingController = Get.find<MeetingController>();
  final currentUser = AppLocalStorage.getUserDetails();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable();
    AppLogger.print('meeting id before init  :${widget.meetingId}');
    final alreadyInThisMeeting = meetingController.isJoined.value && meetingController.meetingId == widget.meetingId;
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

  // ─── End Call Button ───────────────────────
  Widget _buildEndCallButton({
    required BuildContext context,
    required bool isHost,
    required VoidCallback onEndCallForAll,
    required Future<void> Function() onLeaveMeeting,
    required _Scale scale,
  }) {
    return InkWell(
      onTap: () {
        showDialog(
          context: context,
          builder:
              (dialogContext) => AlertDialog(
                title: const Text('Confirmation', textAlign: TextAlign.center),
                content: Text(
                  isHost
                      ? 'Do you want to end the call for everyone or just leave the meeting?'
                      : 'Do you want to leave the meeting?',
                ),
                actions: [
                  TextButton(
                    onPressed: () async {
                      Navigator.of(dialogContext).pop();
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (loadingContext) {
                          final loadingDialogContext = loadingContext;
                          onLeaveMeeting()
                              .then((_) {
                                if (loadingDialogContext.mounted) {
                                  Navigator.of(loadingDialogContext).pop();
                                }
                              })
                              .catchError((e) {
                                if (loadingDialogContext.mounted) {
                                  Navigator.of(loadingDialogContext).pop();
                                }
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error leaving meeting: $e'), backgroundColor: Colors.red),
                                  );
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
                  TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
                ],
              ),
        );
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: scale.controlHorizontalPadding),
        height: scale.controlButtonHeight,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(scale.borderRadius), color: Colors.red),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'End Call',
              style: TextStyle(fontSize: scale.fontSize * 0.8, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.call_end, color: Colors.white),
          ],
        ),
      ),
    );
  }

  // ─── Speaker Button ────────────────────────
  Widget _buildSpeakerButton(MeetingController mc, _Scale scale, double responsivePad) {
    return Obx(
      () => SizedBox(
        height: scale.controlButtonHeight,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: mc.isOnSpeaker.value ? Colors.green : Colors.white),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(scale.borderRadius)),
            padding: EdgeInsets.symmetric(horizontal: scale.controlHorizontalPadding, vertical: 8),
          ),
          onPressed: mc.toggleSpeaker,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(mc.isOnSpeaker.value ? Icons.volume_up : Icons.volume_off, size: scale.iconSize),
              const SizedBox(width: 8),
              Text(
                mc.isOnSpeaker.value ? 'Speaker On' : 'Speaker Off',
                style: TextStyle(fontSize: scale.fontSize * 0.65),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Mic Button ────────────────────────────
  Widget _buildMicButton({required MeetingController mc, required _Scale scale, required bool isHost}) {
    if (isHost) {
      return GestureDetector(
        onTap: () {
          if (mc.isMuted.value) {
            mc.startPtt();
          } else {
            mc.stopPtt();
          }
        },
        child: Obx(() {
          final isPttActive = mc.pttUsers.contains(mc.currentUser.userId);
          return CircleAvatar(
            radius: scale.micRadius,
            backgroundColor: isPttActive ? Colors.green : Colors.white.withAppOpacity(0.2),
            child: Icon(isPttActive ? Icons.mic : Icons.mic_off, color: Colors.white, size: scale.micRadius * 0.85),
          );
        }),
      );
    } else {
      return GestureDetector(
        onLongPressStart: (_) => mc.startPtt(),
        onLongPressEnd: (_) => mc.stopPtt(),
        child: Obx(() {
          final isPttActive = mc.pttUsers.contains(mc.currentUser.userId);
          return CircleAvatar(
            radius: scale.micRadius,
            backgroundColor: isPttActive ? Colors.green : Colors.white.withAppOpacity(0.2),
            child: Icon(isPttActive ? Icons.mic : Icons.mic_off, color: Colors.white, size: scale.micRadius * 0.85),
          );
        }),
      );
    }
  }

  // ─── Bottom Controls ───────────────────────
  //
  // On laptop: all controls in a single horizontal Row
  // On mobile/tablet: keep the original stacked layout
  //
  Widget _buildBottomControls(MeetingController mc, _Scale scale, double responsivePad, bool isLaptop) {
    final mic = _buildMicButton(mc: mc, scale: scale, isHost: mc.isHost);
    final speaker = _buildSpeakerButton(mc, scale, responsivePad);
    final endCall = _buildEndCallButton(
      context: context,
      isHost: mc.isHost,
      onEndCallForAll: mc.endMeetForAll,
      onLeaveMeeting: mc.endMeeting,
      scale: scale,
    );

    if (isLaptop) {
      // Laptop: everything in one horizontal row with equal spacing
      final spacing = SizedBox(width: MediaQuery.of(context).size.width * 0.05);
      return Padding(
        padding: EdgeInsets.only(bottom: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [mic, spacing, speaker, spacing, endCall],
        ),
      );
    }

    // Mobile / Tablet: original stacked layout preserved
    if (mc.isHost) {
      return Padding(
        padding: EdgeInsets.only(bottom: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            mic,
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [speaker, SizedBox(height: 16), endCall],
            ),
          ],
        ),
      );
    } else {
      return Padding(
        padding: EdgeInsets.only(bottom: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            mic,
            SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [speaker, SizedBox(width: 16), endCall]),
          ],
        ),
      );
    }
  }

  // ─── Build ─────────────────────────────────
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
                        onPressed: () {
                          // meetingController.toggleMixRecordingButton();
                        },
                        icon:
                        // Obx(
                        //   () =>
                        Icon(
                          // meetingController.isRecordingOn.value ? Icons.stop_circle_rounded :
                          Icons.fiber_manual_record_rounded,
                          size: 24,
                          color: Colors.red,
                        ),
                        // ),
                      ),
                      Obx(() {
                        if (meetingController.isRecordingOn.value && meetingController.isHost) {
                          return BlinkingText(
                            text: 'Rec',
                            style: const TextStyle(fontSize: 14, color: Colors.redAccent, fontWeight: FontWeight.w500),
                          );
                        }
                        return const SizedBox.shrink();
                      }),
                    ],
                  ),
                Obx(() {
                  return meetingController.isRecordingOn.value && !meetingController.isHost
                      ? Row(
                        children: const [
                          Icon(Icons.fiber_manual_record_rounded, size: 24, color: Colors.red),
                          SizedBox(width: 4),
                          BlinkingText(
                            text: 'Rec',
                            style: TextStyle(fontSize: 14, color: Colors.redAccent, fontWeight: FontWeight.w500),
                          ),
                        ],
                      )
                      : const SizedBox.shrink();
                }),
                IconButton(
                  onPressed: () async {
                    meetingController.fetchPendingRequests();
                    showMeetingInfo(context);
                  },
                  icon: const Icon(Icons.settings),
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
                    if (meetingController.remainingSeconds >= 0)
                      Text(
                        'Time remaining: ${meetingController.remainingSeconds.formatDuration}',
                        style: const TextStyle(fontSize: 12, color: Colors.red),
                      ),
                  ],
                ),
              ),
            ),
            body: GetBuilder<MeetingController>(
              builder: (meetingController) {
                if (!meetingController.meetingModel.value.isEmpty) {
                  AppFirebaseService.instance.getMeetingData(widget.meetingId);
                } else {
                  AppLogger.print('Meeting Model is empty');
                }

                return SafeArea(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final double screenWidth = constraints.maxWidth;
                      final scale = _Scale.fromWidth(screenWidth);
                      final isLaptop = _Breakpoint.isLaptop(screenWidth);
                      final responsivePad = responsivePadding(context);

                      return Padding(
                        padding: EdgeInsets.symmetric(horizontal: scale.bodyHorizontalPadding),
                        child: Column(
                          children: [
                            // ── Main content area ──
                            meetingController.isLoading.value
                                ? const Expanded(child: Center(child: CircularProgressIndicator()))
                                : !meetingController.agoraInitialized
                                ? const Expanded(child: Center(child: Text('Agora not initialized yet...!')))
                                : Expanded(
                                  child:
                                      meetingController.isHost
                                          ? _buildHostView(meetingController, screenWidth)
                                          : _buildParticipantView(meetingController, screenWidth),
                                ),

                            // ── Host join requests ──
                            if (meetingController.isHost) JoinRequestWidget(),

                            // ── Bottom controls ──
                            _buildBottomControls(meetingController, scale, responsivePad, isLaptop),

                            SizedBox(height: 20),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  // ─── Participant Tile ──────────────────────
  Widget _buildParticipantTile(ParticipantModel user, MeetingController meetingController, double screenWidth) {
    final scale = _Scale.fromWidth(screenWidth);

    return Container(
      margin: EdgeInsets.all(scale.padding),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(scale.borderRadius),
        border: Border.all(color: user.color),
      ),
      child: Stack(
        children: [
          // Water ripple for PTT users
          Obx(
            () =>
                meetingController.pttUsers.contains(user.userId)
                    ? Positioned.fill(child: WaterRipple(color: user.color))
                    : const SizedBox.shrink(),
          ),

          // Name label
          Padding(
            padding: EdgeInsets.all(scale.padding),
            child: Center(
              child: Text(
                user.userId == meetingController.currentUser.userId ? 'You' : user.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: TextStyle(fontSize: scale.fontSize, color: user.color),
              ),
            ),
          ),

          // Bottom-left mic + speaking indicator
          Positioned(
            bottom: scale.padding,
            left: scale.padding,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Obx(() {
                  final isMuted = user.isUserMuted || !meetingController.pttUsers.contains(user.userId);
                  return Icon(
                    isMuted ? Icons.mic_off : Icons.mic,
                    color: isMuted ? Colors.red : Colors.white,
                    size: scale.iconSize,
                  );
                }),
                Obx(() {
                  if (meetingController.pttUsers.contains(user.userId)) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(width: scale.padding / 2),
                        Container(
                          width: scale.indicatorDotSize,
                          height: scale.indicatorDotSize,
                          decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                        ),
                      ],
                    );
                  }
                  return const SizedBox.shrink();
                }),
              ],
            ),
          ),

          // Top-right PTT active badge
          Obx(() {
            if (meetingController.pttUsers.contains(user.userId)) {
              return Positioned(
                top: scale.padding,
                right: scale.padding,
                child: Container(
                  padding: EdgeInsets.all(scale.padding / 2),
                  decoration: BoxDecoration(color: Colors.green.withOpacity(0.8), shape: BoxShape.circle),
                  child: Icon(Icons.mic, color: Colors.white, size: scale.topIconSize),
                ),
              );
            }
            return const SizedBox.shrink();
          }),

          // Top-left host controls (remove participant)
          if (meetingController.isHost && user.userId != meetingController.currentUser.userId)
            Positioned(
              top: scale.padding,
              left: scale.padding,
              child: PopupMenuButton<String>(
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (value) {
                  if (value == 'remove') {
                    _showRemoveParticipantDialog(context, user, meetingController);
                  }
                  if (value == 'make_host') {
                    meetingController.transferHost(user.userId);
                  }
                },
                itemBuilder:
                    (context) => [
                      PopupMenuItem(
                        value: 'remove',
                        child: Row(
                          children: const [
                            Icon(Icons.close, color: Colors.red, size: 18),
                            SizedBox(width: 8),
                            Text("Remove"),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'make_host',
                        child: Row(
                          children: const [
                            Icon(Icons.star, color: Colors.yellow, size: 18),
                            SizedBox(width: 8),
                            Text("Make Host"),
                          ],
                        ),
                      ),
                    ],
                child: Container(
                  padding: EdgeInsets.all(scale.padding / 2),
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), shape: BoxShape.circle),
                  child: Icon(Icons.more_vert, color: Colors.white, size: scale.topIconSize),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Host Grid View ────────────────────────
  Widget _buildHostView(MeetingController meetingController, double screenWidth) {
    int crossAxisCount;
    double childAspectRatio;

    if (_Breakpoint.isMobile(screenWidth)) {
      switch (meetingController.participants.length) {
        case < 3:
          crossAxisCount = 1;
          childAspectRatio = 1.75;
          break;
        default:
          crossAxisCount = 2;
          childAspectRatio = 1.0;
      }
    } else if (_Breakpoint.isTablet(screenWidth)) {
      crossAxisCount = 3;
      childAspectRatio = 1.05;
    } else {
      switch (meetingController.participants.length) {
        case > 4:
          crossAxisCount = 6;
          childAspectRatio = 1.1;
          break;
        case < 3:
          crossAxisCount = 2;
          childAspectRatio = 1.3;
          break;
        default:
          crossAxisCount = 2;
          childAspectRatio = 2.5;
      }
    }

    return GridView.builder(
      itemCount: meetingController.participants.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemBuilder: (context, index) {
        final user = meetingController.participants[index];
        return _buildParticipantTile(user, meetingController, screenWidth);
      },
    );
  }

  // ─── Participant List View ─────────────────
  Widget _buildParticipantView(MeetingController meetingController, double screenWidth) {
    final host = meetingController.participants.firstWhereOrNull(
      (p) => p.userId == meetingController.meetingModel.value.hostUserId,
    );
    final self = meetingController.participants.firstWhereOrNull(
      (p) => p.userId == meetingController.currentUser.userId,
    );

    final List<ParticipantModel> viewParticipants = [];
    if (host != null) viewParticipants.add(host);
    if (self != null && self.userId != host?.userId) {
      viewParticipants.add(self);
    }

    final bool isLaptop = _Breakpoint.isLaptop(screenWidth);

    final double tileHeight =
        _Breakpoint.isMobile(screenWidth)
            ? MediaQuery.of(context).size.height * 0.25
            : _Breakpoint.isTablet(screenWidth)
            ? 220
            : 280;

    // Laptop → horizontal row of cards
    if (isLaptop) {
      return SizedBox(
        height: tileHeight,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: viewParticipants.length,
          itemBuilder: (context, index) {
            final user = viewParticipants[index];
            return SizedBox(
              width: 320,
              height: tileHeight,
              child: _buildParticipantTile(user, meetingController, screenWidth),
            );
          },
        ),
      );
    }

    // Mobile & Tablet → vertical list
    return ListView.builder(
      itemCount: viewParticipants.length,
      itemBuilder: (context, index) {
        final user = viewParticipants[index];
        return SizedBox(height: tileHeight, child: _buildParticipantTile(user, meetingController, screenWidth));
      },
    );
  }

  // ─── Helpers ──────────────────────────────
  Widget speakerRippleEffect({required int userId, required int activeSpeakerUid, required Color color}) {
    return Obx(() {
      if (userId == activeSpeakerUid) {
        return Container(
          decoration: BoxDecoration(shape: BoxShape.circle, color: color.withAppOpacity(0.5)),
          child: const CircularProgressIndicator(),
        );
      }
      return Container();
    });
  }

  void _showRemoveParticipantDialog(
    BuildContext context,
    ParticipantModel participant,
    MeetingController meetingController,
  ) {
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
