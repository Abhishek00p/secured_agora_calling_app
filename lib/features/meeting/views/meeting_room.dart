// import 'dart:async';
// import 'package:agora_rtc_engine/agora_rtc_engine.dart';
// import 'package:flutter/material.dart';
// import 'package:get/get_state_manager/src/simple/get_state.dart';
// import 'package:get/instance_manager.dart';
// import 'package:get/route_manager.dart';
// import 'package:secured_calling/app_tost_util.dart';
// import 'package:secured_calling/core/extensions/app_int_extension.dart';
// import 'package:secured_calling/core/extensions/app_string_extension.dart';
// import 'package:secured_calling/core/routes/app_router.dart';
// import 'package:secured_calling/core/services/app_firebase_service.dart';
// import 'package:secured_calling/core/services/app_local_storage.dart';
// import 'package:secured_calling/core/theme/app_theme.dart';
// import 'package:secured_calling/features/auth/views/login_register_controller.dart';
// import 'package:secured_calling/features/meeting/services/agora_service.dart';
// import 'package:secured_calling/features/meeting/services/agora_service_controller.dart';
// import 'package:secured_calling/features/meeting/views/live_meeting_controller.dart';

// class MeetingRoom extends StatefulWidget {
//   final String channelName;
//   final bool isHost;
//   final String meetingId;
//   const MeetingRoom({
//     required this.channelName,
//     this.isHost = false,
//     super.key,
//     required this.meetingId,
//   });

//   @override
//   State<MeetingRoom> createState() => _MeetingRoomState();
// }

// class _MeetingRoomState extends State<MeetingRoom> {
//   final AgoraService _agoraService = AgoraService();
//   final AppFirebaseService _firebaseService = AppFirebaseService.instance;

//   // UI States
//   bool _isLoading = true;
//   bool _isMuted = false;
//   bool _isVideoEnabled = true;
//   bool _isScreenSharing = false;
//   bool _isSettingsOpen = false;
//   bool _isChatOpen = false;
//   bool _isParticipantListOpen = false;
//   bool _isRecording = false;
//   bool _isSpeakerFocusEnabled = false;
//   bool _isAudioOnlyMode = true;
//   int? _focusedUserId;

//   // Meeting info
//   String? _meetingId;
//   Map<String, dynamic>? _meetingData;
//   List<Map<String, dynamic>> _pendingRequests = [];

//   // Free trial countdown
//   int? _remainingSeconds;
//   bool _showExtendOption = false;

//   // Chat
//   final TextEditingController _chatController = TextEditingController();
//   final List<Map<String, dynamic>> _chatMessages = [];

//   // Participants control
//   final Map<int, bool> _remoteUserAudioStates = {}; // uid -> isEnabled
//   final Map<int, bool> _remoteUserVideoStates = {}; // uid -> isEnabled
// final agoraServiceController = Get.put(AgoraController()
//   );  @override
//   void initState() {
//     super.initState();
//     _initializeAgora();
//     if (widget.isHost) {
//       _getMeetingData();
//     }
//   }

//   Future<void> approveJoinRequest(String userId) async {
//     try {
//       await _firebaseService.approveMeetingJoinRequest(
//         widget.meetingId,
//         userId,
//       );
//       await fetchPendingRequests();
//     } catch (e) {
//       AppLogger.print("error approving request: $e");
//     }
//   }

//   Future<void> fetchPendingRequests() async {
//     try {
//       final meetingDoc =
//           await _firebaseService.meetingsCollection.doc(widget.meetingId).get();
//       final meetingData = meetingDoc.data() as Map<String, dynamic>;
//       final pendingUserIds = meetingData['pendingApprovals'] as List<dynamic>;

//       final pendingRequests = <Map<String, dynamic>>[];

//       for (final userId in pendingUserIds) {
//         final userDoc = await _firebaseService.getUserData(userId as String);
//         final userData = userDoc.data() as Map<String, dynamic>?;
//         if (userData != null) {
//           pendingRequests.add({
//             'userId': userId,
//             'name': userData['name'] ?? 'Unknown User',
//           });
//         }
//       }

//       _pendingRequests = pendingRequests;
//     } catch (e) {
//       AppLogger.print("failed to fetch pending requests: $e");
//     }
//   }

