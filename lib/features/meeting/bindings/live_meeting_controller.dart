import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:secured_calling/core/routes/app_router.dart';
import 'package:secured_calling/utils/app_logger.dart';
import 'package:secured_calling/utils/app_tost_util.dart';
import 'package:secured_calling/core/models/meeting_model.dart';
import 'package:secured_calling/core/services/app_firebase_service.dart';
import 'package:secured_calling/core/services/app_local_storage.dart';
import 'package:secured_calling/core/services/app_lifecycle_manager.dart';
import 'package:secured_calling/core/services/meeting_timeout_service.dart';
import 'package:secured_calling/features/meeting/services/agora_service.dart';
import 'package:secured_calling/core/models/participant_model.dart';
import 'package:secured_calling/utils/warm_color_generator.dart';
import 'package:secured_calling/features/meeting/widgets/timer_warning_dialog.dart';
import 'package:secured_calling/features/meeting/widgets/extend_meeting_dialog.dart';

class MeetingController extends GetxController {
  final AppFirebaseService _firebaseService = AppFirebaseService.instance;
  final AgoraService _agoraService = AgoraService();
  final currentUser = AppLocalStorage.getUserDetails();
  final AppLifecycleManager _lifecycleManager = AppLifecycleManager.instance;
  final MeetingTimeoutService _timeoutService = MeetingTimeoutService.instance;
  // State variables
  final isLoading = false.obs;
  final error = RxnString();

  final isMuted = false.obs;
  final isOnSpeaker = true.obs;
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

  RxBool isRecordingOn = false.obs;
  RxMap<String, dynamic> payloadOfRecording = RxMap();

  String agoraMeetingToken = '';

  String speakingEventDocId = '';
  int recordingStartTimeEpoch = 0;

  @override
  void onInit() {
    super.onInit();
    _muteSubscription = AppFirebaseService.instance
        .isCurrentUserMutedByHost(meetingId)
        .listen((s) {
          if (s) {
            stopPtt();
          }
        });
  }

  void startTimer() async {
    try {
      _meetingTimer?.cancel(); // Cancel any existing timer
      final result = await _firebaseService.getMeetingData(meetingId);
      if (result == null) {
        AppToastUtil.showErrorToast('Meeting data not found');
        return;
      }
      print(
        "\n <-------- meeting model data in start timer: ${result.entries.join("\n")} \n ----> ",
      );
      meetingModel.value = MeetingModel.fromJson(result);
      final thisMeetingScheduledEndTime = meetingModel.value.scheduledEndTime;
      final currentTime = DateTime.now();
      remainingSeconds =
          thisMeetingScheduledEndTime.difference(currentTime).inSeconds;
      print(
        "\n <------------------------------------------------\n meeting end time which was scheduled : $thisMeetingScheduledEndTime , current time : $currentTime, difference in sec : $remainingSeconds\n ---------------------------------------->\n",
      );
      isHost = meetingModel.value.hostUserId == currentUser.userId;

      // Initialize last known meeting data for change detection
      _lastMeetingData = Map<String, dynamic>.from(result);

      _meetingTimer = Timer.periodic(Duration(seconds: 1), (timer) {
        // Check if meeting time has ended
        if (remainingSeconds <= 0) {
          timer.cancel();
          print(
            "forcing end meeting becoz remaining second < = 0, we are in start timer func",
          );
          _forceEndMeeting();
          return;
        }

        // Show persistent timer warning dialog at 5 minutes remaining
        if (remainingSeconds <= 300 &&
            remainingSeconds > 0 &&
            isHost &&
            !_hasExtended &&
            !_timerWarningShown) {
          if (remainingSeconds % 60 == 0) {
            _showTimerWarningDialog();
          }
        }

        // Update existing dialog content if it's already shown
        if (_timerWarningShown && _timerWarningDialogKey.currentState != null) {
          _updateTimerWarningContent();
        }

        // Show final countdown toast in last 60 seconds if host hasn't extended
        if (remainingSeconds <= 60 && remainingSeconds > 0 && !_hasExtended) {
          _showEndTimeToast(remainingSeconds);
        }

        remainingSeconds--;
        update();
      });

      _leaveSubscription?.cancel();
      _leaveSubscription = _firebaseService.isInstructedToLeave(meetingId).listen((
        isInstructed,
      ) {
        if (isInstructed) {
          print(
            "<<<<<<< ----------- \n user got instruction to leave the meeting ...... \n --------- >>>>>>",
          );
          endMeeting();
        }
      });
    } catch (e) {
      AppLogger.print('Error starting timer: $e');
    }
  }

