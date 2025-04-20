import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:secured_calling/app_tost_util.dart';
import 'package:secured_calling/core/extensions/app_int_extension.dart';
import 'package:secured_calling/core/routes/app_router.dart';
import 'package:secured_calling/core/services/app_firebase_service.dart';
import 'package:secured_calling/core/theme/app_theme.dart';
import 'package:secured_calling/features/meeting/services/agora_service.dart';
import 'package:secured_calling/features/meeting/views/live_meeting_controller.dart';

class MeetingRoom extends ConsumerStatefulWidget {
  final String channelName;
  final bool isHost;
  final String meetingId;
  const MeetingRoom({
    required this.channelName,
    this.isHost = false,
    super.key,
    required this.meetingId,
  });

  @override
  ConsumerState<MeetingRoom> createState() => _MeetingRoomState();
}

class _MeetingRoomState extends ConsumerState<MeetingRoom> {
  final AgoraService _agoraService = AgoraService();
  final AppFirebaseService _firebaseService = AppFirebaseService.instance;

  // UI States
  bool _isLoading = true;
  bool _isMuted = false;
  bool _isVideoEnabled = true;
  bool _isScreenSharing = false;
  bool _isSettingsOpen = false;
  bool _isChatOpen = false;
  bool _isParticipantListOpen = false;
  bool _isRecording = false;
  bool _isSpeakerFocusEnabled = false;
  bool _isAudioOnlyMode = true;
  int? _focusedUserId;

  // Meeting info
  String? _meetingId;
  Map<String, dynamic>? _meetingData;
  List<Map<String, dynamic>> _pendingRequests = [];

  // Free trial countdown
  int? _remainingSeconds;
  bool _showExtendOption = false;

  // Chat
  final TextEditingController _chatController = TextEditingController();
  final List<Map<String, dynamic>> _chatMessages = [];

  // Participants control
  final Map<int, bool> _remoteUserAudioStates = {}; // uid -> isEnabled
  final Map<int, bool> _remoteUserVideoStates = {}; // uid -> isEnabled

  @override
  void initState() {
    super.initState();
    _initializeAgora();
    if (widget.isHost) {
      _getMeetingData();
    }
  }

  Future<void> _getMeetingData() async {
    try {
      final querySnapshot = await _firebaseService.searchMeetingByChannelName(
        widget.channelName,
      );
      if (querySnapshot.docs.isNotEmpty) {
        setState(() {
          _meetingId = querySnapshot.docs.first.id;
          _meetingData =
              querySnapshot.docs.first.data() as Map<String, dynamic>;
        });
      }
    } catch (e) {
      AppToastUtil.showErrorToast(context, 'Error loading meeting data: $e');
    }
  }