//   Future<void> _getMeetingData() async {
//     try {
//       final querySnapshot = await _firebaseService.searchMeetingByChannelName(
//         widget.channelName,
//       );
//       if (querySnapshot.docs.isNotEmpty) {
//         setState(() {
//           _meetingId = querySnapshot.docs.first.id;
//           _meetingData =
//               querySnapshot.docs.first.data() as Map<String, dynamic>;
//         });
//       }
//     } catch (e) {
//       AppToastUtil.showErrorToast(context, 'Error loading meeting data: $e');
//     }
//   }

//   Future<void> _initializeAgora() async {
//     try {
//       await _agoraService.initialize(
//         // onUserJoined: _onUserJoined,
//         // onUserOffline: _onUserOffline,
//         // onUserAudioStateChanged: _onUserAudioStateChanged,
//         // onUserVideoStateChanged: _onUserVideoStateChanged,
//         // onMeetingEnded: _onMeetingEnded,
//         // onFreeTrialCountdown: _onFreeTrialCountdown,
//       );

//       await agoraServiceController.joinChannel(
//          'testing',
//       );

//       setState(() {
//         _isLoading = false;
//       });
//       if (_agoraService.isInitialized) {
//         AppToastUtil.showSuccessToast(
//           context,
//           'Agora intialized , lets go......',
//         );
//         AppFirebaseService.instance.startMeeting(widget.meetingId);
//       } else {
//         AppToastUtil.showErrorToast(
//           context,
//           'Agora not intialized , dont go......',
//         );
//       }
//     } catch (e) {
//       AppLogger.print("error in init agora :$e");
//       AppToastUtil.showErrorToast(context, 'Error initializing video call: $e');
//       setState(() {
//         _isLoading = false;
//       });
//     }
//   }

//   // Agora callbacks
//   void _onUserJoined(int uid) {
// meeting
//     setState(() {
//       _remoteUserAudioStates[uid] = true;
//       _remoteUserVideoStates[uid] = true;
//     });
//   }

//   void _onUserOffline(int uid) {
//     ref.read(remoteUsersProvider.notifier).removeUser(uid);
//     setState(() {
//       _remoteUserAudioStates.remove(uid);
//       _remoteUserVideoStates.remove(uid);
//       if (_focusedUserId == uid) {
//         _focusedUserId = null;
//       }
//     });
//   }

//   void _onUserAudioStateChanged(int uid, bool enabled) {
//     setState(() {
//       _remoteUserAudioStates[uid] = enabled;
//     });
//   }

//   void _onUserVideoStateChanged(int uid, bool enabled) {
//     setState(() {
//       _remoteUserVideoStates[uid] = enabled;
//     });
//   }

//   void _onMeetingEnded() {
//     // Navigator.pop(context);
//   }

//   void _onFreeTrialCountdown(int remainingSeconds) {
//     setState(() {
//       _remainingSeconds = remainingSeconds;
//       // Show extend option when 1 minute remaining
//       _showExtendOption = remainingSeconds <= 60;
//     });
//   }

//   // UI Actions
//   Future<void> _toggleMute() async {
//     await _agoraService.toggleMute();
//     setState(() {
//       _isMuted = !_isMuted;
//     });
//   }

//   Future<void> _toggleVideo() async {
//     await _agoraService.toggleVideo();
//     setState(() {
//       _isVideoEnabled = !_isVideoEnabled;
//     });
//   }

//   Future<void> _toggleAudioOnlyMode() async {
//     await _agoraService.toggleAudioOnlyMode();
//     setState(() {
//       _isAudioOnlyMode = !_isAudioOnlyMode;
//       if (_isAudioOnlyMode) {
//         // Audio-only mode forces video off
//         _isVideoEnabled = false;
//       }
//     });
//     ref.read(isAudioOnlyModeProvider.notifier).state = _isAudioOnlyMode;
//   }

//   Future<void> _toggleScreenSharing() async {
//     try {
//       if (_isScreenSharing) {
//         await _agoraService.stopScreenSharing();
//       } else {
//         await _agoraService.startScreenSharing();
//       }
//       setState(() {
//         _isScreenSharing = !_isScreenSharing;
//       });
//     } catch (e) {
//       AppToastUtil.showErrorToast(context, 'Error toggling screen sharing: $e');
//     }
//   }

//   Future<void> _toggleRecording() async {
//     try {
//       if (_isRecording) {
//         await _agoraService.stopRecording();
//       } else {
//         await _agoraService.startRecording();
//       }
//       setState(() {
//         _isRecording = !_isRecording;
//       });
//     } catch (e) {
//       AppToastUtil.showErrorToast(context, 'Error toggling recording: $e');
//     }
//   }

