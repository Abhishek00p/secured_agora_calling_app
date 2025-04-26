import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get/get_state_manager/get_state_manager.dart';
import 'package:secured_calling/app_logger.dart';
import 'package:secured_calling/core/extensions/app_int_extension.dart';
import 'package:secured_calling/features/meeting/views/live_meeting_controller.dart';
import 'package:secured_calling/features/meeting/views/showPendingRequestDialog.dart';

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
  Widget _buildEndCallButton(VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16),
        height: 50,
        color: Colors.red,
        child: Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('End Call'),
            SizedBox(width: 10),
            Icon(Icons.call_end),
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
    bool isEndCall = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: isEndCall ? Colors.red : Colors.black54,
              borderRadius: BorderRadius.circular(25),
            ),
            child: IconButton(
              icon: Icon(icon),
              color: color,
              onPressed: onPressed,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildControlBar(MeetingController meetingController) {
    return SizedBox(
      height: 70,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Obx(
              () => _buildControlButton(
                icon:
                    meetingController.isMuted.value ? Icons.mic_off : Icons.mic,
                label: meetingController.isMuted.value ? 'Unmute' : 'Mute',
                color:
                    meetingController.isMuted.value ? Colors.red : Colors.white,
                onPressed: meetingController.toggleMute,
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
  @override
  void initState() {
    AppLogger.print('meeting id before init  :${widget.meetingId}');
    meetingController.inint(widget.meetingId, widget.isHost);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<MeetingController>(
      builder: (meetingController) {
        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text('Meeting Room'),
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
          bottomNavigationBar: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildControlBar(meetingController),
              _buildEndCallButton(() async {
                await meetingController.endMeeting(meetingId: widget.meetingId);

                if (mounted) {
                  AppLogger.print("popping context from meeting room.....");
                  Navigator.pop(context);
                }
              }),
            ],
          ),
          body: GetBuilder<MeetingController>(
          builder: (meetingController) {
            return SafeArea(
              child:   Column(
                children: [
                  meetingController.isLoading.value
                      ? const Center(child: CircularProgressIndicator())
                      :! meetingController.agoraInitialized?Center(child: Text('Agora not intialized yet...!'),): Expanded(
                        child: Stack(
                          children: [
                            // _buildVideoGrid([]),//TODO: implement dynamic 
                            // _buildLocalVideo(),
                            Center(child: Text(widget.meetingId),),
                            // Bottom Control Bar
                            Positioned(
                              right: 10,
                              top: 0,
                              child: IconButton(
                                onPressed: () async {
                                  // await fetchPendingRequests();
                                  showPendingRequestsDialog(context);
                                },
                                icon: Icon(Icons.settings),
                              ),
                            ),
                          ],
                        ),
                      ),
                ],
              ),
            );
          }
        ),
    
        );
      },
    );
  }
}
