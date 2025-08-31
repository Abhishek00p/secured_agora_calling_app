import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:secured_calling/core/models/private_meeting_model.dart';
import 'package:secured_calling/core/routes/app_router.dart';
import 'package:secured_calling/utils/app_logger.dart';
import 'package:secured_calling/utils/app_meeting_id_genrator.dart';
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
  final currentUser = AppLocalStorage.getUserDetails();
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
  final pttUsers = <int>[].obs;

  String meetingId = '';
  bool isHost = false;
  int remainingSeconds =
      AppLocalStorage.getUserDetails().isMember ? 25200 : 300;
  String currentSpeaker = '';

  bool get agoraInitialized => _agoraService.isInitialized;
  final meetingModel = MeetingModel.toEmpty().obs;
  Timer? _meetingTimer;
  StreamSubscription? _leaveSubscription;
  StreamSubscription? _muteSubscription;
  StreamSubscription? _meetingSubscription;

  RxInt activeSpeakerUid = 0.obs;

  void startTimer() async {
    try {
      _meetingTimer?.cancel(); // Cancel any existing timer
      final result = await _firebaseService.getMeetingData(meetingId);
      if (result == null) {
        AppToastUtil.showErrorToast('Meeting data not found');
        return;
      }
      meetingModel.value = MeetingModel.fromJson(result);
      remainingSeconds =
          meetingModel.value.scheduledEndTime.difference(DateTime.now()).inSeconds;

      isHost = meetingModel.value.hostId == currentUser.firebaseUserId;

      _meetingTimer = Timer.periodic(Duration(seconds: 1), (timer) {
        if (remainingSeconds <= 300 && isHost) {
          timer.cancel(); // stop this timer first
          if (!isHost && remainingSeconds <= 0) {
            endMeeting().then((_) {
              AppToastUtil.showInfoToast(
                'Your Free Trial Time is over, please contact support',
              );
            });
            Navigator.pop(Get.context!);
          } else {
            int remainingTime = 10;
            Timer? countdownTimer;

            countdownTimer = Timer.periodic(Duration(seconds: 1), (countdown) {
              if (remainingTime > 0) {
                remainingTime--;
              } else {
                countdown.cancel();
                endMeeting();
                Navigator.pop(Get.context!);
              }
            });

            showDialog(
              context: Get.context!,
              barrierDismissible: false,
              builder: (context) {
                return StatefulBuilder(
                  builder: (context, setState) {
                    return AlertDialog(
                      title: Text('Meeting Time Ended'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'This meeting will close in $remainingSeconds seconds.',
                            style: TextStyle(fontSize: 16),
                          ),
                          SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              countdownTimer?.cancel();
                              Navigator.pop(context);
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
        } else {
          remainingSeconds--;
        }
        update();
      });
      _leaveSubscription?.cancel();
      _leaveSubscription = _firebaseService
          .isInstructedToLeave(meetingId)
          .listen((isInstructed) {
            if (isInstructed) {
              endMeeting();
            }
          });
    } catch (e) {
      AppLogger.print('Error starting timer: $e');
    }
  }

  // void startTimer() async {
  //   try {
  //     isHost =
  //         meetingModel.hostId ==
  //         currentUser.firebaseUserId;

  //     remainingSeconds = meetingModel.duration * 60;

  //     Timer.periodic(Duration(seconds: 1), (timer) {
  //       if (remainingSeconds <= 0) {
  //         if (!isHost) {
  //           endMeeting().then((c) {
  //             AppToastUtil.showInfoToast(

  //               'Your Free Trial Time is over, please contact support',
  //             );
  //           });
  //           Navigator.pop(Get.context!);
  //         } else {
  //           int remainingTime = 10; // Countdown timer in seconds
  //           Timer? countdownTimer;

  //           // Start the countdown timer
  //           countdownTimer = Timer.periodic(Duration(seconds: 1), (timer) {
  //             if (remainingTime > 0) {
  //               remainingTime--;
  //             } else {
  //               timer.cancel();
  //               endMeeting(); // Automatically end the meeting after 10 seconds
  //               Navigator.pop(Get.context!); // Close the dialog and meeting
  //             }
  //           });

  //           // Show the dialog
  //           showDialog(
  //             context: Get.context!,
  //             barrierDismissible:
  //                 false, // Prevent dismissing the dialog by tapping outside
  //             builder: (context) {
  //               return StatefulBuilder(
  //                 builder: (context, setState) {
  //                   return AlertDialog(
  //                     title: Text('Meeting Time Ended'),
  //                     content: Column(
  //                       mainAxisSize: MainAxisSize.min,
  //                       children: [
  //                         Text(
  //                           'This meeting will close in $remainingTime seconds.',
  //                           style: TextStyle(fontSize: 16),
  //                         ),
  //                         SizedBox(height: 16),
  //                         ElevatedButton(
  //                           onPressed: () {
  //                             countdownTimer?.cancel(); // Stop the countdown
  //                             Navigator.pop(context); // Close the dialog
  //                             // Extend meeting logic here
  //                             extendMeetingTime();
  //                           },
  //                           child: Text('Extend Meeting Time'),
  //                         ),
  //                       ],
  //                     ),
  //                   );
  //                 },
  //               );
  //             },
  //           );
  //         }
  //         timer.cancel();
  //       } else {
  //         remainingSeconds--;
  //       }
  //       update();
  //     });
  //   } catch (e) {
  //     AppLogger.print('Error starting timer: $e');
  //   }
  // }

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

      await joinChannel(channelName: meetingId);
      await _agoraService.engine?.enableAudio();
      await _agoraService.engine?.muteLocalAudioStream(true);
      isMuted.value = true; // All users start muted by default
      if (isUserHost) {
        _firebaseService.startMeeting(meetingId);
      }

      _firebaseService.getParticipantsStream(meetingId).listen((snapshot) {
        final newParticipants = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return ParticipantModel(
            userId: data['userId'],
            name: data['username'],
            isUserMuted: !pttUsers.contains(data['userId']), // Muted if not in PTT
            isUserSpeaking: false, // This will be updated by Agora
            color: WarmColorGenerator.getRandomWarmColor(),
            firebaseUid: '', // This might need to be fetched if required
          );
        }).toList();
        participants = newParticipants;
        update();
      });

      _meetingSubscription?.cancel();
      _meetingSubscription =
          _firebaseService.getMeetingStream(meetingId).listen((doc) {
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          pttUsers.value = List<int>.from(data['pttUsers'] ?? []);

       
          updateMuteStatesForPTT();
        }
      });
    } catch (e) {
      AppLogger.print('Error initializing meeting: $e');
    }

    update();
  }

  Future<void> startPtt() async {
    await _firebaseService.meetingsCollection.doc(meetingId).update({
      'pttUsers': FieldValue.arrayUnion([currentUser.userId]),
    });
    await _agoraService.muteLocalAudio(false);
    isMuted.value = false;
  }

  Future<void> stopPtt() async {
    await _firebaseService.meetingsCollection.doc(meetingId).update({
      'pttUsers': FieldValue.arrayRemove([currentUser.userId]),
    });
    await _agoraService.muteLocalAudio(true);
    isMuted.value = true;
  }

  void updateMuteStatesForPTT() {
    if (isHost) {
      // Host can hear everyone. Unmute all remote streams.
      for (final participant in participants) {
        if (participant.userId != currentUser.userId) {
          _agoraService.engine?.muteRemoteAudioStream(uid: participant.userId, mute: false);
        }
      }
    } else {
      // Participants have specific audio rules.
      for (final participant in participants) {
        if (participant.userId == currentUser.userId) continue;

        // Participant can always hear the host.
      if (participant.userId == meetingModel.value.hostUserId) {
          _agoraService.engine?.muteRemoteAudioStream(uid: participant.userId, mute: false);
          continue;
        }

        // Mute/unmute other participants based on PTT status.
        // A participant should hear another participant only if BOTH are in the PTT group.
        final amIPtt = pttUsers.contains(currentUser.userId);
        final isOtherPtt = pttUsers.contains(participant.userId);

        if (amIPtt && isOtherPtt) {
          _agoraService.engine?.muteRemoteAudioStream(uid: participant.userId, mute: false);
        } else {
          _agoraService.engine?.muteRemoteAudioStream(uid: participant.userId, mute: true);
        }
      }
    }
    update();
  }

  Future<void> joinChannel({required String channelName}) async {
    try {
      final value = await _firebaseService.getMeetingData(meetingId);
      meetingModel.value = MeetingModel.fromJson(value ?? {});
      final currentUserId = currentUser.userId;

      // The max participants check should be done on the server-side with security rules
      // or a cloud function for reliability. Client-side check is not secure.

      final token = await _firebaseService.getAgoraToken(
        channelName: channelName,
        uid: currentUser.userId,
        isHost: isHost,
      );
      print("\n\nthe token is $token\n");
      if (token.trim().isEmpty) {
        AppToastUtil.showErrorToast('Token not found');
        return;
      }

      await _agoraService.joinChannel(
        channelName: channelName,
        token: token,
        userId: currentUserId,
      );
    } catch (e) {
      AppLogger.print('Error joining channel: $e');
      AppToastUtil.showErrorToast('Error joining channel: $e');
    }
  }

  Future<void> leaveChannel() async {
    await _agoraService.leaveChannel();
    isJoined.value = false;
  }

  Future<void> toggleSpeaker() async {
    isOnSpeaker.toggle();
    _agoraService.engine?.setEnableSpeakerphone(isOnSpeaker.value);
    update();
  }

 



  Future<void> endMeeting() async {
    await _agoraService.leaveChannel();
    if (meetingId.isNotEmpty) {
      await _firebaseService.endMeeting(meetingId);
    }
  }

  Future<void> endMeetForAll() async {
    endMeeting();
    removeAllParticipants();
  }

  Future<void> removeAllParticipants() async {
    await _firebaseService.removeAllParticipants(meetingId);
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

  void removeUser(int remoteUid) {
    // This is now handled by the participant stream
    AppLogger.print('User left: $remoteUid');
  }

  void updateMuteStatus(int remoteUid, bool muted) {
    AppLogger.print('User $remoteUid muted: $muted');
    final index = participants.indexWhere((e) => e.userId == remoteUid);
    if (index != -1) {
      participants[index] = participants[index].copyWith(
        isUserMuted: muted,
        // Only reset speaking status if user is muted
        isUserSpeaking: muted ? false : participants[index].isUserSpeaking,
      );
    } else {
      AppLogger.print('Warning: User $remoteUid not found in participants list');
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
                      ? e.copyWith(isUserSpeaking: true)
                      : e.copyWith(isUserSpeaking: false),
            )
            .toList();
    update();
  }

  void onJoinSuccess() {
    try {
      isJoined.value = true;
      final currentUserId = AppLocalStorage.getUserDetails().userId;
      _firebaseService.addParticipants(meetingId, currentUserId);
      startTimer();
      update();
    } catch (e) {
      AppLogger.print('Error in onJoinSuccess: $e');
    }
  }

  RtcEngineEventHandler _rtcEngineEventHandler(BuildContext context) {
    _agoraService.engine?.enableAudioVolumeIndication(
  interval: 200, // ms between reports
  smooth: 3,     // smoothness (1–3)
  reportVad: true, // voice activity detection
    );
    return RtcEngineEventHandler(
      onUserJoined: (connection, remoteUid, elapsed) {
        // The participant stream will handle adding the user to the list.
        // The PTT logic will handle muting/unmuting.
        AppLogger.print('User joined: $remoteUid');
      },
      onUserOffline: (connection, remoteUid, reason) => removeUser(remoteUid),
      onJoinChannelSuccess: (connection, elapsed) {
        onJoinSuccess();
      },
      onLeaveChannel: (connection, stats) {
        isMeetEneded = true;
        update();
      },
      onAudioVolumeIndication: (rtc,speakers, speakerNumber,totalVolume) {
          if (speakers.isNotEmpty) {
            final loudest = speakers.reduce((a, b) =>( a.volume??0) > (b.volume??0) ? a : b);
            if ((loudest.volume??0) > 5) { // threshold
              activeSpeakerUid.value = loudest.uid ?? 0;
            } else {
              activeSpeakerUid.value = 0;
            }
          }
        },
    
      onUserMuteAudio:
          (connection, remoteUid, muted) => updateMuteStatus(remoteUid, muted),
      onActiveSpeaker: onActiveSpeaker,

      onError: (error, message) {
        print('❌ Agora error: $error\n$message');
        AppToastUtil.showErrorToast('❌ Agora error: $error\n$message');
      },
    );
  }

  @override
  void onClose() {
    _agoraService.destroy();
    _meetingTimer?.cancel();
    _leaveSubscription?.cancel();
    _muteSubscription?.cancel();
    _meetingSubscription?.cancel();
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

  void extendMeetingTime() async {
    try {
      // Show loading state
      update();
      
      // Use the enhanced Firebase service
      await _firebaseService.extendMeetingWithOptions(
        meetingId: meetingId,
        additionalMinutes: 30,
        reason: 'Meeting extended by host during live session',
        notifyParticipants: true,
      );
      
      // Update local meeting model
      if (meetingModel.value != MeetingModel.toEmpty()) {
        final updatedMeeting = MeetingModel(
          meetId: meetingModel.value.meetId,
          meetingName: meetingModel.value.meetingName,
          channelName: meetingModel.value.channelName,
          hostId: meetingModel.value.hostId,
          hostUserId: meetingModel.value.hostUserId,
          hostName: meetingModel.value.hostName,
          password: meetingModel.value.password,
          memberCode: meetingModel.value.memberCode,
          requiresApproval: meetingModel.value.requiresApproval,
          status: meetingModel.value.status,
          isParticipantsMuted: meetingModel.value.isParticipantsMuted,
          maxParticipants: meetingModel.value.maxParticipants,
          duration: meetingModel.value.duration + 30,
          participants: meetingModel.value.participants,
          allParticipants: meetingModel.value.allParticipants,
          pendingApprovals: meetingModel.value.pendingApprovals,
          invitedUsers: meetingModel.value.invitedUsers,
          scheduledStartTime: meetingModel.value.scheduledStartTime,
          scheduledEndTime: meetingModel.value.scheduledEndTime.add(Duration(minutes: 30)),
          createdAt: meetingModel.value.createdAt,
          actualStartTime: meetingModel.value.actualStartTime,
          actualEndTime: meetingModel.value.actualEndTime,
          totalParticipantsCount: meetingModel.value.totalParticipantsCount,
          actualDuration: meetingModel.value.actualDuration,
          participantHistory: meetingModel.value.participantHistory,
        );
        
        meetingModel.value = updatedMeeting;
      }
      
      // Restart timer with new duration
      startTimer();
      
      // Show success message
      AppToastUtil.showSuccessToast('Meeting extended by 30 minutes');
      
    } catch (e) {
      AppLogger.print('Error extending meeting: $e');
      AppToastUtil.showErrorToast('Failed to extend meeting: $e');
    } finally {
      update();
    }
  }

  // Future<bool> createPrivateMeeting({
  //   required String parentMeetingId,
  //   required int hostId,
  //   required String hostName,
  //   required int participantId,
  //   required String participantName,
  //   required int maxParticipants,
  // }) async {
  //   try {
  //     final meetId = await AppMeetingIdGenrator.generateMeetingId();
  //     final hostToken = await _firebaseService.getAgoraToken(
  //       channelName: meetId,
  //       uid: hostId,
  //       isHost: true,
  //     );
  //     if (hostToken.isEmpty) {
  //       AppToastUtil.showErrorToast('Failed to generate host token');
  //       return false;
  //     }
  //     final participantToken = await _firebaseService.getAgoraToken(
  //       channelName: meetId,
  //       uid: participantId,
  //       isHost: false,
  //     );
    
  //     if (participantToken.isEmpty) {
  //       AppToastUtil.showErrorToast('Failed to generate participant token');
  //       return false;
  //     }
  //     print("the token is $hostToken, $participantToken");
  //     final privateMeeting = PrivateMeetingModel(
  //       meetId: meetId,
  //       parentMeetingId: parentMeetingId,
  //       channelName: meetId,
  //       hostId: hostId,
  //       participantId: participantId,
  //       hostName: hostName,
  //       participantName: participantName,
  //       maxParticipants: maxParticipants,
  //       createdAt: DateTime.now(),
  //       scheduledStartTime: DateTime.now(),
  //       scheduledEndTime: DateTime.now().add(Duration(hours: 1)),
  //       status: 'live',
  //       duration: 60, // Default duration in minutes
  //       tokens: {
  //         'hostToken': hostToken,
  //         'participantToken': participantToken,
  //       },
  //     );

  //     await _firebaseService.createPrivateMeeting(privateMeeting);
  //       Navigator.pop(Get.context!); // Close the current meeting
  //     // Navigate to the private meeting room
  //     Navigator.pushNamed(
  //       Get.context!,
  //       AppRouter.meetingRoomRoute,
  //       arguments: {
  //         'channelName': meetId,
  //         'isHost': hostId == AppLocalStorage.getUserDetails().userId,
  //         'meetingId': meetId,
  //       },
  //     );
  //     return true;
  //   } catch (e) {
  //     AppLogger.print('Error creating private meeting: $e');
  //     AppToastUtil.showErrorToast('Error creating private meeting: $e');
  //     return false;
  //   }
  // }

  // void createPrivateRoomForUser(ParticipantModel user) async{
  //  await endMeeting();
  //   final isCreated = await createPrivateMeeting(
  //     parentMeetingId: meetingId,
  //     hostId: currentUser.userId,
  //     hostName: currentUser.name,
  //     participantId: user.userId,
  //     participantName: user.name,
  //     maxParticipants: 2, // Assuming private room for 2 participants
  //   );
  //   if (isCreated) {
  //     AppToastUtil.showSuccessToast('Private room created successfully');
    
  //   } else {
  //     AppToastUtil.showErrorToast('Failed to create private room');
  //   }
  // }
}
