import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:secured_calling/utils/app_tost_util.dart';
import 'package:secured_calling/core/services/app_firebase_service.dart';
import 'package:secured_calling/utils/app_logger.dart';

class MeetingListenerService {
  static final MeetingListenerService _instance = MeetingListenerService._internal();
  factory MeetingListenerService() => _instance;
  MeetingListenerService._internal();

  final _firebaseService = AppFirebaseService.instance;
  StreamSubscription<DocumentSnapshot>? _joinRequestListener;
  StreamSubscription<QuerySnapshot>? _participantsListener;
  Timer? _timeoutTimer;
  String? _currentMeetingId;
  int? _currentUserId;
  VoidCallback? _onApprovalReceived;
  VoidCallback? _onRejectionReceived;
  VoidCallback? _onTimeoutReached;

  /// Start listening for join request status changes using sub-collection
  void startListening({
    required String meetingId,
    required int userId,
    required BuildContext context,
    VoidCallback? onApprovalReceived,
    VoidCallback? onRejectionReceived,
    VoidCallback? onTimeoutReached,
  }) {
    // Stop any existing listeners before starting new ones
    _stopListening();

    _currentMeetingId = meetingId;
    _currentUserId = userId;
    _onApprovalReceived = onApprovalReceived;
    _onRejectionReceived = onRejectionReceived;
    _onTimeoutReached = onTimeoutReached;

    _startJoinRequestListener();
    _startTimeoutTimer();
  }

  /// Start listening for join request status changes
  void _startJoinRequestListener() {
    if (_currentMeetingId == null || _currentUserId == null) return;

    _joinRequestListener = _firebaseService
        .getJoinRequestStream(_currentMeetingId!, _currentUserId!)
        .listen(
          (docSnapshot) {
            if (!docSnapshot.exists) {
              AppLogger.print('Join request document not found');
              return;
            }

            final data = docSnapshot.data() as Map<String, dynamic>?;
            if (data == null) return;

            final status = data['status'] as String?;
            AppLogger.print('Join request status changed to: $status');

            switch (status) {
              case 'accepted':
                AppLogger.print('Join request approved');
                _stopListening();
                _onApprovalReceived?.call();
                break;
              case 'rejected':
                AppLogger.print('Join request rejected');
                _stopListening();
                _onRejectionReceived?.call();
                AppToastUtil.showErrorToast('Your request to join the meeting has been rejected by the host.');
                break;
              case 'joined':
                AppLogger.print('User has joined the meeting');
                // This status is set when user successfully joins
                break;
              case 'pending':
                AppLogger.print('Still waiting for host approval');
                break;
              default:
                AppLogger.print('Unknown join request status: $status');
            }
          },
          onError: (error) {
            AppLogger.print('Join request listener error: $error');
            AppToastUtil.showErrorToast('Error listening for join request updates');
          },
        );
  }

  /// Start timeout timer for join request (1 minute)
  void _startTimeoutTimer() {
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(const Duration(minutes: 1), () {
      AppLogger.print('Join request timeout reached - no response from host');
      _handleTimeout();
    });
  }

  /// Handle timeout scenario
  void _handleTimeout() {
    AppLogger.print('Join request timed out after 1 minute');

    // Stop all listeners
    _stopListening();

    // Show timeout message to user
    AppToastUtil.showErrorToast('Your join request timed out. The host did not respond within 1 minute.');

    // Call timeout callback
    _onTimeoutReached?.call();
  }

  /// Stop all listeners and timers
  void _stopListening() {
    _joinRequestListener?.cancel();
    _participantsListener?.cancel();
    _timeoutTimer?.cancel();
    _joinRequestListener = null;
    _participantsListener = null;
    _timeoutTimer = null;
  }

  /// Public method to stop listening
  void stopListening() {
    _stopListening();
    _currentMeetingId = null;
    _currentUserId = null;
    _onApprovalReceived = null;
    _onRejectionReceived = null;
    _onTimeoutReached = null;
  }

  /// Check if currently listening
  bool get isListening => _joinRequestListener != null || _participantsListener != null;

  /// Dispose all resources
  void dispose() {
    stopListening();
  }
}
