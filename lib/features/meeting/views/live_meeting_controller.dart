import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:secured_calling/app_logger.dart';
import 'package:secured_calling/app_tost_util.dart';
import 'package:secured_calling/core/models/meeting_model.dart';
import 'package:secured_calling/core/services/app_firebase_service.dart';
import 'package:secured_calling/core/services/app_local_storage.dart';
import 'package:secured_calling/features/meeting/services/agora_service.dart';
import 'package:secured_calling/participant_model.dart';
import 'package:secured_calling/warm_color_generator.dart';

class MeetingController extends GetxController {
  final AppFirebaseService _firebaseService = AppFirebaseService.instance;
  final AgoraService _agoraService = AgoraService();

  // State variables
  final isLoading = false.obs;
  final error = RxnString();

  final isMuted = false.obs;
  final isOnSpeaker = false.obs;
  final isJoined = false.obs;
  final isVideoEnabled = true.obs;
  final isScreenSharing = false.obs;

  List<ParticipantModel> participants = <ParticipantModel>[].obs;

  String meetingId = '';
  bool isHost = false;
  int remainingSeconds =
      AppLocalStorage.getUserDetails().isMember ? 25200 : 300;
  String currentSpeaker = '';

  bool get agoraInitialized => _agoraService.isInitialized;
  MeetingModel meetingModel = MeetingModel.empty();


  void startTimer() {
    try{
    _firebaseService.getMeetingData(meetingId).then((value) {
      meetingModel = MeetingModel.fromJson(value ??{});
      isHost = meetingModel.hostId == AppLocalStorage.getUserDetails().firebaseUserId;
    });

    Timer.periodic(Duration(seconds: 1), (timer) {
      if (remainingSeconds == 0) {
        timer.cancel();
      } else {
        remainingSeconds--;
      }
      update();
    });
    }catch(e){
      AppLogger.print('Error starting timer: $e');
    }
  }

  Future<void> initializeMeeting({
    required String meetingId,
    required bool isUserHost,
    required BuildContext context,
  }) async {
    this.meetingId = meetingId;
    isHost = isUserHost;

    try {
      await _agoraService.initialize(
        rtcEngineEventHandler: _rtcEngineEventHandler(context),
      );

      await joinChannel(channelName: 'testing');

      if (isUserHost) {
        _firebaseService.startMeeting(meetingId);
      }
    } catch (e) {
      AppLogger.print('Error initializing meeting: $e');
    }

    update();
  }

  Future<void> joinChannel({required String channelName}) async {
    try {
      final token = await _firebaseService.getAgoraToken();

      final currentUserId = AppLocalStorage.getUserDetails().userId;
      if (token.trim().isEmpty) {
        AppToastUtil.showErrorToast(Get.context!, 'Token not found');
        return;
      }
      AppLogger.print('agora token :$token');

      if (participants.length >= 45) {
        AppToastUtil.showErrorToast(
          Get.context!,
          'Meet Participants Limit Exceeds, you cannot join Meeting as of now',
        );
        return;
      }
      await _agoraService.joinChannel(
        channelName: channelName,
        token: token,
        userId: currentUserId,
      );
    } catch (e) {
      AppLogger.print('Error joining channel: $e');
      AppToastUtil.showErrorToast(Get.context!, 'Error joining channel: $e');
    }
  }

  Future<void> leaveChannel() async {
    await _agoraService.leaveChannel();
    isJoined.value = false;
  }

  Future<void> toggleMute() async {
    isMuted.toggle();
    await _agoraService.muteLocalAudio(isMuted.value);
    update();
  }

  Future<void> toggleSpeaker() async {
    isOnSpeaker.toggle();
    _agoraService.engine?.setEnableSpeakerphone(isOnSpeaker.value);
    update();
  }

  Future<void> toggleVideo() async {
    isVideoEnabled.toggle();
    await _agoraService.muteLocalVideo(!isVideoEnabled.value);
  }

  Future<void> toggleScreenSharing() async {
    if (isScreenSharing.value) {
      await _agoraService.stopScreenSharing();
    } else {
      await _agoraService.startScreenSharing();
    }
    isScreenSharing.toggle();
  }

  Future<void> endMeeting() async {
    await _agoraService.leaveChannel();
    if (meetingId.isNotEmpty) {
      await _firebaseService.endMeeting(meetingId);
    }
  }

  Stream<List<Map<String, dynamic>>> fetchPendingRequests() async* {
    yield* _firebaseService.meetingsCollection
        .doc(meetingId)
        .snapshots()
        .asyncMap((docSnapshot) async {
          final meetingData = docSnapshot.data() as Map<String, dynamic>?;
          if (meetingData == null) return [];

          final pendingUserIds =
              meetingData['pendingApprovals'] as List<dynamic>;
          final List<Map<String, dynamic>> requests = [];

          for (final userId in pendingUserIds) {
            final userDoc = await _firebaseService.getUserData(
              userId.toString(),
            );
            final userData = userDoc.data() as Map<String, dynamic>?;
            if (userData != null) {
              requests.add({
                'userId': userId,
                'name': userData['name'] ?? 'Unknown User',
              });
            }
          }

          return requests;
        });
  }

