import 'dart:async';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  // Stream subscriptions
  StreamSubscription<DocumentSnapshot>? _meetingStreamSubscription;

  MeetingDetailController({required this.meetingId});

  @override
  void onInit() {
    super.onInit();
    loadMeetingDetails();
    _initializeRealTimeUpdates();
  }

  @override
  void onClose() {
    _meetingStreamSubscription?.cancel();
    super.onClose();
  }

  fetchRecordings() async {
    try {
      final docName = '${meetingId}_individual';
      final docName2 = '${meetingId}_mix';
      final result1 =
          (await AppFirebaseService.instance.recordingsCollection
                  .doc(docName)
                  .get())
              .data();
      final result2 =
          (await AppFirebaseService.instance.recordingsCollection
                  .doc(docName2)
                  .get())
              .data();
      String recording1Url = '';
      String recording2Url = '';
      if (result1 != null && result1 is Map<String, dynamic>) {
        recording1Url = result1['m3u8Path'] ?? '';
      }
      if (result2 != null && result2 is Map<String, dynamic>) {
        recording2Url = result2['m3u8Path'] ?? '';
      }
      AppLogger.print('Fetched 1st recording URL: $recording1Url');
      AppLogger.print('Fetched 2nd recording URL: $recording2Url');
    } catch (e) {
      AppLogger.print('Error fetching recordings: $e');
    }
  }

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
}
