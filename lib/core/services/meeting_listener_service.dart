import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:secured_calling/utils/app_tost_util.dart';
import 'package:secured_calling/core/services/app_firebase_service.dart';

class MeetingListenerService {
  static final MeetingListenerService _instance =
      MeetingListenerService._internal();
  factory MeetingListenerService() => _instance;
  MeetingListenerService._internal();

  final _firebaseService = AppFirebaseService.instance;
  StreamSubscription<DocumentSnapshot>? _joinRequestListener;
  StreamSubscription<QuerySnapshot>? _participantsListener;
  String? _currentMeetingId;
  int? _currentUserId;
  VoidCallback? _onApprovalReceived;
  VoidCallback? _onRejectionReceived;

  /// Start listening for join request status changes using sub-collection
  void startListening({
    required String meetingId,
    required int userId,
    required BuildContext context,
    VoidCallback? onApprovalReceived,
    VoidCallback? onRejectionReceived,
  }) {
    // Stop any existing listeners before starting new ones
    _stopListening();

    _currentMeetingId = meetingId;
    _currentUserId = userId;
    _onApprovalReceived = onApprovalReceived;
    _onRejectionReceived = onRejectionReceived;

    _startJoinRequestListener();
  }

  /// Start listening for join request status changes
  void _startJoinRequestListener() {
    if (_currentMeetingId == null || _currentUserId == null) return;

    _joinRequestListener = _firebaseService
        .getJoinRequestStream(_currentMeetingId!, _currentUserId!)
        .listen(
          (docSnapshot) {
            if (!docSnapshot.exists) {
              print('Join request document not found');
              return;
            }

            final data = docSnapshot.data() as Map<String, dynamic>?;
            if (data == null) return;

            final status = data['status'] as String?;
            print('Join request status changed to: $status');

            switch (status) {
              case 'accepted':
                print('Join request approved');
                _stopListening();
                _onApprovalReceived?.call();
                break;
              case 'rejected':
                print('Join request rejected');
                _stopListening();
                _onRejectionReceived?.call();
                AppToastUtil.showErrorToast(
                  'Your request to join the meeting has been rejected by the host.',
                );
                break;
              case 'joined':
                print('User has joined the meeting');
                // This status is set when user successfully joins
                break;
              case 'pending':
                print('Still waiting for host approval');
                break;
              default:
                print('Unknown join request status: $status');
            }
          },
          onError: (error) {
            print('Join request listener error: $error');
            AppToastUtil.showErrorToast('Error listening for join request updates');
          },
        );
  }

  /// Stop all listeners
  void _stopListening() {
    _joinRequestListener?.cancel();
    _participantsListener?.cancel();
    _joinRequestListener = null;
    _participantsListener = null;
  }

  /// Public method to stop listening
  void stopListening() {
    _stopListening();
    _currentMeetingId = null;
    _currentUserId = null;
    _onApprovalReceived = null;
    _onRejectionReceived = null;
  }

  /// Check if currently listening
  bool get isListening =>
      _joinRequestListener != null || _participantsListener != null;

  /// Dispose all resources
  void dispose() {
    stopListening();
  }
}
