// import 'dart:async';

// import 'package:agora_rtc_engine/agora_rtc_engine.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// // import 'package:secured_calling/core/services/app_firebase_service.dart';
// // import 'package:secured_calling/core/theme/app_theme.dart';
// // import 'package:secured_calling/features/meeting/services/agora_service.dart';

// class MeetingRoom extends ConsumerStatefulWidget {
//   final String channelName;
//   final bool isHost;

//   const MeetingRoom({
//     required this.channelName,
//     this.isHost = false,
//     super.key,
//   });

//   @override
//   ConsumerState<MeetingRoom> createState() => _MeetingRoomState();
// }

// class _MeetingRoomState extends ConsumerState<MeetingRoom> {
//   // TODO: Uncomment when AgoraService is implemented
//   // final AgoraService _agoraService = AgoraService();
//   // final AppFirebaseService _firebaseService = AppFirebaseService.instance;

//   // Basic UI States
//   bool _isLoading = true;
//   bool _isMuted = false;
//   bool _isVideoEnabled = true;
  
//   // TODO: Uncomment when remote user functionality is implemented
//   // List<int> remoteUsers = []; // Mock remote users for now
//   // final Map<int, bool> _remoteUserAudioStates = {}; // uid -> isEnabled
//   // final Map<int, bool> _remoteUserVideoStates = {}; // uid -> isEnabled

//   @override
//   void initState() {
//     super.initState();
//     _initializeAgora();
//   }

//   Future<void> _initializeAgora() async {
//     try {
//       // TODO: Implement actual Agora initialization
//       /*
//       await _agoraService.initialize(
//         onUserJoined: _onUserJoined,
//         onUserOffline: _onUserOffline,
//         onUserAudioStateChanged: _onUserAudioStateChanged,
//         onUserVideoStateChanged: _onUserVideoStateChanged,
//       );

//       await _agoraService.joinChannel(
//         channelName: widget.channelName,
//       );
//       */

//       // Mock initialization for now
//       await Future.delayed(const Duration(seconds: 1));

//       setState(() {
//         _isLoading = false;
//       });
//     } catch (e) {
//       _showError('Error initializing video call: $e');
//       setState(() {
//         _isLoading = false;
//       });
//     }
//   }

//   /*
//   // Agora callbacks - to be implemented
//   void _onUserJoined(int uid) {
//     ref.read(remoteUsersProvider.notifier).addUser(uid);
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
//   */

//   // Basic UI Actions
//   Future<void> _toggleMute() async {
//     // TODO: Implement actual mute functionality
//     // await _agoraService.toggleMute();
//     setState(() {
//       _isMuted = !_isMuted;
//     });
//   }

//   Future<void> _toggleVideo() async {
//     // TODO: Implement actual video toggle functionality
//     // await _agoraService.toggleVideo();
//     setState(() {
//       _isVideoEnabled = !_isVideoEnabled;
//     });
//   }

//   Future<void> _endMeeting() async {
//     // TODO: Implement actual meeting end functionality
//     /*
//     if (_meetingId != null && widget.isHost) {
//       try {
//         await _firebaseService.endMeeting(_meetingId!);
//       } catch (e) {
//         debugPrint('Error ending meeting: $e');
//       }
//     }

//     await _agoraService.leaveChannel();
//     */
//     if (mounted) {
//       Navigator.pop(context);
//     }
//   }

//   void _showError(String message) {
//     if (mounted) {
//       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
//     }
//   }

//   @override
//   void dispose() {
//     // TODO: Implement actual cleanup
//     // _agoraService.destroy();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     // TODO: Replace with actual remote users provider
//     // final remoteUsers = ref.watch(remoteUsersProvider);
//     final remoteUsers = []; // Empty list for now

//     return WillPopScope(
//       onWillPop: () async {
//         await _endMeeting();
//         return true;
//       },
//       child: Scaffold(
//         appBar: AppBar(
//           title: const Text('Meeting Room'),
//           leading: IconButton(
//             icon: const Icon(Icons.arrow_back),
//             onPressed: _endMeeting,
//           ),
//         ),
//         body: _isLoading
//             ? const Center(child: CircularProgressIndicator())
//             : Stack(
//                 children: [
//                   // Main Video Grid
//                   _buildVideoGrid(remoteUsers),

//                   // Bottom Control Bar
//                   _buildControlBar(),
//                   _buildEndCallButton(),

//                   // Floating Local Video
//                   _buildLocalVideo(),
//                 ],
//               ),
//       ),
//     );
//   }

//   Widget _buildVideoGrid(List<int> remoteUsers) {
//     // For demo purposes - show mock remote users
//     if (remoteUsers.isEmpty) {
//       return const Center(child: Text('Waiting for others to join...'));
//     }