//   void _toggleSpeakerFocus() {
//     setState(() {
//       _isSpeakerFocusEnabled = !_isSpeakerFocusEnabled;
//       if (!_isSpeakerFocusEnabled) {
//         _focusedUserId = null;
//       }
//     });
//   }

//   void _focusOnUser(int uid) {
//     if (!_isSpeakerFocusEnabled) return;

//     setState(() {
//       _focusedUserId = _focusedUserId == uid ? null : uid;
//     });
//     _agoraService.setFocusedUser(_focusedUserId);
//   }

//   Future<void> _muteRemoteUser(int uid) async {
//     await _agoraService.toggleRemoteAudio(uid, true); // true = mute
//   }

//   Future<void> _extendMeeting() async {
//     if (_meetingId == null) return;

//     try {
//       // Extend meeting by 15 minutes
//       await _firebaseService.extendMeeting(_meetingId!, 15);

//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Meeting extended by 15 minutes')),
//       );
//     } catch (e) {
//       AppToastUtil.showErrorToast(context, 'Error extending meeting: $e');
//     }
//   }

//   void _sendChatMessage() {
//     final message = _chatController.text.trim();
//     if (message.isEmpty) return;

//     // In a full implementation, this would send to Firebase
//     // For demo purposes, we're just adding it locally
//     setState(() {
//       _chatMessages.add({
//         'userId': _firebaseService.currentUser!.uid,
//         'name': _firebaseService.currentUser!.displayName ?? 'You',
//         'message': message,
//         'timestamp': DateTime.now(),
//         'isCurrentUser': true,
//       });
//     });

//     _chatController.clear();
//   }

//   @override
//   void dispose() {
//     _chatController.dispose();
//     _agoraService.destroy();
//     super.dispose();
//   }

//   void endMeeting(MeetingController controller) async {
//     await controller.endMeeting(
//       leaveAgora: () async {
//         _agoraService.leaveChannel();
//       },
//       meetingId: widget.meetingId,
//     );
//     if (mounted) {
//       AppLogger.print("popping context from meeting room.....");
//       Navigator.pop(context);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {

//     return PopScope(
//       canPop: true,
//       onPopInvokedWithResult: (didPop, _) async {
//         // endMeeting(controller);
//       },
//       child: Scaffold(
//         appBar: AppBar(
//           title: Column(
//             crossAxisAlignment: CrossAxisAlignment.center,
//             children: [
//               const Text('Meeting Room'),
//               if (_remainingSeconds != null) ...[
//                 Text(
//                   'Time remaining: ${_remainingSeconds!.formatDuration}',
//                   style: const TextStyle(fontSize: 12, color: Colors.red),
//                 ),
//               ],
//             ],
//           ),
//           //
//         ),
//         bottomNavigationBar: Row(
//           mainAxisAlignment: MainAxisAlignment.spaceAround,
//           children: [
//             _buildControlBar(),
//             _buildEndCallButton(() async {
//               await controller.endMeeting(
//                 leaveAgora: () async {
//                   _agoraService.leaveChannel();
//                 },
//                 meetingId: widget.meetingId,
//               );

//               if (mounted) {
//                 AppLogger.print("popping context from meeting room.....");
//                 Navigator.pop(context);
//               }
//             }),
//           ],
//         ),

//         body: GetBuilder<MeetingController>(
//           builder: (meetingController) {
//             return SafeArea(
//               child: Column(
//                 children: [
//                   _isLoading
//                       ? const Center(child: CircularProgressIndicator())
//                       : Expanded(
//                         child: Stack(
//                           children: [
//                             _buildVideoGrid([]),//TODO: implement dynamic
//                             _buildLocalVideo(),

//                             // Bottom Control Bar
//                             Positioned(
//                               right: 10,
//                               top: 10,
//                               child: IconButton(
//                                 onPressed: () async {
//                                   await fetchPendingRequests();
//                                   _showPendingRequestsDialog(meetingController);
//                                 },
//                                 icon: Icon(Icons.settings),
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                 ],
//               ),
//             );
//           }
//         ),
//       ),
//     );
//   }

//   Widget _buildVideoGrid(List<int> remoteUsers) {

//     final int totalUsers = remoteUsers.length;
//     if (totalUsers == 0) {
//       return const Center(child: Text('Waiting for others to join...'));
//     }

