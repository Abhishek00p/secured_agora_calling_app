import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:secured_calling/core/models/app_user_model.dart';
import 'package:secured_calling/core/models/individual_recording_model.dart';
import 'package:secured_calling/core/models/recording_file_model.dart';
import 'package:secured_calling/core/services/app_firebase_service.dart';
import 'package:secured_calling/core/services/app_local_storage.dart';
import 'package:secured_calling/features/meeting/services/meeting_detail_service.dart';
import 'package:secured_calling/models/meeting_detail.dart';
import 'package:secured_calling/utils/app_logger.dart';
import 'package:secured_calling/utils/app_tost_util.dart';

class MeetingDetailController extends GetxController {
  final String meetingId;
  final MeetingDetailService _meetingService = MeetingDetailService();

  // Observable variables
  final meetingDetail = Rxn<MeetingDetail>();
  final isLoading = false.obs;
  final hasError = false.obs;
  final errorMessage = RxnString();

  // Real-time updates
  final isRealTimeLoading = false.obs;
  final realTimeError = RxnString();
  final lastUpdated = Rxn<DateTime>();
  RxInt currentTabIndex = 0.obs;

  RxList<MixRecordingModel> mixRecordings = <MixRecordingModel>[].obs;
  RxList<SpeakingEventModel> individualRecordings = <SpeakingEventModel>[].obs;
  // Stream subscriptions
  StreamSubscription<DocumentSnapshot>? _meetingStreamSubscription;

  MeetingDetailController({required this.meetingId});
  RxBool isMixRecordingLoading = false.obs;
  RxBool isIndividualRecordingLoading = false.obs;

  AppUser loggedInUserData = AppLocalStorage.getUserDetails();

  bool get isCurrentUserHost => meetingDetail.value?.hostId == loggedInUserData.userId;

  bool get canCurrentUserSeeMixRecording => loggedInUserData.canSeeMixRecording;

  @override
  void onInit() {
    super.onInit();
    loadMeetingDetails().then((_) {
      fetchIndividualRecordings();
      // if (canCurrentUserSeeMixRecording) {
      fetchMixRecordings();
      // }
    });
    _initializeRealTimeUpdates();
    // fetchAllIndividualRecordings();
  }

  @override
  void onClose() {
    _meetingStreamSubscription?.cancel();
    super.onClose();
  }

  // void fetchAllIndividualRecordings() async {
  //   final details = await _meetingService.fetchMeetingDetail(meetingId);

  //   for (int i = 0; i < (details.participants.length ?? 0); i++) {
  //     final participantUserId = details.participants[i].userId ?? '';
  //     print("Participant User ID : $participantUserId \n");
  //     individualRecordings.value +=
  //         (await fetchIndividualRecordingsByUserId(participantUserId) ?? [])
  //             .map((e) => Map<String, dynamic>.from(e))
  //             .toList();
  //   }
  // }