//     return GridView.builder(
//       gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//         crossAxisCount: 2, // Simple 2-column grid for now
//         childAspectRatio: 16 / 9,
//         crossAxisSpacing: 4,
//         mainAxisSpacing: 4,
//       ),
//       itemCount: remoteUsers.length,
//       itemBuilder: (context, index) {
//         final remoteUid = remoteUsers[index];
//         return Container(
//           color: Colors.black,
//           child: Stack(
//             children: [
//               // TODO: Replace with actual Agora video view
//               /*
//               Center(
//                 child: _remoteUserVideoStates[remoteUid] == false
//                     ? Container(
//                         color: Colors.black54,
//                         child: const Center(
//                           child: Icon(
//                             Icons.videocam_off,
//                             color: Colors.white,
//                             size: 40,
//                           ),
//                         ),
//                       )
//                     : AgoraVideoView(
//                         controller: VideoViewController.remote(
//                           rtcEngine: _agoraService.engine!,
//                           canvas: VideoCanvas(uid: remoteUid),
//                           connection: RtcConnection(channelId: widget.channelName),
//                         ),
//                       ),
//               ),
//               */
//               Center(
//                 child: Container(
//                   color: Colors.grey[800],
//                   child: Center(
//                     child: Text(
//                       'User $remoteUid',
//                       style: const TextStyle(color: Colors.white),
//                     ),
//                   ),
//                 ),
//               ),
//               Positioned(
//                 bottom: 8,
//                 left: 8,
//                 child: Container(
//                   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                   decoration: BoxDecoration(
//                     color: Colors.black54,
//                     borderRadius: BorderRadius.circular(4),
//                   child: Row(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       // TODO: Show actual mute state
//                       /*
//                       if (_remoteUserAudioStates[remoteUid] == false) ...[
//                         const Icon(Icons.mic_off, color: Colors.white, size: 14),
//                         const SizedBox(width: 4),
//                       ],
//                       */
//                       Text(
//                         'User $remoteUid',
//                         style: const TextStyle(color: Colors.white, fontSize: 12),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         );
//       },
//     );
//   }

//   Widget _buildLocalVideo() {
//     return Positioned(
//       left: 16,
//       bottom: 150,
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
//               // TODO: Replace with actual Agora video view
//               /*
//               Center(
//                 child: _isVideoEnabled
//                     ? AgoraVideoView(
//                         controller: VideoViewController(
//                           rtcEngine: _agoraService.engine!,
//                           canvas: const VideoCanvas(uid: 0),
//                         ),
//                       )
//                     : Container(
//                         color: Colors.black54,
//                         child: const Center(
//                           child: Icon(
//                             Icons.videocam_off,
//                             color: Colors.white,
//                             size: 40,
//                           ),
//                         ),
//                       ),
//               ),
//               */
//               Center(
//                 child: Container(
//                   color: Colors.grey[800],
//                   child: const Center(
//                     child: Text(
//                       'You',
//                       style: TextStyle(color: Colors.white),
//                     ),
//                   ),
//                 ),
//               ),
//               Positioned(
//                 bottom: 8,
//                 left: 8,
//                 child: Container(
//                   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                   decoration: BoxDecoration(
//                     color: Colors.black54,
//                     borderRadius: BorderRadius.circular(4),
//                   ),
//                   child: Row(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       if (_isMuted) ...[
//                         const Icon(Icons.mic_off, color: Colors.white, size: 14),
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

//   Widget _buildEndCallButton() {
//     return Positioned(
//       bottom: 16,
//       child: Container(
//         width: MediaQuery.sizeOf(context).width,
//         padding: const EdgeInsets.symmetric(horizontal: 16),
//         height: 50,
//         child: InkWell(
//           onTap: _endMeeting,
//           child: ColoredBox(
//             color: Colors.red,
//             child: Row(
//               mainAxisSize: MainAxisSize.max,
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 const Text('End Call', style: TextStyle(color: Colors.white)),
//                 const SizedBox(width: 10),
//                 const Icon(Icons.call_end, color: Colors.white),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildControlBar() {
//     return Positioned(
//       left: 0,
//       right: 0,
//       bottom: 80,
//       child: SafeArea(
//         child: SingleChildScrollView(
//           scrollDirection: Axis.horizontal,
//           child: Row(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               _buildControlButton(
//                 icon: _isMuted ? Icons.mic_off : Icons.mic,
//                 label: _isMuted ? 'Unmute' : 'Mute',
//                 color: _isMuted ? Colors.red : Colors.white,
//                 onPressed: _toggleMute,
//               ),
//               _buildControlButton(
//                 icon: _isVideoEnabled ? Icons.videocam : Icons.videocam_off,
//                 label: _isVideoEnabled ? 'Stop Video' : 'Start Video',
//                 color: _isVideoEnabled ? Colors.white : Colors.red,
//                 onPressed: _toggleVideo,
//               ),
//               /*
//               // TODO: Add these back when implemented
//               _buildControlButton(
//                 icon: Icons.screen_share,
//                 label: 'Share Screen',
//                 color: _isScreenSharing ? Colors.blue : Colors.white,
//                 onPressed: _toggleScreenSharing,
//               ),
//               if (widget.isHost) ...[
//                 _buildControlButton(
//                   icon: _isRecording
//                       ? Icons.fiber_manual_record
//                       : Icons.fiber_manual_record_outlined,
//                   label: _isRecording ? 'Stop Recording' : 'Record',
//                   color: _isRecording ? Colors.red : Colors.white,
//                   onPressed: _toggleRecording,
//                 ),
//               ],
//               */
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildControlButton({
//     required IconData icon,
//     required String label,
//     required Color color,
//     required VoidCallback onPressed,
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
//               color: Colors.black54,
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
// }

// /*
// // TODO: Implement these providers when needed
// final remoteUsersProvider = StateProvider<List<int>>((ref) => []);
// final isAudioOnlyModeProvider = StateProvider<bool>((ref) => false);
// */