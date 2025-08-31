import 'dart:async';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  
  // Extension history
  final isExtensionHistoryLoading = false.obs;
  final extensionHistory = <Map<String, dynamic>>[].obs;
  
  // Stream subscriptions
  StreamSubscription<DocumentSnapshot>? _meetingStreamSubscription;
  StreamSubscription<QuerySnapshot>? _extensionsStreamSubscription;

  MeetingDetailController({required this.meetingId});

  @override
  void onInit() {
    super.onInit();
    loadMeetingDetails();
    _initializeRealTimeUpdates();
    _initializeExtensionHistory();
  }

  @override
  void onClose() {
    _meetingStreamSubscription?.cancel();
    _extensionsStreamSubscription?.cancel();
    super.onClose();
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

      _meetingStreamSubscription = _meetingService.getMeetingStream(meetingId).listen(
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

  /// Initialize extension history
  void _initializeExtensionHistory() {
    try {
      isExtensionHistoryLoading.value = true;

      _extensionsStreamSubscription = _meetingService.getMeetingExtensionsStream(meetingId).listen(
        (snapshot) {
          final extensions = snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {
              'additionalMinutes': data['additionalMinutes'] as int? ?? 0,
              'reason': data['reason'] as String?,
              'extendedAt': data['extendedAt']?.toDate(),
              'extendedBy': data['extendedBy'] as String?,
            };
          }).toList();
          
          extensionHistory.value = extensions;
          isExtensionHistoryLoading.value = false;
        },
        onError: (error) {
          isExtensionHistoryLoading.value = false;
          AppLogger.print('Extension history error: $error');
        },
      );
    } catch (e) {
      isExtensionHistoryLoading.value = false;
      AppLogger.print('Error initializing extension history: $e');
    }
  }

  /// Refresh real-time updates
  Future<void> refreshRealTimeUpdates() async {
    _meetingStreamSubscription?.cancel();
    _initializeRealTimeUpdates();
  }

  /// Refresh extension history
  Future<void> refreshExtensionHistory() async {
    _extensionsStreamSubscription?.cancel();
    _initializeExtensionHistory();
  }

  /// Handle meeting extension
  void onMeetingExtended() {
    // Refresh all data when meeting is extended
    refreshMeetingDetails();
    refreshExtensionHistory();
    
    // Show success message
    AppToastUtil.showSuccessToast('Meeting extended successfully!');
  }

  /// Check if user can extend meeting
  Future<bool> canExtendMeeting() async {
    try {
      return await _meetingService.canExtendMeeting(meetingId);
    } catch (e) {
      AppLogger.print('Error checking extend permission: $e');
      return false;
    }
  }

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
