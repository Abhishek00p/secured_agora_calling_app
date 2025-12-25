import 'dart:async';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart';
import 'package:secured_calling/core/extensions/app_int_extension.dart';
import 'package:secured_calling/core/models/recording_file_model.dart';
import 'package:secured_calling/core/services/app_firebase_service.dart';
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
  RxList<RecordingFileModel> individualRecordings = <RecordingFileModel>[].obs;
  // Stream subscriptions
  StreamSubscription<DocumentSnapshot>? _meetingStreamSubscription;

  MeetingDetailController({required this.meetingId});
  RxBool isMixRecordingLoading = false.obs;
  RxBool isIndividualRecordingLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadMeetingDetails();
    _initializeRealTimeUpdates();
    fetchIndividualRecordings();
    // fetchAllIndividualRecordings();
    fetchMixRecordings();
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

  // Future<void> fetchMixRecordings() async {
  //   try {
  //     final items = <RecordingFileModel>[];
  //     final firestoreRecordingTrack =
  //         (await AppFirebaseService.instance.meetingsCollection
  //                 .doc(meetingId)
  //                 .collection('recordingTrack')
  //                 .get())
  //             .docs;
  //     final allRecordings =
  //         await AppFirebaseService.instance.getAllMixRecordings(meetingId) ??
  //         [];
  //     for (final doc in firestoreRecordingTrack) {
  //       final itemData = doc.data();
  //       final startTime =
  //           itemData['startTime'] != null
  //               ? (itemData['startTime'] as int).toDateTime
  //               : DateTime.now();
  //       final stopTime =
  //           itemData['stopTime'] != null
  //               ? (itemData['stopTime'] as int).toDateTime
  //               : DateTime.now();

  //       final item = allRecordings.firstWhere(
  //         (element) =>
  //             (element.lastModified ?? DateTime.now()).isAfter(startTime) &&
  //             (element.lastModified ?? DateTime.now()).isBefore(stopTime),
  //         orElse: () => RecordingFileModel.empty(),
  //       );
  //       if (item.isNotEmpty) {
  //         items.add(
  //           RecordingFileModel(
  //             key: item.key,
  //             playableUrl: item.playableUrl,
  //             lastModified: item.lastModified,
  //             startTime: startTime,
  //             stopTime: stopTime,
  //             size: item.size,
  //           ),
  //         );
  //       }
  //     }
  //     mixRecordings.value = items;
  //   } catch (e) {
  //     AppLogger.print("Failed to fetch mix recording in controller : $e");
  //     mixRecordings.clear();
  //   }
  // }

  Future<void> fetchMixRecordings() async {
    try {
      isMixRecordingLoading.value = true;
      final items = <RecordingFileModel>[];

      final firestoreRecordingTrack =
          (await AppFirebaseService.instance.meetingsCollection
                  .doc(meetingId)
                  .collection('recordingTrack')
                  .get())
              .docs;

      final allRecordings =
          await AppFirebaseService.instance.getAllMixRecordings(meetingId) ??
          [];

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

          return recTime.isAfter(startTime) && recTime.isBefore(stopTime);
        });

        for (final item in matched) {
          items.add(
            RecordingFileModel(
              key: item.key,
              playableUrl: item.playableUrl,
              lastModified: item.lastModified,
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

      final items = <RecordingFileModel>[];

      // 🔹 fetch all individual recordings from backend
      final allIndividualRecordings =
          await AppFirebaseService.instance.getAllIndividualRecordings(
            meetingId,
          ) ??
          [];

      // 🔹 group recordings by userId for faster lookup
      final recordingsByUser = <String, List<RecordingFileModel>>{};

      for (final rec in allIndividualRecordings) {
        if (rec.userId == null) continue;
        recordingsByUser.putIfAbsent(rec.userId!.toString(), () => []).add(rec);
      }

      // 🔹 fetch participants
      final participantsSnap =
          await AppFirebaseService.instance.meetingsCollection
              .doc(meetingId)
              .collection('participants')
              .get();

      for (final participantDoc in participantsSnap.docs) {
        final userId = participantDoc.id;

        final userRecordings = recordingsByUser[userId];
        if (userRecordings == null || userRecordings.isEmpty) continue;

        // 🔹 fetch speaking events for this user
        final speakingEventsSnap =
            await AppFirebaseService.instance.meetingsCollection
                .doc(meetingId)
                .collection('participants')
                .doc(userId)
                .collection('speakingEvents')
                .get();

        for (final eventDoc in speakingEventsSnap.docs) {
          final data = eventDoc.data();

          if (data['start'] == null || data['stop'] == null) continue;

          final startTime = (data['start'] as int).toDateTime;
          final stopTime = (data['stop'] as int).toDateTime;

          // ✅ match recordings inside speaking window
          final matched = userRecordings.where((rec) {
            final recTime = rec.recordingTime;
            if (recTime == null) return false;

            return recTime.isAfter(startTime) && recTime.isBefore(stopTime);
          });

          for (final rec in matched) {
            items.add(
              RecordingFileModel(
                key: rec.key,
                playableUrl: rec.playableUrl,
                lastModified: rec.lastModified,
                recordingTime: rec.recordingTime,
                startTime: startTime,
                stopTime: stopTime,
                userId: int.tryParse(userId),
                userName: rec.userName,
                size: rec.size,
              ),
            );
          }
        }
      }

      individualRecordings.value = items;
      isIndividualRecordingLoading.value = false;
    } catch (e, st) {
      AppLogger.print(
        "Failed to fetch individual recording in controller : $e\n$st",
      );
      individualRecordings.clear();
      isIndividualRecordingLoading.value = false;
    }
  }

  //   Future<List<dynamic>?> fetchIndividualRecordingsByUserId(
  //     String userId,
  //   ) async {
  //     try {
  //       return await AppFirebaseService.instance
  //               .getAllIndividualRecordingsByUserId(meetingId, userId: userId) ??
  //           [];
  //     } catch (e) {
  //       AppLogger.print(
  //         "Failed to fetch individual b userid recording in controller : $e",
  //       );
  //     }
  //   }
}