  /// Load meeting details
  Future<void> loadMeetingDetails() async {
    try {
      isLoading.value = true;
      hasError.value = false;
      errorMessage.value = null;

      final details = await _meetingService.fetchMeetingDetail(meetingId);
      meetingDetail.value = details;

      AppLogger.print('Meeting details loaded successfully');
    } catch (e) {
      hasError.value = true;
      errorMessage.value = e.toString();
      AppLogger.print('Error loading meeting details: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Refresh meeting details
  Future<void> refreshMeetingDetails() async {
    await loadMeetingDetails();
    await Future.wait([fetchIndividualRecordings(), fetchMixRecordings()]);
  }

  /// Refresh participants list
  Future<void> refreshParticipants() async {
    try {
      final details = await _meetingService.fetchMeetingDetail(meetingId);

      meetingDetail.value = details;
      AppToastUtil.showSuccessToast('Participants refreshed');
    } catch (e) {
      AppToastUtil.showErrorToast('Failed to refresh participants: $e');
    }
  }

  /// Initialize real-time meeting updates
  void _initializeRealTimeUpdates() {
    try {
      isRealTimeLoading.value = true;
      realTimeError.value = null;

      _meetingStreamSubscription = _meetingService
          .getMeetingStream(meetingId)
          .listen(
            (snapshot) {
              if (snapshot.exists) {
                final data = snapshot.data() as Map<String, dynamic>?;
                if (data != null) {
                  final lastExtendedAt = data['lastExtendedAt'];
                  if (lastExtendedAt != null) {
                    lastUpdated.value = lastExtendedAt.toDate();
                  }
                }
              }
              isRealTimeLoading.value = false;
            },
            onError: (error) {
              realTimeError.value = error.toString();
              isRealTimeLoading.value = false;
              AppLogger.print('Real-time updates error: $error');
            },
          );
    } catch (e) {
      realTimeError.value = e.toString();
      isRealTimeLoading.value = false;
      AppLogger.print('Error initializing real-time updates: $e');
    }
  }

  // /// Refresh real-time updates
  // Future<void> refreshRealTimeUpdates() async {
  //   _meetingStreamSubscription?.cancel();
  //   _initializeRealTimeUpdates();
  // }

  /// Get meeting status for UI updates
  String get meetingStatus {
    final meeting = meetingDetail.value;
    if (meeting == null) return 'loading';
    return meeting.status;
  }

  /// Get participant count
  int get participantCount {
    final meeting = meetingDetail.value;
    return meeting?.participants.length ?? 0;
  }

  /// Check if meeting is active
  bool get isMeetingActive {
    final status = meetingStatus;
    return status == 'ongoing' || status == 'upcoming';
  }

  /// Check if meeting has ended
  bool get isMeetingEnded {
    return meetingStatus == 'ended';
  }

  /// Check if meeting is upcoming
  bool get isMeetingUpcoming {
    return meetingStatus == 'upcoming';
  }

  Future<void> fetchMixRecordings() async {
    try {
      if (!canCurrentUserSeeMixRecording) {
        debugPrint("Current user does not have permission to see mix recording, skipping fetchMixRecordings");
        return;
      }
      isMixRecordingLoading.value = true;
      final allRecordingsTrack = (await AppFirebaseService.instance.meetingsCollection.doc(meetingId).collection('recordingTrack').get()).docs;
      if (allRecordingsTrack.isEmpty) {
        AppLogger.print("No recording tracks found for meeting : $meetingId");
        mixRecordings.clear();
        isMixRecordingLoading.value = false;
        return;
      }
      List<MixRecordingModel> list = [];
      for (Map<String, dynamic> item in allRecordingsTrack.map((e) => e.data())) {
        final startTime = item['startTime'] as int? ?? 0;
        final endTime = item['stopTime'] as int? ?? 0;
        if (startTime == 0 || endTime == 0) {
          AppLogger.print(" =======> start or endtime is 0 , skipping fetch recording for this track : ${item['trackId']}");
          continue;
        }
        final recordingUrl = await AppFirebaseService.instance.getMeetingRecordingM4aUrl(meetingId: meetingId, start: startTime, end: endTime);
        if (recordingUrl.trim().isNotEmpty) {
          debugPrint(
            " =======> fetched mix recording for track with start time : ${item['startTime']} and end time : ${item['stopTime']} with url : $recordingUrl",
          );
          list.add(MixRecordingModel(playableUrl: recordingUrl, startTime: startTime, endTime: endTime));
        } else {
          debugPrint(" =======> recording url empty for track with start time : ${item['startTime']} and end time : ${item['stopTime']} ");
        }
      }
      mixRecordings.value = list;

      isMixRecordingLoading.value = false;
    } catch (e, st) {
      AppLogger.print("Failed to fetch mix recording in controller : $e\n$st");
      mixRecordings.clear();
      isMixRecordingLoading.value = false;
    }
  }

  Future<void> fetchIndividualRecordings() async {
    try {
      isIndividualRecordingLoading.value = true;
      final allRecordingTracks = (await AppFirebaseService.instance.meetingsCollection.doc(meetingId).collection('recordingTrack').get()).docs;
      List<SpeakingEventModel> list = [];
      individualRecordings.clear();

      for (var item in allRecordingTracks) {
        final itemData = item.data();
        final startTime = itemData['startTime'] as int? ?? 0;
        final endTime = itemData['stopTime'] as int? ?? 0;
        if (startTime == 0 || endTime == 0) {
          AppLogger.print(" =======> start or endtime is 0 , skipping fetch recording for this track : ${item.id}");
          continue;
        }
        final speakingEventsOfThisTrack =
            (await AppFirebaseService.instance.meetingsCollection
                    .doc(meetingId)
                    .collection('recordingTrack')
                    .doc(item.id)
                    .collection('speakingEvents')
                    .get())
                .docs;
        for (var speakingEvent in speakingEventsOfThisTrack) {
          final data = speakingEvent.data();
          final eventStart = data['start'];
          final eventStop = data['stop'];
          if (eventStart == null || eventStart == 0 || eventStop == null || eventStop == 0) {
            continue;
          }
          final evStart = eventStart as int;
          final evStop = eventStop as int;
          if (isCurrentUserHost || loggedInUserData.userId.toString() == data['userId'].toString()) {
            AppLogger.print(" =======> fetching recording for user : ${data['userName']} with id : ${data['userId']} for track : ${item.id}");
          } else {
            AppLogger.print(
              " =======> skipping recording for user : ${data['userName']} with id : ${data['userId']} for track : ${item.id} as current user is not host and recording is not of current user",
            );
            continue;
          }
          final trimmedUrl = await AppFirebaseService.instance.getTrimmedRecordingM4aUrl(
            meetingId: meetingId,
            recordingFullStartTime: startTime,
            recordingFullEndTime: endTime,
            trimmedStartTime: evStart,
            trimmedEndTime: evStop,
          );
          if (trimmedUrl.trim().isEmpty) {
            AppLogger.print(' =======> trimmed m4a url empty for track ${item.id} speaking event');
            continue;
          }
          list.add(
            SpeakingEventModel(
              userId: data['userId'].toString(),
              userName: data['userName'],
              startTime: evStart,
              endTime: evStop,
              recordingUrl: trimmedUrl,
              trackStartTime: itemData['startTime'],
              trackStopTime: itemData['stopTime'],
            ),
          );
        }
      }
      list.sort((a, b) => a.userName.toLowerCase().compareTo(b.userName.toLowerCase()));
      individualRecordings.value = list;
    } catch (e, st) {
      AppLogger.print("Failed to fetchIndividualRecordings : $e\n$st");
      individualRecordings.clear();
    } finally {
      isIndividualRecordingLoading.value = false;
    }
  }
  // Future<void> getAllUserWiseRecordings() async {
  //   final eventsSnap =
  //       await FirebaseFirestore.instance.collectionGroup('speakingEvents').where('meetingId', isEqualTo: meetingId).orderBy('start').get();

  //   List<RecordingTrackModel> data = [];
  //   for (var doc in eventsSnap.docs) {
  //     final docData = RecordingTrackModel.fromJson(doc.data());
  //     final recordedFile = mixRecordings.firstWhereOrNull(
  //       (e) => (e.startTime?.isBefore(docData.startTime.toDateTime) ?? false) && (e.stopTime?.isAfter(docData.endTime.toDateTime) ?? false),
  //     );

  //     if (recordedFile != null) {
  //       data.add(
  //         IndividualRecordingModel(
  //               url: recordedFile.playableUrl,
  //               startTime: docData.startTime.toDateTime,
  //               stopTime: docData.endTime.toDateTime,
  //               recordingTime: recordedFile.recordingTime,
  //               userId: int.tryParse(doc.reference.parent.parent?.id ?? '0'),
  //             )
  //             as RecordingTrackModel,
  //       );
  //     }
  //   }
  // }
}