  // Track if meeting has been extended
  bool _hasExtended = false;

  // Track if timer warning dialog is already shown
  bool _timerWarningShown = false;

  // Track if timer warning dialog was dismissed (to prevent re-showing)
  bool _timerWarningDismissed = false;

  // Global key for the timer warning dialog
  final GlobalKey<TimerWarningDialogState> _timerWarningDialogKey =
      GlobalKey<TimerWarningDialogState>();

  // Track last known meeting data to detect changes
  Map<String, dynamic>? _lastMeetingData;

  /// Handle meeting data updates from Firestore stream
  void _handleMeetingDataUpdate(Map<String, dynamic> data) {
    try {
      // Check if this is the first time we're receiving data
      if (_lastMeetingData == null) {
        _lastMeetingData = Map<String, dynamic>.from(data);
        return;
      }

      // Check for meeting time changes (extensions)
      final currentScheduledEndTime = data['scheduledEndTime'];
      final lastScheduledEndTime = _lastMeetingData!['scheduledEndTime'];

      final currentDuration = data['duration'] as int? ?? 0;
      final lastDuration = _lastMeetingData!['duration'] as int? ?? 0;

      // Check if meeting was extended
      if (currentScheduledEndTime != lastScheduledEndTime ||
          currentDuration != lastDuration) {
        AppLogger.print('Meeting time changed detected - refreshing timer');

        // Update local meeting model with new data
        meetingModel.value = MeetingModel.fromJson(data);

        // Restart timer with updated time
        _refreshTimerWithNewData();

        // Show notification to participants (not host)
        if (!isHost) {
          final additionalMinutes = currentDuration - lastDuration;
          if (additionalMinutes > 0) {
            final reason = data['lastExtensionReason'] as String?;
            final message =
                reason != null
                    ? 'Meeting extended by $additionalMinutes minutes: $reason'
                    : 'Meeting extended by $additionalMinutes minutes';
            AppToastUtil.showInfoToast(message);
          }
        }
      }

      // Check for extension notifications (for all participants)
      final lastNotification = data['lastExtensionNotification'];
      final lastKnownNotification =
          _lastMeetingData!['lastExtensionNotification'];

      if (lastNotification != lastKnownNotification &&
          lastNotification != null) {
        final extensionMinutes = data['lastExtensionMinutes'] as int? ?? 0;
        final reason = data['lastExtensionReason'] as String?;

        if (extensionMinutes > 0) {
          final message =
              reason != null
                  ? 'Meeting extended by $extensionMinutes minutes: $reason'
                  : 'Meeting extended by $extensionMinutes minutes';
          AppToastUtil.showInfoToast(message);
        }
      }

      // Update last known data
      _lastMeetingData = Map<String, dynamic>.from(data);
    } catch (e) {
      AppLogger.print('Error handling meeting data update: $e');
    }
  }

