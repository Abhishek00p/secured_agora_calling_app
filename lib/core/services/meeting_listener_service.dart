import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:secured_calling/core/routes/app_router.dart';
import 'package:secured_calling/core/services/app_local_storage.dart';
import 'package:secured_calling/utils/app_tost_util.dart';

class MeetingListenerService {
  static final MeetingListenerService _instance = MeetingListenerService._internal();
  factory MeetingListenerService() => _instance;
  MeetingListenerService._internal();

  StreamSubscription<DocumentSnapshot>? _meetingDataListener;
  StreamSubscription<QuerySnapshot>? _participantsListener;
  String? _currentMeetingId;
  int? _currentUserId;
  BuildContext? _context;
  VoidCallback? _onApprovalReceived;
  VoidCallback? _onRejectionReceived;

  /// Start listening for meeting data and participants changes
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
    _context = context;
    _onApprovalReceived = onApprovalReceived;
    _onRejectionReceived = onRejectionReceived;

    _startMeetingDataListener();
    _startParticipantsListener();
  }

  /// Start listening for meeting data changes (pendingApprovals, etc.)
  void _startMeetingDataListener() {
    if (_currentMeetingId == null) return;

    _meetingDataListener = FirebaseFirestore.instance
        .collection('meetings')
        .doc(_currentMeetingId!)
        .snapshots()
        .listen(
      (meetingSnapshot) {
        if (!meetingSnapshot.exists) return;
        
        final meetingData = meetingSnapshot.data()!;
        final pendingRequests = List<String>.from(
          meetingData['pendingApprovals'] ?? [],
        );

        // Check if user is no longer in pending requests
        if (!pendingRequests.contains(_currentUserId.toString())) {
          _checkParticipantStatus();
        } else {
          print('User still waiting for host approval: $pendingRequests');
        }
      },
      onError: (error) {
        print('Meeting data listener error: $error');
        AppToastUtil.showErrorToast('Error listening for meeting updates');
      },
    );
  }

  /// Start listening for participants collection changes
  void _startParticipantsListener() {
    if (_currentMeetingId == null || _currentUserId == null) return;

    _participantsListener = FirebaseFirestore.instance
        .collection('meetings')
        .doc(_currentMeetingId!)
        .collection('participants')
        .snapshots()
        .listen(
      (participantsSnapshot) {
        final participantData = participantsSnapshot.docs
            .where((doc) => doc.id == _currentUserId.toString())
            .firstOrNull
            ?.data() ?? {};

        if (participantData.isNotEmpty) {
          _checkParticipantStatus();
        }
      },
      onError: (error) {
        print('Participants listener error: $error');
        AppToastUtil.showErrorToast('Error listening for participant updates');
      },
    );
  }

  /// Check the current status of the participant and take appropriate action
  void _checkParticipantStatus() async {
    if (_currentMeetingId == null || _currentUserId == null || _context == null) return;

    try {
      // Get fresh meeting data
      final meetingDoc = await FirebaseFirestore.instance
          .collection('meetings')
          .doc(_currentMeetingId!)
          .get();

      if (!meetingDoc.exists) return;

      final meetingData = meetingDoc.data()!;
      final pendingRequests = List<String>.from(
        meetingData['pendingApprovals'] ?? [],
      );

      // Get fresh participant data
      final participantDoc = await FirebaseFirestore.instance
          .collection('meetings')
          .doc(_currentMeetingId!)
          .collection('participants')
          .doc(_currentUserId.toString())
          .get();

      final participantData = participantDoc.data() ?? {};

      // Check if user is approved and active
      if (!pendingRequests.contains(_currentUserId.toString()) &&
          participantData.isNotEmpty &&
          participantData['isActive'] == true) {
        
        // User has been approved and is active
        _stopListening();
        _onApprovalReceived?.call();
        
        if (_context != null && _context!.mounted) {
          Navigator.pushNamed(
            _context!,
            AppRouter.meetingRoomRoute,
            arguments: {
              'channelName': meetingData['channelName'],
              'isHost': meetingData['hostId'] == 
                  AppLocalStorage.getUserDetails().firebaseUserId,
              'meetingId': _currentMeetingId,
            },
          );
        }
      } else if (!pendingRequests.contains(_currentUserId.toString()) &&
          (participantData.isEmpty || participantData['isActive'] == false)) {
        
        // User has been rejected
        _stopListening();
        _onRejectionReceived?.call();
        
        AppToastUtil.showErrorToast(
          'Your request to join the meeting has been rejected by the host.',
        );
      }
    } catch (e) {
      print('Error checking participant status: $e');
      AppToastUtil.showErrorToast('Error checking meeting status');
    }
  }

  /// Stop all listeners
  void _stopListening() {
    _meetingDataListener?.cancel();
    _participantsListener?.cancel();
    _meetingDataListener = null;
    _participantsListener = null;
  }

  /// Public method to stop listening
  void stopListening() {
    _stopListening();
    _currentMeetingId = null;
    _currentUserId = null;
    _context = null;
    _onApprovalReceived = null;
    _onRejectionReceived = null;
  }

  /// Check if currently listening
  bool get isListening => 
      _meetingDataListener != null || _participantsListener != null;

  /// Dispose all resources
  void dispose() {
    stopListening();
  }
}
