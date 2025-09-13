import 'package:flutter/material.dart';
import 'package:secured_calling/core/models/meeting_model.dart';
import 'package:secured_calling/core/routes/app_router.dart';
import 'package:secured_calling/core/services/app_firebase_service.dart';
import 'package:secured_calling/core/services/app_local_storage.dart';
import 'package:secured_calling/core/services/meeting_listener_service.dart';
import 'package:secured_calling/core/theme/app_theme.dart';
import 'package:secured_calling/utils/app_logger.dart';

/// Centralized service for handling join requests
/// This ensures consistent behavior across all UI components
class JoinRequestService {
  static final JoinRequestService _instance = JoinRequestService._internal();
  factory JoinRequestService() => _instance;
  JoinRequestService._internal();

  final _firebaseService = AppFirebaseService.instance;
  final _meetingListenerService = MeetingListenerService();

  /// Request to join a meeting with approval flow
  /// 
  /// [context] - BuildContext for navigation and UI updates
  /// [meeting] - MeetingModel of the meeting to join
  /// [onStateChanged] - Callback for UI state updates (optional)
  /// 
  /// Returns true if request was sent successfully, false otherwise
  Future<bool> requestToJoinMeeting({
    required BuildContext context,
    required MeetingModel meeting,
    Function(bool isWaiting, String? errorMessage)? onStateChanged,
  }) async {
    try {
      AppLogger.print('Requesting to join meeting: ${meeting.meetId}');
      
      final userId = AppLocalStorage.getUserDetails().userId;
      
      // Send join request to Firebase
      await _firebaseService.requestToJoinMeeting(meeting.meetId, userId);
      
      // Update UI state
      onStateChanged?.call(true, null);
      
      // Show success message
      _showSuccessMessage(context, meeting.meetingName);
      
      // Start listening for approval/rejection
      _startListeningForResponse(
        context: context,
        meeting: meeting,
        userId: userId,
        onStateChanged: onStateChanged,
      );
      
      AppLogger.print('Join request sent successfully for meeting: ${meeting.meetId}');
      return true;
      
    } catch (e) {
      AppLogger.print('Error requesting to join meeting: $e');
      final errorMessage = 'Error requesting to join: $e';
      onStateChanged?.call(false, errorMessage);
      _showErrorMessage(context, errorMessage);
      return false;
    }
  }

  /// Start listening for approval/rejection response
  void _startListeningForResponse({
    required BuildContext context,
    required MeetingModel meeting,
    required int userId,
    Function(bool isWaiting, String? errorMessage)? onStateChanged,
  }) {
    _meetingListenerService.startListening(
      meetingId: meeting.meetId,
      userId: userId,
      context: context,
      onApprovalReceived: () {
        AppLogger.print('Join request approved for meeting: ${meeting.meetId}');
        onStateChanged?.call(false, null);
        _navigateToMeetingRoom(context, meeting);
      },
      onRejectionReceived: () {
        AppLogger.print('Join request rejected for meeting: ${meeting.meetId}');
        const errorMessage = 'Your request to join the meeting has been rejected by the host.';
        onStateChanged?.call(false, errorMessage);
        _showErrorMessage(context, errorMessage);
      },
    );
  }

  /// Navigate to meeting room
  void _navigateToMeetingRoom(BuildContext context, MeetingModel meeting) {
    if (!context.mounted) return;
    
    AppLogger.print('Navigating to meeting room: ${meeting.meetId}');
    
    Navigator.pushNamed(
      context,
      AppRouter.meetingRoomRoute,
      arguments: {
        'channelName': meeting.channelName,
        'isHost': meeting.hostId == AppLocalStorage.getUserDetails().firebaseUserId,
        'meetingId': meeting.meetId,
      },
    );
  }

  /// Show success message
  void _showSuccessMessage(BuildContext context, String meetingName) {
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Request sent to join $meetingName meeting'),
        backgroundColor: AppTheme.successColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Show error message
  void _showErrorMessage(BuildContext context, String message) {
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.errorColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Stop listening for join request responses
  /// Call this when the UI component is disposed or when canceling a request
  void stopListening() {
    _meetingListenerService.stopListening();
  }

  /// Check if currently listening for responses
  bool get isListening => _meetingListenerService.isListening;
}