  Future<void> _initializeAgora() async {
    try {
      await _agoraService.initialize(
        onUserJoined: _onUserJoined,
        onUserOffline: _onUserOffline,
        onUserAudioStateChanged: _onUserAudioStateChanged,
        onUserVideoStateChanged: _onUserVideoStateChanged,
        onMeetingEnded: _onMeetingEnded,
        onFreeTrialCountdown: _onFreeTrialCountdown,
      );

      await _agoraService.joinChannel(
        channelName: 'testing',
        //  widget.channelName,
        isFreeTrial: !widget.isHost, // Free trial for non-hosts
      );

      setState(() {
        _isLoading = false;
      });
      if (_agoraService.isInitialized) {
        AppToastUtil.showSuccessToast(
          context,
          'Agora intialized , lets go......',
        );
        AppFirebaseService.instance.startMeeting(widget.meetingId);
      } else {
        AppToastUtil.showErrorToast(
          context,
          'Agora not intialized , dont go......',
        );
      }
    } catch (e) {
      debugPrint("error in init agora :$e");
      AppToastUtil.showErrorToast(context, 'Error initializing video call: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Agora callbacks
  void _onUserJoined(int uid) {
    ref.read(remoteUsersProvider.notifier).addUser(uid);
    setState(() {
      _remoteUserAudioStates[uid] = true;
      _remoteUserVideoStates[uid] = true;
    });
  }

  void _onUserOffline(int uid) {
    ref.read(remoteUsersProvider.notifier).removeUser(uid);
    setState(() {
      _remoteUserAudioStates.remove(uid);
      _remoteUserVideoStates.remove(uid);
      if (_focusedUserId == uid) {
        _focusedUserId = null;
      }
    });
  }

  void _onUserAudioStateChanged(int uid, bool enabled) {
    setState(() {
      _remoteUserAudioStates[uid] = enabled;
    });
  }

  void _onUserVideoStateChanged(int uid, bool enabled) {
    setState(() {
      _remoteUserVideoStates[uid] = enabled;
    });
  }

  void _onMeetingEnded() {
    // Navigator.pop(context);
  }

  void _onFreeTrialCountdown(int remainingSeconds) {
    setState(() {
      _remainingSeconds = remainingSeconds;
      // Show extend option when 1 minute remaining
      _showExtendOption = remainingSeconds <= 60;
    });
  }

  // UI Actions
  Future<void> _toggleMute() async {
    await _agoraService.toggleMute();
    setState(() {
      _isMuted = !_isMuted;
    });
  }

  Future<void> _toggleVideo() async {
    await _agoraService.toggleVideo();
    setState(() {
      _isVideoEnabled = !_isVideoEnabled;
    });
  }

  Future<void> _toggleAudioOnlyMode() async {
    await _agoraService.toggleAudioOnlyMode();
    setState(() {
      _isAudioOnlyMode = !_isAudioOnlyMode;
      if (_isAudioOnlyMode) {
        // Audio-only mode forces video off
        _isVideoEnabled = false;
      }
    });
    ref.read(isAudioOnlyModeProvider.notifier).state = _isAudioOnlyMode;
  }

  Future<void> _toggleScreenSharing() async {
    try {
      if (_isScreenSharing) {
        await _agoraService.stopScreenSharing();
      } else {
        await _agoraService.startScreenSharing();
      }
      setState(() {
        _isScreenSharing = !_isScreenSharing;
      });
    } catch (e) {
      AppToastUtil.showErrorToast(context, 'Error toggling screen sharing: $e');
    }
  }

  Future<void> _toggleRecording() async {
    try {
      if (_isRecording) {
        await _agoraService.stopRecording();
      } else {
        await _agoraService.startRecording();
      }
      setState(() {
        _isRecording = !_isRecording;
      });
    } catch (e) {
      AppToastUtil.showErrorToast(context, 'Error toggling recording: $e');
    }
  }

  void _toggleSpeakerFocus() {
    setState(() {
      _isSpeakerFocusEnabled = !_isSpeakerFocusEnabled;
      if (!_isSpeakerFocusEnabled) {
        _focusedUserId = null;
      }
    });
  }

  void _focusOnUser(int uid) {
    if (!_isSpeakerFocusEnabled) return;

    setState(() {
      _focusedUserId = _focusedUserId == uid ? null : uid;
    });
    _agoraService.setFocusedUser(_focusedUserId);
  }

  Future<void> _muteRemoteUser(int uid) async {
    await _agoraService.toggleRemoteAudio(uid, true); // true = mute
  }

  Future<void> _extendMeeting() async {
    if (_meetingId == null) return;

    try {
      // Extend meeting by 15 minutes
      await _firebaseService.extendMeeting(_meetingId!, 15);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Meeting extended by 15 minutes')),
      );
    } catch (e) {
      AppToastUtil.showErrorToast(context, 'Error extending meeting: $e');
    }
  }

  void _sendChatMessage() {
    final message = _chatController.text.trim();
    if (message.isEmpty) return;

    // In a full implementation, this would send to Firebase
    // For demo purposes, we're just adding it locally
    setState(() {
      _chatMessages.add({
        'userId': _firebaseService.currentUser!.uid,
        'name': _firebaseService.currentUser!.displayName ?? 'You',
        'message': message,
        'timestamp': DateTime.now(),
        'isCurrentUser': true,
      });
    });

    _chatController.clear();
  }

  @override
  void dispose() {
    _chatController.dispose();
    _agoraService.destroy();
    super.dispose();
  }

  void endMeeting(MeetingController controller) async {
    await controller.endMeeting(
      leaveAgora: () async {
        _agoraService.leaveChannel();
      },
      meetingId: widget.meetingId,
    );
    if (mounted) {
      debugPrint("popping context from meeting room.....");
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final remoteUsers = ref.watch(remoteUsersProvider);
    final controller = ref.read(
      meetingControllerProvider((
        isHost: widget.isHost,
        meetingId: widget.channelName,
      )).notifier,
    );
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        endMeeting(controller);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text('Meeting Room'),
              if (_remainingSeconds != null) ...[
                Text(
                  'Time remaining: ${_remainingSeconds!.formatDuration}',
                  style: const TextStyle(fontSize: 12, color: Colors.red),
                ),
              ],
            ],
          ),
          //
        ),
        body:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Stack(
                  children: [
                    _buildVideoGrid(remoteUsers),
                    _buildLocalVideo(),
                    // Bottom Control Bar
                    _buildControlBar(),
                    _buildEndCallButton(() => endMeeting(controller)),
                    Positioned(
                      right: 10,
                      top: 10,
                      child: IconButton(
                        onPressed: () => _showPendingRequestsDialog(controller),
                        icon: Icon(Icons.settings),
                      ),
                    ),
                  ],
                ),
      ),
    );
  }

  Widget _buildVideoGrid(List<int> remoteUsers) {
    // If speaker focus is enabled and we have a focused user, show only that user
    if (_isSpeakerFocusEnabled && _focusedUserId != null) {
      return Center(
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            color: Colors.black,
            child: Stack(
              children: [
                Center(
                  child: AgoraVideoView(
                    controller: VideoViewController.remote(
                      rtcEngine: _agoraService.engine!,
                      canvas: VideoCanvas(uid: _focusedUserId),
                      connection: RtcConnection(channelId: widget.channelName),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_remoteUserAudioStates[_focusedUserId] ==
                            false) ...[
                          const Icon(
                            Icons.mic_off,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                        ],
                        const Text(
                          'Speaker View',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Calculate grid dimensions
    final int totalUsers = remoteUsers.length;
    if (totalUsers == 0) {
      return const Center(child: Text('Waiting for others to join...'));
    }

    int crossAxisCount = 2;
    if (totalUsers > 4) crossAxisCount = 3;
    if (totalUsers > 9) crossAxisCount = 4;

    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 16 / 9,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: totalUsers,
      itemBuilder: (context, index) {
        final remoteUid = remoteUsers[index];
        return GestureDetector(
          onTap: () => _focusOnUser(remoteUid),
          child: Container(
            color: Colors.black,
            child: Stack(
              children: [
                Center(
                  child:
                      _remoteUserVideoStates[remoteUid] == false
                          ? Container(
                            color: Colors.black54,
                            child: const Center(
                              child: Icon(
                                Icons.videocam_off,
                                color: Colors.white,
                                size: 40,
                              ),
                            ),
                          )
                          : AgoraVideoView(
                            controller: VideoViewController.remote(
                              rtcEngine: _agoraService.engine!,
                              canvas: VideoCanvas(uid: remoteUid),
                              connection: RtcConnection(
                                channelId: widget.channelName,
                              ),
                            ),
                          ),
                ),
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_remoteUserAudioStates[remoteUid] == false) ...[
                          const Icon(
                            Icons.mic_off,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          'User $remoteUid',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (widget.isHost) ...[
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Mute remote user
                        GestureDetector(
                          onTap: () => _muteRemoteUser(remoteUid),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Icon(
                              Icons.mic_off,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_isSpeakerFocusEnabled) ...[
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: () => _focusOnUser(remoteUid),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: AppTheme.primaryColor,
                            width: 2,
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.fullscreen,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLocalVideo() {
    return Positioned(
      left: 16,
      bottom: 150,
      width: 120,
      height: 160,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white),
          color: Colors.black,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            children: [
              Center(
                child:
                    _isVideoEnabled
                        ? AgoraVideoView(
                          controller: VideoViewController(
                            rtcEngine: _agoraService.engine!,
                            canvas: const VideoCanvas(uid: 0),
                          ),
                        )
                        : Container(
                          color: Colors.black54,
                          child: const Center(
                            child: Icon(
                              Icons.videocam_off,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                        ),
              ),
              Positioned(
                bottom: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isMuted) ...[
                        const Icon(
                          Icons.mic_off,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                      ],
                      const Text(
                        'You',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEndCallButton(VoidCallback onTap) {
    return Positioned(
      bottom: 16,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: MediaQuery.sizeOf(context).width,
          padding: EdgeInsets.symmetric(horizontal: 16),
          height: 30,
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
      ),
    );
  }

  Widget _buildControlBar() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 60,
      child: SafeArea(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildControlButton(
                icon: _isMuted ? Icons.mic_off : Icons.mic,
                label: _isMuted ? 'Unmute' : 'Mute',
                color: _isMuted ? Colors.red : Colors.white,
                onPressed: _toggleMute,
              ),
              _buildControlButton(
                icon: _isVideoEnabled ? Icons.videocam : Icons.videocam_off,
                label: _isVideoEnabled ? 'Stop Video' : 'Start Video',
                color: _isVideoEnabled ? Colors.white : Colors.red,
                onPressed: _toggleVideo,
              ),
              _buildControlButton(
                icon: Icons.screen_share,
                label: 'Share Screen',
                color: _isScreenSharing ? AppTheme.accentColor : Colors.white,
                onPressed: _toggleScreenSharing,
              ),
              if (widget.isHost) ...[
                _buildControlButton(
                  icon:
                      _isRecording
                          ? Icons.fiber_manual_record
                          : Icons.fiber_manual_record_outlined,
                  label: _isRecording ? 'Stop Recording' : 'Record',
                  color: _isRecording ? Colors.red : Colors.white,
                  onPressed: _toggleRecording,
                ),
                _buildControlButton(
                  icon:
                      _isSpeakerFocusEnabled
                          ? Icons.center_focus_strong
                          : Icons.center_focus_weak,
                  label: 'Speaker Focus',
                  color:
                      _isSpeakerFocusEnabled
                          ? AppTheme.accentColor
                          : Colors.white,
                  onPressed: _toggleSpeakerFocus,
                ),
              ],
            ],
          ),
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

  // Widget _buildParticipantsPanel(List<int> remoteUsers) {
  //   return Positioned(
  //     right: 0,
  //     top: 0,
  //     bottom: 80,
  //     width: 300,
  //     child: Container(
  //       margin: const EdgeInsets.all(16),
  //       decoration: BoxDecoration(
  //         color: Theme.of(context).cardTheme.color,
  //         borderRadius: BorderRadius.circular(12),
  //         boxShadow: [
  //           BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10),
  //         ],
  //       ),
  //       child: Column(
  //         children: [
  //           Padding(
  //             padding: const EdgeInsets.all(16.0),
  //             child: Row(
  //               mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //               children: [
  //                 Text(
  //                   'Participants (${1 + remoteUsers.length})', // +1 for local user
  //                   style: const TextStyle(fontWeight: FontWeight.bold),
  //                 ),
  //                 IconButton(
  //                   icon: const Icon(Icons.close),
  //                   onPressed:
  //                       () => setState(() => _isParticipantListOpen = false),
  //                 ),
  //               ],
  //             ),
  //           ),
  //           const Divider(height: 1),
  //           Expanded(
  //             child: ListView(
  //               children: [
  //                 // Local user (you)
  //                 ListTile(
  //                   leading: CircleAvatar(
  //                     backgroundColor: AppTheme.primaryColor,
  //                     child: const Text(
  //                       'Y',
  //                       style: TextStyle(color: Colors.white),
  //                     ),
  //                   ),
  //                   title: const Text(
  //                     'You (Host)',
  //                     style: TextStyle(fontWeight: FontWeight.bold),
  //                   ),
  //                   subtitle: Text(_isMuted ? 'Muted' : 'Unmuted'),
  //                   trailing: IconButton(
  //                     icon: Icon(_isMuted ? Icons.mic_off : Icons.mic),
  //                     onPressed: _toggleMute,
  //                   ),
  //                 ),
  //                 // Remote users
  //                 // ...remoteUsers.map(
  //                 //   (uid) => ListTile(
  //                 //     leading: CircleAvatar(
  //                 //       backgroundColor: Colors.grey,
  //                 //       child: Text(
  //                 //         '${uid.toString().substring(0, 1)}',
  //                 //         style: const TextStyle(color: Colors.white),
  //                 //       ),
  //                 //     ),
  //                 //     title: Text('User $uid'),
  //                 //     subtitle: Text(
  //                 //       _remoteUserAudioStates[uid] == false
  //                 //           ? 'Muted'
  //                 //           : 'Unmuted',
  //                 //     ),
  //                 //     trailing:
  //                 //         widget.isHost
  //                 //             ? Row(
  //                 //               mainAxisSize: MainAxisSize.min,
  //                 //               children: [
  //                 //                 IconButton(
  //                 //                   icon: Icon(
  //                 //                     _remoteUserAudioStates[uid] == false
  //                 //                         ? Icons.mic_off
  //                 //                         : Icons.mic,
  //                 //                   ),
  //                 //                   onPressed: () => _muteRemoteUser(uid),
  //                 //                 ),
  //                 //                 IconButton(
  //                 //                   icon: const Icon(Icons.more_vert),
  //                 //                   onPressed:
  //                 //                       () => _showUserOptionsDialog(uid),
  //                 //                 ),
  //                 //               ],
  //                 //             )
  //                 //             : null,
  //                 //   ),
  //                 // ),

  //               ],
  //             ),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  // Widget _buildChatPanel() {
  //   return Positioned(
  //     right: 0,
  //     top: 0,
  //     bottom: 80,
  //     width: 300,
  //     child: Container(
  //       margin: const EdgeInsets.all(16),
  //       decoration: BoxDecoration(
  //         color: Theme.of(context).cardTheme.color,
  //         borderRadius: BorderRadius.circular(12),
  //         boxShadow: [
  //           BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10),
  //         ],
  //       ),
  //       child: Column(
  //         children: [
  //           Padding(
  //             padding: const EdgeInsets.all(16.0),
  //             child: Row(
  //               mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //               children: [
  //                 const Text(
  //                   'Chat',
  //                   style: TextStyle(fontWeight: FontWeight.bold),
  //                 ),
  //                 IconButton(
  //                   icon: const Icon(Icons.close),
  //                   onPressed: () => setState(() => _isChatOpen = false),
  //                 ),
  //               ],
  //             ),
  //           ),
  //           const Divider(height: 1),
  //           Expanded(
  //             child:
  //                 _chatMessages.isEmpty
  //                     ? const Center(child: Text('No messages yet'))
  //                     : ListView.builder(
  //                       itemCount: _chatMessages.length,
  //                       itemBuilder: (context, index) {
  //                         final message = _chatMessages[index];
  //                         final isCurrentUser =
  //                             message['isCurrentUser'] == true;

  //                         return Padding(
  //                           padding: const EdgeInsets.symmetric(
  //                             vertical: 4,
  //                             horizontal: 16,
  //                           ),
  //                           child: Row(
  //                             mainAxisAlignment:
  //                                 isCurrentUser
  //                                     ? MainAxisAlignment.end
  //                                     : MainAxisAlignment.start,
  //                             children: [
  //                               if (!isCurrentUser) ...[
  //                                 CircleAvatar(
  //                                   radius: 16,
  //                                   backgroundColor: Colors.grey,
  //                                   child: Text(
  //                                     message['name'].substring(0, 1),
  //                                     style: const TextStyle(
  //                                       color: Colors.white,
  //                                     ),
  //                                   ),
  //                                 ),
  //                                 const SizedBox(width: 8),
  //                               ],
  //                               Flexible(
  //                                 child: Container(
  //                                   padding: const EdgeInsets.symmetric(
  //                                     horizontal: 12,
  //                                     vertical: 8,
  //                                   ),
  //                                   decoration: BoxDecoration(
  //                                     color:
  //                                         isCurrentUser
  //                                             ? AppTheme.primaryColor
  //                                             : Colors.grey.shade200,
  //                                     borderRadius: BorderRadius.circular(16),
  //                                   ),
  //                                   child: Column(
  //                                     crossAxisAlignment:
  //                                         CrossAxisAlignment.start,
  //                                     children: [
  //                                       if (!isCurrentUser) ...[
  //                                         Text(
  //                                           message['name'],
  //                                           style: TextStyle(
  //                                             fontWeight: FontWeight.bold,
  //                                             color:
  //                                                 isCurrentUser
  //                                                     ? Colors.white
  //                                                     : Colors.black,
  //                                             fontSize: 12,
  //                                           ),
  //                                         ),
  //                                         const SizedBox(height: 4),
  //                                       ],
  //                                       Text(
  //                                         message['message'],
  //                                         style: TextStyle(
  //                                           color:
  //                                               isCurrentUser
  //                                                   ? Colors.white
  //                                                   : Colors.black,
  //                                         ),
  //                                       ),
  //                                     ],
  //                                   ),
  //                                 ),
  //                               ),
  //                               if (isCurrentUser) ...[
  //                                 const SizedBox(width: 8),
  //                                 CircleAvatar(
  //                                   radius: 16,
  //                                   backgroundColor: AppTheme.primaryColor,
  //                                   child: const Text(
  //                                     'Y',
  //                                     style: TextStyle(color: Colors.white),
  //                                   ),
  //                                 ),
  //                               ],
  //                             ],
  //                           ),
  //                         );
  //                       },
  //                     ),
  //           ),
  //           const Divider(height: 1),
  //           Padding(
  //             padding: const EdgeInsets.all(8.0),
  //             child: Row(
  //               children: [
  //                 Expanded(
  //                   child: TextField(
  //                     controller: _chatController,
  //                     decoration: const InputDecoration(
  //                       hintText: 'Type a message...',
  //                       border: OutlineInputBorder(
  //                         borderRadius: BorderRadius.all(Radius.circular(20)),
  //                       ),
  //                       contentPadding: EdgeInsets.symmetric(
  //                         horizontal: 16,
  //                         vertical: 8,
  //                       ),
  //                     ),
  //                     textInputAction: TextInputAction.send,
  //                     onSubmitted: (_) => _sendChatMessage(),
  //                   ),
  //                 ),
  //                 const SizedBox(width: 8),
  //                 CircleAvatar(
  //                   backgroundColor: AppTheme.primaryColor,
  //                   child: IconButton(
  //                     icon: const Icon(Icons.send, color: Colors.white),
  //                     onPressed: _sendChatMessage,
  //                   ),
  //                 ),
  //               ],
  //             ),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  // Widget _buildSettingsPanel() {
  //   return Positioned(
  //     right: 0,
  //     top: 0,
  //     bottom: 80,
  //     width: 300,
  //     child: Container(
  //       margin: const EdgeInsets.all(16),
  //       decoration: BoxDecoration(
  //         color: Theme.of(context).cardTheme.color,
  //         borderRadius: BorderRadius.circular(12),
  //         boxShadow: [
  //           BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10),
  //         ],
  //       ),
  //       child: Column(
  //         children: [
  //           Padding(
  //             padding: const EdgeInsets.all(16.0),
  //             child: Row(
  //               mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //               children: [
  //                 const Text(
  //                   'Meeting Settings',
  //                   style: TextStyle(fontWeight: FontWeight.bold),
  //                 ),
  //                 IconButton(
  //                   icon: const Icon(Icons.close),
  //                   onPressed: () => setState(() => _isSettingsOpen = false),
  //                 ),
  //               ],
  //             ),
  //           ),
  //           const Divider(height: 1),
  //           Expanded(
  //             child: ListView(
  //               padding: const EdgeInsets.all(16),
  //               children: [
  //                 // Meeting Info
  //                 Container(
  //                   padding: const EdgeInsets.all(16),
  //                   decoration: BoxDecoration(
  //                     color: Colors.grey.withOpacity(0.1),
  //                     borderRadius: BorderRadius.circular(8),
  //                   ),
  //                   child: Column(
  //                     crossAxisAlignment: CrossAxisAlignment.start,
  //                     children: [
  //                       const Text(
  //                         'Meeting Information',
  //                         style: TextStyle(fontWeight: FontWeight.bold),
  //                       ),
  //                       const SizedBox(height: 8),
  //                       Row(
  //                         children: [
  //                           const Text('Meeting ID: '),
  //                           Expanded(
  //                             child: Text(
  //                               widget.channelName,
  //                               style: const TextStyle(
  //                                 fontWeight: FontWeight.bold,
  //                               ),
  //                             ),
  //                           ),
  //                         ],
  //                       ),
  //                       if (_meetingData != null) ...[
  //                         const SizedBox(height: 4),
  //                         Row(
  //                           children: [
  //                             const Text('Meeting Name: '),
  //                             Expanded(
  //                               child: Text(
  //                                 _meetingData!['meetingName'] as String,
  //                                 style: const TextStyle(
  //                                   fontWeight: FontWeight.bold,
  //                                 ),
  //                               ),
  //                             ),
  //                           ],
  //                         ),
  //                       ],
  //                     ],
  //                   ),
  //                 ),
  //                 const SizedBox(height: 16),

  //                 // User Settings
  //                 const Text(
  //                   'User Settings',
  //                   style: TextStyle(fontWeight: FontWeight.bold),
  //                 ),
  //                 const SizedBox(height: 8),
  //                 SwitchListTile(
  //                   title: const Text('Mute my microphone'),
  //                   value: _isMuted,
  //                   onChanged: (value) => _toggleMute(),
  //                 ),
  //                 SwitchListTile(
  //                   title: const Text('Disable my camera'),
  //                   value: !_isVideoEnabled,
  //                   onChanged:
  //                       _isAudioOnlyMode
  //                           ? null
  //                           : (value) =>
  //                               _toggleVideo(), // Disable toggle when in audio-only mode
  //                 ),
  //                 SwitchListTile(
  //                   title: const Text('Audio-Only Mode'),
  //                   subtitle: const Text(
  //                     'Disables video for all participants to save bandwidth',
  //                   ),
  //                   value: _isAudioOnlyMode,
  //                   onChanged: (value) => _toggleAudioOnlyMode(),
  //                   activeColor: AppTheme.accentColor,
  //                 ),
  //                 if (_isAudioOnlyMode) ...[
  //                   const Padding(
  //                     padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
  //                     child: Text(
  //                       'Audio-only mode is active. Video is disabled to conserve bandwidth and improve call quality.',
  //                       style: TextStyle(
  //                         fontSize: 12,
  //                         fontStyle: FontStyle.italic,
  //                       ),
  //                     ),
  //                   ),
  //                 ],

  //                 if (widget.isHost) ...[
  //                   const SizedBox(height: 16),
  //                   const Text(
  //                     'Host Settings',
  //                     style: TextStyle(fontWeight: FontWeight.bold),
  //                   ),
  //                   const SizedBox(height: 8),
  //                   SwitchListTile(
  //                     title: const Text('Enable Speaker Focus Mode'),
  //                     value: _isSpeakerFocusEnabled,
  //                     onChanged: (value) => _toggleSpeakerFocus(),
  //                   ),
  //                   SwitchListTile(
  //                     title: const Text('Record Meeting'),
  //                     value: _isRecording,
  //                     onChanged: (value) => _toggleRecording(),
  //                   ),
  //                   ListTile(
  //                     title: const Text('Extend Meeting Time'),
  //                     trailing: ElevatedButton(
  //                       onPressed: _extendMeeting,
  //                       child: const Text('+15 min'),
  //                     ),
  //                   ),
  //                 ],
  //               ],
  //             ),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  // Widget _buildExtendMeetingPrompt() {
  //   return Positioned(
  //     left: 0,
  //     right: 0,
  //     bottom: 100,
  //     child: Center(
  //       child: Container(
  //         width: 300,
  //         padding: const EdgeInsets.all(16),
  //         decoration: BoxDecoration(
  //           color: Colors.red.shade700,
  //           borderRadius: BorderRadius.circular(12),
  //         ),
  //         child: Column(
  //           mainAxisSize: MainAxisSize.min,
  //           children: [
  //             const Text(
  //               'Meeting ending soon',
  //               style: TextStyle(
  //                 color: Colors.white,
  //                 fontWeight: FontWeight.bold,
  //               ),
  //             ),
  //             const SizedBox(height: 8),
  //             Text(
  //               'Your meeting will end in ${(_remainingSeconds ?? 0).formatDuration}',
  //               style: const TextStyle(color: Colors.white),
  //             ),
  //             const SizedBox(height: 16),
  //             ElevatedButton(
  //               onPressed: _extendMeeting,
  //               style: ElevatedButton.styleFrom(
  //                 backgroundColor: Colors.white,
  //                 foregroundColor: Colors.red.shade700,
  //               ),
  //               child: const Text('Extend Meeting'),
  //             ),
  //           ],
  //         ),
  //       ),
  //     ),
  //   );
  // }

  // void _showUserOptionsDialog(int uid) {
  //   showDialog(
  //     context: context,
  //     builder:
  //         (context) => AlertDialog(
  //           title: Text('Options for User $uid'),
  //           content: Column(
  //             mainAxisSize: MainAxisSize.min,
  //             children: [
  //               ListTile(
  //                 leading: const Icon(Icons.mic_off),
  //                 title: const Text('Mute User'),
  //                 onTap: () {
  //                   Navigator.pop(context);
  //                   _muteRemoteUser(uid);
  //                 },
  //               ),
  //               ListTile(
  //                 leading: const Icon(Icons.person_remove),
  //                 title: const Text('Remove from Meeting'),
  //                 onTap: () {
  //                   Navigator.pop(context);
  //                   // Remove user logic would go here
  //                 },
  //               ),
  //               if (_isSpeakerFocusEnabled) ...[
  //                 ListTile(
  //                   leading: const Icon(Icons.fullscreen),
  //                   title: const Text('Focus on this Speaker'),
  //                   onTap: () {
  //                     Navigator.pop(context);
  //                     _focusOnUser(uid);
  //                   },
  //                 ),
  //               ],
  //               ListTile(
  //                 leading: const Icon(Icons.meeting_room),
  //                 title: const Text('Invite to Private Room'),
  //                 onTap: () {
  //                   Navigator.pop(context);
  //                   // Private room invitation logic would go here
  //                   // In a full implementation, this would create a new channel
  //                   // and send an invitation to the user
  //                   _agoraService.inviteToPrivateRoom(
  //                     uid,
  //                     'private_${widget.channelName}_$uid',
  //                   );
  //                 },
  //               ),
  //             ],
  //           ),
  //           actions: [
  //             TextButton(
  //               onPressed: () => Navigator.pop(context),
  //               child: const Text('Cancel'),
  //             ),
  //           ],
  //         ),
  //   );
  // }

  void _showPendingRequestsDialog(MeetingController controller) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Pending Join Requests'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Meeting Id  : ${widget.meetingId}'),
                _pendingRequests.isEmpty
                    ? const Center(child: Text('No pending requests'))
                    : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _pendingRequests.length,
                      itemBuilder: (context, index) {
                        final request = _pendingRequests[index];
                        return ListTile(
                          title: Text(request['name']),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.check,
                                  color: Colors.green,
                                ),
                                onPressed: () {
                                  Navigator.pop(context);
                                  controller.approveJoinRequest(
                                    request['userId'],
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.red,
                                ),
                                onPressed: () {
                                  Navigator.pop(context);
                                  controller.rejectJoinRequest(
                                    request['userId'],
                                  );
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }
}