  /// Refresh timer with updated meeting data
  void _refreshTimerWithNewData() {
    try {
      // Cancel existing timer
      _meetingTimer?.cancel();

      // Recalculate remaining seconds with updated data
      remainingSeconds =
          meetingModel.value.scheduledEndTime
              .difference(DateTime.now())
              .inSeconds;

      // Reset extension flags for new timer period
      _hasExtended = false;
      _timerWarningShown = false;
      _timerWarningDismissed = false;

      // Restart timer
      _meetingTimer = Timer.periodic(Duration(seconds: 1), (timer) {
        // Check if meeting time has ended
        if (remainingSeconds <= 0) {
          timer.cancel();
          print(
            "meeting time is less then 0, we are inside refreshtimerWithNewData",
          );
          _forceEndMeeting();
          return;
        }

        // Show persistent timer warning dialog at 5 minutes remaining
        if (remainingSeconds <= 300 &&
            remainingSeconds > 0 &&
            isHost &&
            !_hasExtended &&
            !_timerWarningShown) {
          _showTimerWarningDialog();
        }

        // Update existing dialog content if it's already shown
        if (_timerWarningShown && _timerWarningDialogKey.currentState != null) {
          _updateTimerWarningContent();
        }

        // Show final countdown toast in last 60 seconds if host hasn't extended
        if (remainingSeconds <= 60 && remainingSeconds > 0 && !_hasExtended) {
          _showEndTimeToast(remainingSeconds);
        }

        remainingSeconds--;
        update();
      });

      AppLogger.print(
        'Timer refreshed with new meeting data. Remaining: $remainingSeconds seconds',
      );
    } catch (e) {
      AppLogger.print('Error refreshing timer: $e');
    }
  }

  // Show persistent timer warning dialog
  void _showTimerWarningDialog() {
    if (_timerWarningShown || _timerWarningDismissed) {
      return; // Don't show if already shown or dismissed
    }

    _timerWarningShown = true;

    showDialog(
      context: Get.context!,
      barrierDismissible: false, // Cannot be dismissed by clicking outside
      builder:
          (context) => TimerWarningDialog(
            key: _timerWarningDialogKey,
            onExtend: () async {
              _timerWarningShown = false;
              Navigator.pop(context);
              await _showExtendMeetingDialog(context);
            },
            onDismiss: () {
              _timerWarningShown = false;
              _timerWarningDismissed =
                  true; // Mark as dismissed to prevent re-showing
              Navigator.pop(context);
            },
          ),
    );
  }

  // Update timer warning dialog content
  void _updateTimerWarningContent() {
    if (_timerWarningDialogKey.currentState != null) {
      _timerWarningDialogKey.currentState!.updateRemainingTime(
        remainingSeconds,
      );
    }
  }

  // Show extend meeting dialog
  Future<void> _showExtendMeetingDialog(BuildContext context) async {
    showDialog(
      context: context,
      builder:
          (context) => ExtendMeetingDialog(
            meetingId: meetingId,
            meetingTitle: meetingModel.value.meetingName,
            onExtend: (additionalMinutes, reason) async {
              try {
                await extendMeetingWithOptions(
                  additionalMinutes: additionalMinutes,
                  reason: reason,
                );
                return true;
              } catch (e) {
                AppToastUtil.showErrorToast('Failed to extend meeting: $e');
                return false;
              }
            },
          ),
    );
  }

  // Show end time toast in last 60 seconds
  void _showEndTimeToast(int secondsLeft) {
    if (secondsLeft % 10 == 0) {
      // Show every 10 seconds to avoid spam
      AppToastUtil.showInfoToast(
        'Meeting will end in ${secondsLeft ~/ 60}:${(secondsLeft % 60).toString().padLeft(2, '0')}',
      );
    }
  }

  // Force end meeting when time runs out
  Future<void> _forceEndMeeting() async {
    try {
      AppLogger.print('Meeting time expired. Force ending meeting...');

      // Show final warning
      AppToastUtil.showErrorToast(
        'Meeting time has expired. Ending meeting...',
      );

      // Force remove all participants including host
      await _firebaseService.removeAllParticipants(meetingId);

      // Leave Agora channel
      await _agoraService.leaveChannel();

      // Clear all memories and state
      _clearMeetingState();

      // Navigate back to home page
      if (Get.context != null && Get.context!.mounted) {
        Get.offAllNamed(AppRouter.homeRoute);
      }
    } catch (e) {
      AppLogger.print('Error force ending meeting: $e');
      // Even if there's an error, try to navigate back
      if (Get.context != null && Get.context!.mounted) {
        Get.offAllNamed(AppRouter.homeRoute);
      }
    }
  }

