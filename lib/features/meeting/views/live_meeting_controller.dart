import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:secured_calling/app_logger.dart';
import 'package:secured_calling/app_tost_util.dart';
import 'package:secured_calling/core/services/app_firebase_service.dart';
import 'package:secured_calling/core/services/app_local_storage.dart';
import 'package:secured_calling/features/meeting/services/agora_service.dart';
import 'package:secured_calling/participant_model.dart';

class MeetingController extends GetxController {
  final AppFirebaseService _firebaseService = AppFirebaseService.instance;
  final AgoraService _agoraService = AgoraService();

  // State variables
  final isLoading = false.obs;
  final error = RxnString();
  final pendingRequests = <Map<String, dynamic>>[].obs;

  final isMuted = false.obs;
  final isOnSpeaker = false.obs;
  final isJoined = false.obs;
  final isVideoEnabled = true.obs;
  final isScreenSharing = false.obs;

  List<ParticipantModel> participants = <ParticipantModel>[].obs;

  String meetingId = '';
  bool isHost = false;
  int remainingSeconds = 25200;
  String currentSpeaker = '';

  bool get agoraInitialized => _agoraService.isInitialized;

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
    final token = await _firebaseService.getAgoraToken();
    if (token.trim().isEmpty) {
      AppToastUtil.showErrorToast(Get.context!, 'Token not found');
      return;
    }
    AppLogger.print('agora token :$token');
    await _agoraService.joinChannel(
      channelName: channelName,
      token: token,
      userId: AppLocalStorage.getUserDetails().userId,
    );
    final currentUser = AppLocalStorage.getUserDetails();
    participants.add(
      ParticipantModel(
        userId: currentUser.userId,
        firebaseUid: currentUser.firebaseUserId,
        name: currentUser.name,
        isUserMuted: isMuted.value,
      ),
    );
    isJoined.value = true;
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
    if (meetingId.isNotEmpty && isHost) {
      await _firebaseService.endMeeting(meetingId);
    }
  }

  Future<void> fetchPendingRequests() async {
    isLoading.value = true;
    error.value = null;

    try {
      final meetingDoc =
          await _firebaseService.meetingsCollection.doc(meetingId).get();
      final meetingData = meetingDoc.data() as Map<String, dynamic>;
      final pendingUserIds = meetingData['pendingApprovals'] as List<dynamic>;

      final List<Map<String, dynamic>> requests = [];

      for (final userId in pendingUserIds) {
        final userDoc = await _firebaseService.getUserData(userId as String);
        final userData = userDoc.data() as Map<String, dynamic>?;
        if (userData != null) {
          requests.add({
            'userId': userId,
            'name': userData['name'] ?? 'Unknown User',
          });
        }
      }

      pendingRequests.value = requests;
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> rejectJoinRequest(String userId) async {
    try {
      await _firebaseService.rejectMeetingJoinRequest(meetingId, userId);
      await fetchPendingRequests();
    } catch (e) {
      error.value = 'Error rejecting request: $e';
    }
  }

  Future<void> addUser(int remoteUid) async {
    if (participants.any((e) => e.userId == remoteUid)) return;
    AppToastUtil.showInfoToast(Get.context!, 'New user Added :$remoteUid');

    final result = await _firebaseService.getUserDataWhereUserId(remoteUid);
    if (result != null) {
      final userData = result.data() as Map<dynamic, dynamic>;
      AppToastUtil.showInfoToast(Get.context!, 'New user Added : $userData');
      participants.add(
        ParticipantModel(
          userId: remoteUid,
          firebaseUid: result.id,
          name: userData['name'],
          isUserMuted: true,
        ),
      );
    }
    update();
  }

  void removeUser(int remoteUid) {
    AppToastUtil.showInfoToast(Get.context!, ' user Left');

    participants.removeWhere((e) => e.userId == remoteUid);
    update();
  }

  void updateMuteStatus(int remoteUid, bool muted) {
    participants =
        participants
            .map(
              (e) => e.userId == remoteUid ? e.copyWith(isUserMuted: muted) : e,
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
                      ? e.copyWith(isUserMuted: false)
                      : e.copyWith(isUserMuted: true),
            )
            .toList();
    update();
  }

  RtcEngineEventHandler _rtcEngineEventHandler(BuildContext context) {
    return RtcEngineEventHandler(
      onUserJoined: (connection, remoteUid, elapsed) => addUser(remoteUid),
      onUserOffline: (connection, remoteUid, reason) => removeUser(remoteUid),
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
}
