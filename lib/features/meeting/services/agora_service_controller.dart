// // agora_controller.dart

// import 'package:agora_rtc_engine/agora_rtc_engine.dart';
// import 'package:agora_rtc_engine/src/agora_rtc_engine_ex.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/widgets.dart';
// import 'package:get/get.dart';
// import 'package:secured_calling/app_logger.dart';
// import 'package:secured_calling/app_tost_util.dart';
// import 'package:secured_calling/core/services/app_firebase_service.dart';
// import 'package:secured_calling/participant_model.dart';
// import 'agora_service.dart';

// class AgoraController extends GetxController {
//   final AgoraService _agoraService = AgoraService();

//   var isJoined = false.obs;
//   var isMuted = false.obs;
//   var isVideoEnabled = true.obs;
//   var isScreenSharing = false.obs;
//   List<ParticipantModel> participants = [];
//   String currentSpeaker = '';

//   Future<void> initializeAgora({
//     required BuildContext context,
//   }) async {
//     await _agoraService.initialize(rtcEngineEventHandler:_rtcEngineEventHandler(context));
//   }

//   void onActiveSpeaker(RtcConnection conn, int userId) {
//     currentSpeaker = '$userId';
//     participants =
//         participants
//             .map((e) => e.userId == userId ? e.copyWith(isUserMuted: false) : e.copyWith(isUserMuted: true))
//             .toList();
//     update();
//   }

//   Future<void> joinChannel({
//     String channelName = 'testing',
//     String token = '',
//   }) async {
//     final token = await AppFirebaseService.instance.getAgoraToken();
//     if (token.trim().isEmpty) {
//       AppToastUtil.showErrorToast(Get.context!, 'Token not found');
//       return;
//     }
//     await _agoraService.joinChannel(channelName: channelName, token: token);

//     isJoined.value = true;
//   }

//   Future<void> leaveChannel() async {
//     await _agoraService.leaveChannel();
//     isJoined.value = false;
//   }

//   Future<void> toggleMute() async {
//     isMuted.value = !isMuted.value;
//     await _agoraService.muteLocalAudio(isMuted.value);
//   }

//   Future<void> toggleVideo() async {
//     isVideoEnabled.value = !isVideoEnabled.value;
//     await _agoraService.muteLocalVideo(!isVideoEnabled.value);
//   }

//   Future<void> toggleScreenSharing() async {
//     if (isScreenSharing.value) {
//       await _agoraService.stopScreenSharing();
//     } else {
//       await _agoraService.startScreenSharing();
//     }
//     isScreenSharing.value = !isScreenSharing.value;
//   }

//   RtcEngineEventHandler _rtcEngineEventHandler(BuildContext context) {
//     return RtcEngineEventHandler(
//       onUserJoined: (connection, remoteUid, elapsed) {
//         addUser(remoteUid);
//       },
//       onUserOffline: (connection, remoteUid, reason) {
//         removeUser(remoteUid);
//       },
//       onUserMuteAudio: (connection, remoteUid, muted) {
//         updateMuteStatus(remoteUid, muted);
//       },
//       onActiveSpeaker: onActiveSpeaker,

//       onError: (ErrorCodeType error, String message) {
//         AppToastUtil.showErrorToast(context, '❌ Agora error: $error, message: $message');

//       },
//     );
//   }

//   Future<QueryDocumentSnapshot?> fetchUserDetailFromFirebase(int uid) async {
//     return await AppFirebaseService.instance.getUserDataWhereUserId(uid);
//   }

//   void addUser(int remoteUid) async {
//     if (!participants.contains(remoteUid)) {
//       final result = await fetchUserDetailFromFirebase(remoteUid);
//       if (result == null) {
//         return;
//       } else {
//         final userData = result.data() as Map<dynamic, dynamic>;
//         participants.add(
//           ParticipantModel(
//             userId: remoteUid,
//             firebaseUid: result.id,
//             name: userData['name'],
//             isUserMuted: true,
//           ),
//         );
//       }
//     }
//   }

//   void removeUser(int remoteUid) {
//     participants.removeWhere((e) => e.userId == remoteUid);
//   }

//   void updateMuteStatus(int remoteUid, bool muted) {
//        participants =
//         participants
//             .map((e) => e.userId == remoteUid ? e.copyWith(isUserMuted: muted) : e)
//             .toList();
//     update();
//   }
//   @override
//   void onClose() {
//     _agoraService.destroy();
//     super.onClose();
//   }
// }
