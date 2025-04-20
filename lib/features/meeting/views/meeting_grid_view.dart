// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:agora_rtc_engine/agora_rtc_engine.dart';
// import 'package:secured_calling/core/theme/app_theme.dart';
// import 'package:secured_calling/features/meeting/views/live_meeting_controller.dart';

// class VideoGrid extends ConsumerWidget {
//   final String channelName;
//   final bool isHost;
//   const VideoGrid({
//     super.key,
//     required this.isHost,
//     required this.channelName,
//   });

//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     final controller = ref.watch(meetingControllerProvider((isHost:isHost,meetingId:channelName) ).notifier);
//     final state = ref.watch(meetingControllerProvider((isHost:isHost,meetingId:channelName )));

//     final remoteUsers = state.remoteUsers;
//     final isSpeakerFocusEnabled = state.isSpeakerFocusEnabled;
//     final focusedUserId = state.focusedUserId;
//     final remoteUserAudioStates = state.remoteUserAudioStates;
//     final remoteUserVideoStates = state.remoteUserVideoStates;
//     final isHost = isHost;

//     if (isSpeakerFocusEnabled && focusedUserId != null) {
//       return Center(
//         child: AspectRatio(
//           aspectRatio: 16 / 9,
//           child: Container(
//             color: Colors.black,
//             child: Stack(
//               children: [
//                 Center(
//                   child: AgoraVideoView(
//                     controller: VideoViewController.remote(
//                       rtcEngine: controller.engine,
//                       canvas: VideoCanvas(uid: focusedUserId),
//                       connection: RtcConnection(channelId: channelName),
//                     ),
//                   ),
//                 ),
//                 Positioned(
//                   bottom: 8,
//                   right: 8,
//                   child: Container(
//                     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                     decoration: BoxDecoration(
//                       color: Colors.black54,
//                       borderRadius: BorderRadius.circular(4),
//                     ),
//                     child: Row(
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         if (remoteUserAudioStates[focusedUserId] == false) ...[
//                           const Icon(Icons.mic_off, color: Colors.white, size: 16),
//                           const SizedBox(width: 4),
//                         ],
//                         const Text(
//                           'Speaker View',
//                           style: TextStyle(color: Colors.white, fontSize: 12),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       );
//     }

//     if (remoteUsers.isEmpty) {
//       return const Center(child: Text('Waiting for others to join...'));
//     }

//     int crossAxisCount = 2;
//     if (remoteUsers.length > 4) crossAxisCount = 3;
//     if (remoteUsers.length > 9) crossAxisCount = 4;

//     return GridView.builder(
//       padding: const EdgeInsets.all(4),
//       gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
//         crossAxisCount: crossAxisCount,
//         childAspectRatio: 16 / 9,
//         crossAxisSpacing: 4,
//         mainAxisSpacing: 4,
//       ),
//       itemCount: remoteUsers.length,
//       itemBuilder: (context, index) {
//         final remoteUid = remoteUsers[index];
//         final isVideoOn = remoteUserVideoStates[remoteUid] ?? true;
//         final isAudioOn = remoteUserAudioStates[remoteUid] ?? true;

//         return GestureDetector(
//           onTap: () => controller.focusOnUser(remoteUid),
//           child: Container(
//             color: Colors.black,
//             child: Stack(
//               children: [
//                 Center(
//                   child: !isVideoOn
//                       ? Container(
//                           color: Colors.black54,
//                           child: const Center(
//                             child: Icon(Icons.videocam_off, color: Colors.white, size: 40),
//                           ),
//                         )
//                       : AgoraVideoView(
//                           controller: VideoViewController.remote(
//                             rtcEngine: controller.engine,
//                             canvas: VideoCanvas(uid: remoteUid),
//                             connection: RtcConnection(channelId: channelName),
//                           ),
//                         ),
//                 ),
//                 Positioned(
//                   bottom: 8,
//                   left: 8,
//                   child: Container(
//                     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                     decoration: BoxDecoration(
//                       color: Colors.black54,
//                       borderRadius: BorderRadius.circular(4),
//                     ),
//                     child: Row(
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         if (!isAudioOn) ...[
//                           const Icon(Icons.mic_off, color: Colors.white, size: 14),
//                           const SizedBox(width: 4),
//                         ],
//                         Text(
//                           'User $remoteUid',
//                           style: const TextStyle(color: Colors.white, fontSize: 12),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//                 if (isHost) ...[
//                   Positioned(
//                     top: 8,
//                     right: 8,
//                     child: GestureDetector(
//                       onTap: () => controller.muteRemoteUser(remoteUid),
//                       child: Container(
//                         padding: const EdgeInsets.all(4),
//                         decoration: BoxDecoration(
//                           color: Colors.red,
//                           borderRadius: BorderRadius.circular(4),
//                         ),
//                         child: const Icon(Icons.mic_off, color: Colors.white, size: 16),
//                       ),
//                     ),
//                   ),
//                 ],
//                 if (isSpeakerFocusEnabled) ...[
//                   Positioned.fill(
//                     child: GestureDetector(
//                       onTap: () => controller.focusOnUser(remoteUid),
//                       child: Container(
//                         decoration: BoxDecoration(
//                           border: Border.all(color: AppTheme.primaryColor, width: 2),
//                         ),
//                         child: const Center(
//                           child: Icon(Icons.fullscreen, color: Colors.white, size: 32),
//                         ),
//                       ),
//                     ),
//                   ),
//                 ],
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }
// }