  // Clear all meeting state and memories
  void _clearMeetingState() {
    AppLogger.print('Starting _clearMeetingState cleanup...');

    // Cancel all timers
    _meetingTimer?.cancel();
    _leaveSubscription?.cancel();
    _muteSubscription?.cancel();
    _meetingSubscription?.cancel();

    // Reset all state variables
    isMeetEneded = true;
    participants.clear();
    pttUsers.clear();
    remainingSeconds = 0;
    isHost = false;
    isMuted.value = false;
    isOnSpeaker.value = false;
    isJoined.value = false;
    isVideoEnabled.value = true;
    isScreenSharing.value = false;
    activeSpeakerUid.value = 0;
    currentSpeaker = '';
    _hasExtended = false;

    // Clear error state
    error.value = null;

    // Reset timer warning flags
    _timerWarningShown = false;
    _timerWarningDismissed = false; // Reset dismissal flag

    // Clear meeting status from lifecycle manager
    _lifecycleManager.clearMeetingStatus();

    // Destroy Agora engine to prevent error -17
    try {
      _agoraService.destroy();
      AppLogger.print('Agora engine destroyed successfully');
    } catch (e) {
      AppLogger.print('Error destroying Agora engine: $e');
    }

    update();
    AppLogger.print('_clearMeetingState cleanup completed');
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

      await joinChannel(channelName: meetingId);
      await _agoraService.engine?.enableAudio();
      await _agoraService.engine?.muteLocalAudioStream(true);
      isMuted.value = true; // All users start muted by default
      if (isUserHost) {
        _firebaseService.startMeeting(meetingId);
      }

      _firebaseService.getParticipantsStream(meetingId).listen((snapshot) {
        final currentUserId = AppLocalStorage.getUserDetails().userId;
        final newParticipants =
            snapshot.docs
                .where((doc) {
                  return (doc.data() as Map<String, dynamic>)['isActive'] ==
                      true;
                })
                .map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return ParticipantModel(
                    userId: data['userId'] ?? -1,
                    name: data['username'] ?? '',
                    isUserMuted: data['isMuted'] as bool? ?? false,
                    isUserSpeaking: false, // This will be updated by Agora
                    color: WarmColorGenerator.getRandomWarmColorByIndex(
                      data['colorIndex'] ?? 0,
                    ),
                    firebaseUid:
                        '', // This might need to be fetched if required
                  );
                })
                .toList();

        // Check if current user was forcefully removed
        // Only check for removal if user was previously in the meeting and is now removed
        final wasUserInMeeting = participants.any(
          (p) => p.userId == currentUserId,
        );
        final isUserStillInMeeting = newParticipants.any(
          (p) => p.userId == currentUserId,
        );
        final removedByHost =
            (snapshot.docs
                            .firstWhereOrNull(
                              (doc) =>
                                  (doc.data()
                                      as Map<String, dynamic>)['userId'] ==
                                  currentUserId,
                            )
                            ?.data()
                        as Map<String, dynamic>? ??
                    <String, dynamic>{})['removedByHost']
                as bool? ??
            false;
        if (wasUserInMeeting && !isUserStillInMeeting && removedByHost) {
          AppLogger.print('User was forcefully removed from meeting');
          _handleForceRemoval();
          return;
        }

        // Check if user just joined the meeting (for join request approval)
        if (!wasUserInMeeting && isUserStillInMeeting) {
          AppLogger.print('User was approved and joined the meeting');
          // The MeetingListenerService will handle navigation
          // This is just for logging purposes
        }

        participants = newParticipants;
        update();
      });

      _meetingSubscription?.cancel();
      _meetingSubscription = _firebaseService
          .getMeetingStream(meetingId)
          .listen((doc) {
            if (doc.exists) {
              final data = doc.data() as Map<String, dynamic>;
              pttUsers.value = List<int>.from(data['pttUsers'] ?? []);

              updateMuteStatesForPTT();

              // Check for meeting time changes (extensions)
              _handleMeetingDataUpdate(data);
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
    final dateTimeEpoch = DateTime.now().toUtc().millisecondsSinceEpoch;
    speakingEventDocId = dateTimeEpoch.toString();
    await _firebaseService.meetingsCollection
        .doc(meetingId)
        .collection('participants')
        .doc(currentUser.userId.toString())
        .collection('speakingEvents')
        .doc(speakingEventDocId)
        .set({
          'start': dateTimeEpoch,
          'userId': currentUser.userId,
          'userName': currentUser.name,
        });
  }

  Future<void> stopPtt() async {
    await _firebaseService.meetingsCollection.doc(meetingId).update({
      'pttUsers': FieldValue.arrayRemove([currentUser.userId]),
    });
    await _agoraService.muteLocalAudio(true);
    isMuted.value = true;
    await _firebaseService.meetingsCollection
        .doc(meetingId)
        .collection('participants')
        .doc(currentUser.userId.toString())
        .collection('speakingEvents')
        .doc(speakingEventDocId)
        .update({'stop': DateTime.now().toUtc().millisecondsSinceEpoch});
    speakingEventDocId = '';
  }

  void updateMuteStatesForPTT() {
    if (isHost) {
      // Host can hear everyone. Unmute all remote streams.
      for (final participant in participants) {
        if (participant.userId != currentUser.userId) {
          _agoraService.engine?.muteRemoteAudioStream(
            uid: participant.userId,
            mute: false,
          );
        }
      }
    } else {
      // Participants have specific audio rules.
      for (final participant in participants) {
        if (participant.userId == currentUser.userId) continue;

        // Participant can always hear the host.
        if (participant.userId == meetingModel.value.hostUserId) {
          _agoraService.engine?.muteRemoteAudioStream(
            uid: participant.userId,
            mute: false,
          );
          continue;
        }

        // Mute/unmute other participants based on PTT status.
        // A participant should hear another participant only if BOTH are in the PTT group.
        final amIPtt = pttUsers.contains(currentUser.userId);
        final isOtherPtt = pttUsers.contains(participant.userId);

        if (amIPtt && isOtherPtt) {
          _agoraService.engine?.muteRemoteAudioStream(
            uid: participant.userId,
            mute: false,
          );
        } else {
          _agoraService.engine?.muteRemoteAudioStream(
            uid: participant.userId,
            mute: true,
          );
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
      print("\n\nthe agora token is $token\n");
      if (token.trim().isEmpty) {
        AppToastUtil.showErrorToast('Token not found');
        return;
      }
      agoraMeetingToken = token;
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
    //store data in firestore
    if (isOnSpeaker.value) {
      final dateTimeEpoch = DateTime.now().toUtc().millisecondsSinceEpoch;
      speakingEventDocId = dateTimeEpoch.toString();
      await _firebaseService.meetingsCollection
          .doc(meetingId)
          .collection('participants')
          .doc(currentUser.userId.toString())
          .collection('speakingEvents')
          .doc(speakingEventDocId)
          .set({
            'start': dateTimeEpoch,
            'userId': currentUser.userId,
            'userName': currentUser.name,
          });
    } else {
      await _firebaseService.meetingsCollection
          .doc(meetingId)
          .collection('participants')
          .doc(currentUser.userId.toString())
          .collection('speakingEvents')
          .doc(speakingEventDocId)
          .update({'stop': DateTime.now().toUtc().millisecondsSinceEpoch});
      speakingEventDocId = '';
    }
    update();
  }

  Future<void> endMeeting() async {
    try {
      AppLogger.print('Starting endMeeting process...');

      // Leave Agora channel first
      await _agoraService.leaveChannel();
      AppLogger.print('Left Agora channel successfully');

      // Remove user from Firebase participants
      if (meetingId.isNotEmpty) {
        await _firebaseService.endMeeting(meetingId);
        AppLogger.print('Removed user from Firebase participants');
      }

      // Stop heartbeat
      _timeoutService.stopHeartbeat();
      AppLogger.print('Stopped heartbeat');

      // Clear all meeting state and memories
      _clearMeetingState();
      AppLogger.print('Cleared meeting state');

      // Navigate back to home page
      if (Get.context != null && Get.context!.mounted) {
        WidgetsBinding.instance.addPostFrameCallback((s) {
          Get.offAllNamed(AppRouter.homeRoute);
        });
        AppLogger.print('Navigated back to home');
      }

      AppLogger.print('endMeeting process completed successfully');
    } catch (e) {
      AppLogger.print('Error in endMeeting: $e');
      AppToastUtil.showErrorToast('Error leaving meeting: $e');

      // Even if there's an error, try to clear state and navigate
      try {
        _clearMeetingState();
        if (Get.context != null && Get.context!.mounted) {
          Get.offAllNamed(AppRouter.homeRoute);
        }
      } catch (cleanupError) {
        AppLogger.print('Error during cleanup: $cleanupError');
      }
    }
  }

  Future<void> endMeetForAll() async {
    try {
      // First remove all participants from Firebase
      await removeAllParticipants();

      // Then end the meeting (which will handle Agora cleanup and navigation)
      await endMeeting();
    } catch (e) {
      AppLogger.print('Error in endMeetForAll: $e');
      AppToastUtil.showErrorToast('Error ending meeting for all: $e');

      // Even if there's an error, try to end the meeting
      try {
        await endMeeting();
      } catch (endError) {
        AppLogger.print('Error during fallback endMeeting: $endError');
      }
    }
  }

  Future<void> removeAllParticipants() async {
    await _firebaseService.removeAllParticipants(meetingId);
  }

  /// Debug method to test join request creation
  Future<void> testCreateJoinRequest() async {
    try {
      AppLogger.print('Testing join request creation for meeting: $meetingId');
      await _firebaseService.requestToJoinMeeting(
        meetingId,
        999999, // Test user ID
        userName: 'Test User',
        userEmail: 'test@example.com',
      );
      AppLogger.print('Test join request created successfully');
    } catch (e) {
      AppLogger.print('Error creating test join request: $e');
    }
  }

  Stream<List<Map<String, dynamic>>> fetchPendingRequests() async* {
    AppLogger.print(
      'Starting to listen for pending join requests for meeting: $meetingId',
    );

    yield* _firebaseService.getPendingJoinRequestsStream(meetingId).map((
      querySnapshot,
    ) {
      AppLogger.print(
        'Received querySnapshot with ${querySnapshot.docs.length} documents',
      );
      final List<Map<String, dynamic>> requests = [];

      for (final doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        AppLogger.print(
          'Processing join request document: ${doc.id}, data: $data',
        );

        requests.add({
          'userId': data['userId'] as int,
          'name': data['userName'] ?? 'Unknown User',
          'requestId': doc.id,
          'requestedAt': data['requestedAt'],
        });
      }

      AppLogger.print('Processed ${requests.length} join requests: $requests');
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

  /// Host-only feature: Forcefully remove a participant from the meeting
  Future<void> removeParticipantForcefully(int userId) async {
    if (!isHost) {
      AppToastUtil.showErrorToast('Only host can remove participants');
      return;
    }

    try {
      // Remove participant from Firebase
      await _firebaseService.removeParticipants(
        meetingId,
        userId,
        isRemovedByHost: true,
      );

      // Show success message
      AppToastUtil.showSuccessToast('Participant removed from meeting');

      AppLogger.print(
        'Host removed participant $userId from meeting $meetingId',
      );
    } catch (e) {
      AppLogger.print('Error removing participant: $e');
      AppToastUtil.showErrorToast('Error removing participant: $e');
    }
  }

  /// Handle when current user is forcefully removed from meeting
  void _handleForceRemoval() {
    try {
      AppLogger.print('Handling force removal cleanup...');

      // Show notification to user
      AppToastUtil.showErrorToast(
        'You have been removed from the meeting by the host',
      );

      // Leave Agora channel
      _agoraService.leaveChannel();

      // Clear all meeting state
      _clearMeetingState();

      // Navigate back to home
      if (Get.context != null && Get.context!.mounted) {
        Get.offAllNamed(AppRouter.homeRoute);
      }
    } catch (e) {
      AppLogger.print('Error handling force removal: $e');
      // Even if there's an error, try to navigate back
      if (Get.context != null && Get.context!.mounted) {
        Get.offAllNamed(AppRouter.homeRoute);
      }
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
      AppLogger.print(
        'Warning: User $remoteUid not found in participants list',
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

      // Mark join request as joined if user was approved
      if (!isHost) {
        _firebaseService.markJoinRequestAsJoined(meetingId, currentUserId);
      }

      // Notify lifecycle manager that user is in a meeting
      _lifecycleManager.setMeetingStatus(
        isInMeeting: true,
        meetingId: meetingId,
        isHost: isHost,
      );

      // Start heartbeat to keep participant active
      _timeoutService.startHeartbeat(meetingId);

      startTimer();
      update();
    } catch (e) {
      AppLogger.print('Error in onJoinSuccess: $e');
    }
  }

  RtcEngineEventHandler _rtcEngineEventHandler(BuildContext context) {
    _agoraService.engine?.enableAudioVolumeIndication(
      interval: 200, // ms between reports
      smooth: 3, // smoothness (1–3)
      reportVad: true, // voice activity detection
    );
    return RtcEngineEventHandler(
      onUserJoined: (connection, remoteUid, elapsed) {
        // The participant stream will handle adding the user to the list.
        // The PTT logic will handle muting/unmuting.
        AppLogger.print('User joined: $remoteUid');
        if (isRecordingOn.value && remoteUid != currentUser.userId) {
          final userList =
              participants.map((e) => e.userId.toString()).toSet().toList();
          AppFirebaseService.instance.updateRecordingUserStreamList(
            meetingId,
            'individual',
            [...userList, remoteUid.toString()],
          );
        }
      },
      onUserOffline: (connection, remoteUid, reason) => removeUser(remoteUid),
      onJoinChannelSuccess: (connection, elapsed) {
        onJoinSuccess();
      },
      onLeaveChannel: (connection, stats) {
        isMeetEneded = true;
        update();
      },
      onAudioVolumeIndication: (rtc, speakers, speakerNumber, totalVolume) {
        if (speakers.isNotEmpty) {
          final loudest = speakers.reduce(
            (a, b) => (a.volume ?? 0) > (b.volume ?? 0) ? a : b,
          );
          if ((loudest.volume ?? 0) > 5) {
            // threshold
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
        print('❌ Agora error: $error,$message');
        AppToastUtil.showErrorToast('❌ Agora error: $error\n$message');
        AppFirebaseService.instance.verifyAgoraToken(
          channelName: meetingId,
          uid: AppLocalStorage.getUserDetails().userId,
          isHost: isHost,
        );
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

    // Clear meeting status from lifecycle manager
    _lifecycleManager.clearMeetingStatus();

    super.onClose();
  }

  void muteThisParticipantsForAllUser(ParticipantModel user) async {
    if (!isHost) return;
    await _agoraService.muteRemoteAudioStream(userId: user.userId, mute: true);
    await _firebaseService.muteParticipants(meetingId, user.userId, true);
    final index = participants.indexWhere((p) => p.userId == user.userId);
    if (index != -1) {
      participants[index] = participants[index].copyWith(isUserMuted: true);
      update();
    }
  }

  void unMuteThisParticipantsForAllUser(ParticipantModel user) async {
    if (!isHost) return;
    await _agoraService.muteRemoteAudioStream(userId: user.userId, mute: false);
    await _firebaseService.muteParticipants(meetingId, user.userId, false);
    final index = participants.indexWhere((p) => p.userId == user.userId);
    if (index != -1) {
      participants[index] = participants[index].copyWith(isUserMuted: false);
      update();
    }
  }

  /// Extend meeting by 30 minutes (convenience method)
  Future<void> extendMeetingTime() async {
    await extendMeetingWithOptions(
      additionalMinutes: 30,
      reason: 'Meeting extended by host during live session',
    );
  }

  /// Extend meeting with custom options (additional minutes and reason)
  Future<void> extendMeetingWithOptions({
    required int additionalMinutes,
    String? reason,
  }) async {
    try {
      // Show loading state
      update();

      // Use the enhanced Firebase service
      await _firebaseService.extendMeetingWithOptions(
        meetingId: meetingId,
        additionalMinutes: additionalMinutes,
        reason: reason ?? 'Meeting extended by host',
        notifyParticipants: true,
      );

      // Set extension flag to prevent end time warnings
      _hasExtended = true;
      _timerWarningShown = false; // Hide timer warning dialog
      _timerWarningDismissed =
          false; // Reset dismissal flag for future warnings

      // Show success message
      AppToastUtil.showSuccessToast(
        'Meeting extended by $additionalMinutes minutes',
      );

      // Note: Local model update will be handled by the real-time listener
      // This prevents race conditions and ensures consistency
    } catch (e) {
      AppLogger.print('Error extending meeting: $e');
      AppToastUtil.showErrorToast('Failed to extend meeting: $e');
    } finally {
      update();
    }
  }

  Future<void> toggleRecordingButton() async {
    if (isRecordingOn.value) {
      isRecordingOn.value =
          !(await _firebaseService.stopRecording(meetingId: meetingId) ??
              false);
      if (!isRecordingOn.value) {
        await _firebaseService.meetingsCollection
            .doc(meetingId)
            .collection('recordingTrack')
            .doc(recordingStartTimeEpoch.toString())
            .update({
              'stopTime': DateTime.now().toUtc().millisecondsSinceEpoch,
            });
        AppToastUtil.showSuccessToast('Recording stopped');
      }
      await Future.delayed(Duration(seconds: 2), () {});
      // await _firebaseService.queryAgoraRecordingStatus(meetingId, 'individual');
      await _firebaseService.queryAgoraRecordingStatus(meetingId, 'mix');
    } else {
      final token = await _firebaseService.getAgoraToken(
        channelName:
            meetingId.isNotEmpty ? meetingId : meetingModel.value.meetId,
        uid: currentUser.userId,
        isHost: isHost,
      );
      final result =
          await _firebaseService.startRecording(
            meetingId,
            token: agoraMeetingToken,
            userId: currentUser.userId,
          ) ??
          false;
      if (!result) {
        AppToastUtil.showErrorToast('Failed to start recording');
        return;
      }
      await Future.delayed(Duration(seconds: 2), () {});
      // final v1 = await _firebaseService.queryAgoraRecordingStatus(
      //   meetingId,
      //   'individual',
      // );
      final v2 = await _firebaseService.queryAgoraRecordingStatus(
        meetingId,
        'mix',
      );
      isRecordingOn.value =
          // v1 ||
          v2;

      if (isRecordingOn.value) {
        final startTime = DateTime.now().toUtc().millisecondsSinceEpoch;
        recordingStartTimeEpoch = startTime;
        await _firebaseService.meetingsCollection
            .doc(meetingId)
            .collection('recordingTrack')
            .doc(startTime.toString())
            .set({'startTime': startTime});
        AppToastUtil.showSuccessToast('Recording started');
      }
    }
    update();
  }
}