  Future<void> approveJoinRequest(int userId) async {
    try {
      await _firebaseService.approveMeetingJoinRequest(meetingId, userId);
    } catch (e) {
      AppLogger.print("error approving request: $e");
    }
  }

  Future<void> rejectJoinRequest(int userId) async {
    try {
      await _firebaseService.rejectMeetingJoinRequest(meetingId, userId);
    } catch (e) {
      error.value = 'Error rejecting request: $e';
    }
  }

  Future<void> addUser(int remoteUid) async {
    if (participants.any((e) => e.userId == remoteUid)) return;

    final result = await _firebaseService.getUserDataWhereUserId(remoteUid);

    if (result != null) {
      final userData = result.data() as Map<dynamic, dynamic>;
      AppToastUtil.showInfoToast(
        Get.context!,
        AppLocalStorage.getUserDetails().userId == remoteUid
            ? 'You have joined'
            : '${userData['name']} has Joined',
      );
      _firebaseService.addParticipants(meetingId, remoteUid);
      participants.add(
        ParticipantModel(
          userId: remoteUid,
          firebaseUid: userData['firebaseUserId'],
          name: userData['name'],
          isUserMuted: true,
          isUserSpeaking: false,
          color: WarmColorGenerator.getRandomWarmColor(),
        ),
      );
    }
    update();
  }

  void removeUser(int remoteUid) {
    AppToastUtil.showInfoToast(Get.context!, 'user Left');

    participants.removeWhere((e) => e.userId == remoteUid);
    update();
  }

  void updateMuteStatus(int remoteUid, bool muted) {
    participants =
        participants
            .map(
              (e) =>
                  e.userId == remoteUid
                      ? e.copyWith(
                        isUserMuted: muted,
                        isUserSpeaking: muted ? false : e.isUserSpeaking,
                      )
                      : e,
            )
            .toList();
    update();
  }

  void onActiveSpeaker(RtcConnection conn, int userId) {
    currentSpeaker = '$userId';
    participants =
        participants
            .map(
              (e) =>
                  e.userId == userId
                      ? e.copyWith(isUserSpeaking: true, isUserMuted: false)
                      : e.copyWith(isUserSpeaking: false, isUserMuted: true),
            )
            .toList();
    update();
  }

  void onJoinSuccess() {
    try {
      isJoined.value = true;
      final currentUserId = AppLocalStorage.getUserDetails().userId;
      _firebaseService.addParticipants(meetingId, currentUserId).then((v) {
        if (v) {
          addUser(currentUserId);
        }
      });
      _firebaseService.isCurrentUserMutedByHost(meetingId).listen((event) {
        _agoraService.engine?.muteLocalAudioStream(event);
        participants =
            participants
                .map(
                  (e) =>
                      e.userId == currentUserId
                          ? e.copyWith(isUserMuted: event)
                          : e,
                )
                .toList();
        update();
      });
      startTimer();
      update();
    } catch (e) {
      AppLogger.print('Error in onJoinSuccess: $e');
    }
  }

  RtcEngineEventHandler _rtcEngineEventHandler(BuildContext context) {
    return RtcEngineEventHandler(
      onUserJoined: (connection, remoteUid, elapsed) => addUser(remoteUid),
      onUserOffline: (connection, remoteUid, reason) => removeUser(remoteUid),
      onJoinChannelSuccess: (connection, elapsed) => onJoinSuccess(),

      // onAudioVolumeIndication: (
      //   connection,
      //   speakers,
      //   speakerNumber,
      //   totalVolume,
      // ) {

      // final loudestSpeaker = speakers.reduce((a, b) => a.volume > b.volume ? a : b);

      //     participants =
      //         participants
      //             .map(
      //               (e) =>
      //                   e.userId == loudestSpeaker.uid
      //                       ? e.copyWith(isUserSpeaking: true)
      //                       : e.copyWith(isUserSpeaking: false),
      //             )
      //             .toList();
      //     update();
      //
      // },
      onUserMuteAudio:
          (connection, remoteUid, muted) => updateMuteStatus(remoteUid, muted),
      onActiveSpeaker: onActiveSpeaker,

      onError: (error, message) {
        AppToastUtil.showErrorToast(context, '❌ Agora error: $error\n$message');
      },
    );
  }

  @override
  void onClose() {
    _agoraService.destroy();
    super.onClose();
  }

  void muteThisParticipantsForAllUser(ParticipantModel user) {
    participants =
        participants
            .map(
              (e) =>
                  e.userId == user.userId ? e.copyWith(isUserMuted: true) : e,
            )
            .toList();
    update();
  }

  void unMuteThisParticipantsForAllUser(ParticipantModel user) {
    participants =
        participants
            .map(
              (e) =>
                  e.userId == user.userId ? e.copyWith(isUserMuted: false) : e,
            )
            .toList();
    update();
  }
}