//     int crossAxisCount = 2;
//     if (totalUsers > 4) crossAxisCount = 3;
//     if (totalUsers > 9) crossAxisCount = 4;

//     return Expanded(
//       child: GridView.builder(
//         shrinkWrap: true,
//         gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
//           crossAxisCount: crossAxisCount,
//           childAspectRatio: 16 / 9,
//           crossAxisSpacing: 4,
//           mainAxisSpacing: 4,
//         ),
//         itemCount: totalUsers,
//         itemBuilder: (context, index) {
//           final remoteUid = remoteUsers[index];
//           return GestureDetector(
//             onTap: () => _focusOnUser(remoteUid),
//             child: Container(
//               color: Colors.black,
//               child: Stack(
//                 children: [
//                   Center(
//                     child:
//                         _remoteUserVideoStates[remoteUid] == false
//                             ? Container(
//                               color: Colors.black54,
//                               child: const Center(
//                                 child: Icon(
//                                   Icons.videocam_off,
//                                   color: Colors.white,
//                                   size: 40,
//                                 ),
//                               ),
//                             )
//                             : AgoraVideoView(
//                               controller: VideoViewController.remote(
//                                 rtcEngine: _agoraService.engine!,
//                                 canvas: VideoCanvas(uid: remoteUid),
//                                 connection: RtcConnection(
//                                   channelId: widget.channelName,
//                                 ),
//                               ),
//                             ),
//                   ),
//                   Positioned(
//                     bottom: 8,
//                     left: 8,
//                     child: Container(
//                       padding: const EdgeInsets.symmetric(
//                         horizontal: 8,
//                         vertical: 4,
//                       ),
//                       decoration: BoxDecoration(
//                         color: Colors.black54,
//                         borderRadius: BorderRadius.circular(4),
//                       ),
//                       child: Row(
//                         mainAxisSize: MainAxisSize.min,
//                         children: [
//                           if (_remoteUserAudioStates[remoteUid] == false) ...[
//                             const Icon(
//                               Icons.mic_off,
//                               color: Colors.white,
//                               size: 14,
//                             ),
//                             const SizedBox(width: 4),
//                           ],
//                           Text(
//                             'User $remoteUid',
//                             style: const TextStyle(
//                               color: Colors.white,
//                               fontSize: 12,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//                   if (widget.isHost) ...[
//                     Positioned(
//                       top: 8,
//                       right: 8,
//                       child: Row(
//                         mainAxisSize: MainAxisSize.min,
//                         children: [
//                           // Mute remote user
//                           GestureDetector(
//                             onTap: () => _muteRemoteUser(remoteUid),
//                             child: Container(
//                               padding: const EdgeInsets.all(4),
//                               decoration: BoxDecoration(
//                                 color: Colors.red,
//                                 borderRadius: BorderRadius.circular(4),
//                               ),
//                               child: const Icon(
//                                 Icons.mic_off,
//                                 color: Colors.white,
//                                 size: 16,
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ],
//                   if (_isSpeakerFocusEnabled) ...[
//                     Positioned.fill(
//                       child: GestureDetector(
//                         onTap: () => _focusOnUser(remoteUid),
//                         child: Container(
//                           decoration: BoxDecoration(
//                             border: Border.all(
//                               color: AppTheme.primaryColor,
//                               width: 2,
//                             ),
//                           ),
//                           child: const Center(
//                             child: Icon(
//                               Icons.fullscreen,
//                               color: Colors.white,
//                               size: 32,
//                             ),
//                           ),
//                         ),
//                       ),
//                     ),
//                   ],
//                 ],
//               ),
//             ),
//           );
//         },
//       ),
//     );
//   }

