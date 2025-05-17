import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:secured_calling/utils/app_logger.dart';
import 'package:secured_calling/utils/app_tost_util.dart';
import 'package:secured_calling/core/models/meeting_model.dart';
import 'package:secured_calling/core/services/app_firebase_service.dart';
import 'package:secured_calling/core/services/app_local_storage.dart';
import 'package:secured_calling/features/meeting/services/agora_service.dart';
import 'package:secured_calling/core/models/participant_model.dart';
import 'package:secured_calling/utils/warm_color_generator.dart';

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
  bool isMeetEneded = false;
  List<ParticipantModel> participants = <ParticipantModel>[].obs;

  String meetingId = '';
  bool isHost = false;
  int remainingSeconds =
      AppLocalStorage.getUserDetails().isMember ? 25200 : 300;
  String currentSpeaker = '';

  bool get agoraInitialized => _agoraService.isInitialized;
  MeetingModel meetingModel = MeetingModel.toEmpty();

  void startTimer() async {
    try {
      isHost =
          meetingModel.hostId ==
          AppLocalStorage.getUserDetails().firebaseUserId;

      remainingSeconds = meetingModel.duration * 60;

      Timer.periodic(Duration(seconds: 1), (timer) {
        if (remainingSeconds <= 0) {
          if (!isHost) {
            endMeeting().then((c) {
              AppToastUtil.showInfoToast(
                
                'Your Free Trial Time is over, please contact support',
              );
            });
            Navigator.pop(Get.context!);
          } else {
            int remainingTime = 10; // Countdown timer in seconds
            Timer? countdownTimer;

            // Start the countdown timer
            countdownTimer = Timer.periodic(Duration(seconds: 1), (timer) {
              if (remainingTime > 0) {
                remainingTime--;
              } else {
                timer.cancel();
                endMeeting(); // Automatically end the meeting after 10 seconds
                Navigator.pop(Get.context!); // Close the dialog and meeting
              }
            });

            // Show the dialog
            showDialog(
              context: Get.context!,
              barrierDismissible:
                  false, // Prevent dismissing the dialog by tapping outside
              builder: (context) {
                return StatefulBuilder(
                  builder: (context, setState) {
                    return AlertDialog(
                      title: Text('Meeting Time Ended'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'This meeting will close in $remainingTime seconds.',
                            style: TextStyle(fontSize: 16),
                          ),
                          SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              countdownTimer?.cancel(); // Stop the countdown
                              Navigator.pop(context); // Close the dialog
                              // Extend meeting logic here
                              extendMeetingTime();
                            },
                            child: Text('Extend Meeting Time'),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          }
          timer.cancel();
        } else {
          remainingSeconds--;
        }
        update();
      });
    } catch (e) {
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
      final value = await _firebaseService.getMeetingData(meetingId);
      AppLogger.print('meeting data: $value');
      meetingModel = MeetingModel.fromJson(value ?? {});
      final currentUserId = AppLocalStorage.getUserDetails().userId;
      if (token.trim().isEmpty) {
        AppToastUtil.showErrorToast( 'Token not found');
        return;
      }
      AppLogger.print('agora token :$token ');

      if (participants.length >= meetingModel.maxParticipants) {
        AppToastUtil.showErrorToast(
          
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
      AppToastUtil.showErrorToast( 'Error joining channel: $e');
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
          isUserMuted: false,
          isUserSpeaking: false,
          color: WarmColorGenerator.getRandomWarmColor(),
        ),
      );
    }
    update();
  }

  void removeUser(int remoteUid) {
    AppToastUtil.showInfoToast( 'user Left');

    participants.removeWhere((e) => e.userId == remoteUid);
    update();
  }

  void updateMuteStatus(int remoteUid, bool muted) {
    AppLogger.print('User $remoteUid muted: $muted');
    final index = participants.indexWhere((e) => e.userId == remoteUid);
    if (index != -1) {
      participants[index] = participants[index].copyWith(
        isUserMuted: muted,
        isUserSpeaking: muted ? false : null,
      );
    }

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
      onLeaveChannel: (connection, stats) {
        isMeetEneded = true;
        update();
      },
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
        AppToastUtil.showErrorToast('❌ Agora error: $error\n$message');
      },
    );
  }

  @override
  void onClose() {
    _agoraService.destroy();
    super.onClose();
  }

  void muteThisParticipantsForAllUser(ParticipantModel user) {
    _firebaseService.muteParticipants(meetingId, user.userId, true);
    update();
  }

  void unMuteThisParticipantsForAllUser(ParticipantModel user) {
    _firebaseService.muteParticipants(meetingId, user.userId, false);

    update();
  }

  void extendMeetingTime() {
    remainingSeconds += 3600; // Add 1 hour (3600 seconds) to the remaining time
  }
}
