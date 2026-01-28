import 'dart:async';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart';
import 'package:secured_calling/core/extensions/app_int_extension.dart';
import 'package:secured_calling/core/models/individual_recording_model.dart';
import 'package:secured_calling/core/models/recording_file_model.dart';
import 'package:secured_calling/core/models/recording_track_model.dart';
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

  RxList<RecordingFileModel> mixRecordings = <RecordingFileModel>[].obs;
  RxList<SpeakingEventModel> individualRecordings = <SpeakingEventModel>[].obs;
  // Stream subscriptions
  StreamSubscription<DocumentSnapshot>? _meetingStreamSubscription;

  MeetingDetailController({required this.meetingId});
  RxBool isMixRecordingLoading = false.obs;
  RxBool isIndividualRecordingLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadMeetingDetails().then((_) {
      if (meetingDetail.value?.hostId == AppLocalStorage.getUserDetails().userId) {
        fetchIndividualRecordings();
      }
      fetchMixRecordings();
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
  }

  /// Refresh participants list
  Future<void> refreshParticipants() async {
    try {
      final details = await _meetingService.fetchMeetingDetail(meetingId);
      if (details != null) {
        meetingDetail.value = details;
        AppToastUtil.showSuccessToast('Participants refreshed');
      }
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
      isMixRecordingLoading.value = true;
      final items = <RecordingFileModel>[];

      final firestoreRecordingTrack = (await AppFirebaseService.instance.meetingsCollection.doc(meetingId).collection('recordingTrack').get()).docs;

      final allRecordings = await AppFirebaseService.instance.getAllMixRecordings(meetingId) ?? [];

      for (final doc in firestoreRecordingTrack) {
        final itemData = doc.data();

        if (itemData['startTime'] == null || itemData['stopTime'] == null) {
          continue;
        }

        final startTime = (itemData['startTime'] as int).toDateTime;
        final stopTime = (itemData['stopTime'] as int).toDateTime;

        // ✅ collect ALL recordings inside this time window
        final matched = allRecordings.where((element) {
          final recTime = element.recordingTime;
          if (recTime == null) return false;

          return recTime.isAfter(startTime) && recTime.isBefore(stopTime.add(Duration(minutes: 1)));
        });

        for (final item in matched) {
          items.add(
            RecordingFileModel(
              key: item.key,
              playableUrl: item.playableUrl,
              recordingTime: item.recordingTime,
              startTime: startTime,
              stopTime: stopTime,
              size: item.size,
            ),
          );
        }
      }

      mixRecordings.value = items;
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

      individualRecordings.value = await AppFirebaseService.instance.getAllMeetingRecordings(meetingId: meetingId);
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