//   Widget _buildLocalVideo() {
//     return Positioned(
//       left: 16,
//       bottom: 20,
//       width: 120,
//       height: 160,
//       child: Container(
//         decoration: BoxDecoration(
//           borderRadius: BorderRadius.circular(8),
//           border: Border.all(color: Colors.white),
//           color: Colors.black,
//         ),
//         child: ClipRRect(
//           borderRadius: BorderRadius.circular(8),
//           child: Stack(
//             children: [
//               Center(
//                 child:
//                     !_isMuted?
//                     Text(AppLocalStorage.getUserDetails().name.initalLetter)
//                         // ? AgoraVideoView(
//                         //   controller: VideoViewController(
//                         //     rtcEngine: _agoraService.engine!,
//                         //     canvas: const VideoCanvas(uid: 0),
//                         //   ),
//                         // )
//                         : Container(
//                           color: Colors.black54,
//                           child: const Center(
//                             child: Icon(
//                               Icons.spatial_audio_off_outlined,
//                               color: Colors.white,
//                               size: 40,
//                             ),
//                           ),
//                         ),
//               ),
//               Positioned(
//                 bottom: 8,
//                 left: 8,
//                 child: Container(
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 8,
//                     vertical: 4,
//                   ),
//                   decoration: BoxDecoration(
//                     color: Colors.black54,
//                     borderRadius: BorderRadius.circular(4),
//                   ),
//                   child: Row(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       if (_isMuted) ...[
//                         const Icon(
//                           Icons.mic_off,
//                           color: Colors.white,
//                           size: 14,
//                         ),
//                         const SizedBox(width: 4),
//                       ],
//                       const Text(
//                         'You',
//                         style: TextStyle(color: Colors.white, fontSize: 12),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildEndCallButton(VoidCallback onTap) {
//     return InkWell(
//       onTap: onTap,
//       child: Container(
//         padding: EdgeInsets.symmetric(horizontal: 16),
//         height: 50,
//         color: Colors.red,
//         child: Row(
//           mainAxisSize: MainAxisSize.max,
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Text('End Call'),
//             SizedBox(width: 10),
//             Icon(Icons.call_end),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildControlBar() {
//     return SizedBox(
//       height: 70,
//       child: SingleChildScrollView(
//         scrollDirection: Axis.horizontal,
//         child: Row(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             _buildControlButton(
//               icon: _isMuted ? Icons.mic_off : Icons.mic,
//               label: _isMuted ? 'Unmute' : 'Mute',
//               color: _isMuted ? Colors.red : Colors.white,
//               onPressed: _toggleMute,
//             ),
//             _buildControlButton(
//               icon: _isVideoEnabled ? Icons.videocam : Icons.videocam_off,
//               label: _isVideoEnabled ? 'Stop Video' : 'Start Video',
//               color: _isVideoEnabled ? Colors.white : Colors.red,
//               onPressed: _toggleVideo,
//             ),

//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildControlButton({
//     required IconData icon,
//     required String label,
//     required Color color,
//     required VoidCallback onPressed,
//     bool isEndCall = false,
//   }) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 8.0),
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Container(
//             width: 50,
//             height: 50,
//             decoration: BoxDecoration(
//               color: isEndCall ? Colors.red : Colors.black54,
//               borderRadius: BorderRadius.circular(25),
//             ),
//             child: IconButton(
//               icon: Icon(icon),
//               color: color,
//               onPressed: onPressed,
//             ),
//           ),
//           const SizedBox(height: 4),
//           Text(
//             label,
//             style: const TextStyle(fontSize: 12, color: Colors.white),
//           ),
//         ],
//       ),
//     );
//   }

//   void _showPendingRequestsDialog(MeetingController controller) {
//     showDialog(
//       context: context,
//       builder:
//           (context) => AlertDialog(
//             title: const Text('Pending Join Requests'),
//             content: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 SelectableText('Meeting Id  : ${widget.meetingId}'),
//                 _pendingRequests.isEmpty
//                     ? const Center(child: Text('No pending requests'))
//                     : ListView.builder(
//                       shrinkWrap: true,
//                       itemCount: _pendingRequests.length,
//                       itemBuilder: (context, index) {
//                         final request = _pendingRequests[index];
//                         return ListTile(
//                           title: Text(request['name']),
//                           trailing: Row(
//                             mainAxisSize: MainAxisSize.min,
//                             children: [
//                               IconButton(
//                                 icon: const Icon(
//                                   Icons.check,
//                                   color: Colors.green,
//                                 ),
//                                 onPressed: () {
//                                   Navigator.pop(context);
//                                   approveJoinRequest(request['userId']);
//                                 },
//                               ),
//                               IconButton(
//                                 icon: const Icon(
//                                   Icons.close,
//                                   color: Colors.red,
//                                 ),
//                                 onPressed: () {
//                                   Navigator.pop(context);
//                                   controller.rejectJoinRequest(
//                                     request['userId'],
//                                   );
//                                 },
//                               ),
//                             ],
//                           ),
//                         );
//                       },
//                     ),
//               ],
//             ),
//             actions: [
//               TextButton(
//                 onPressed: () => Navigator.pop(context),
//                 child: const Text('Close'),
//               ),
//             ],
//           ),
//     );
//   }
// }
