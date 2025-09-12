import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:secured_calling/core/services/app_firebase_service.dart';
import 'package:secured_calling/core/services/app_local_storage.dart';
import 'package:secured_calling/utils/app_logger.dart';

/// Handles meeting timeouts and participant cleanup
/// This works by having the server detect inactive participants
class MeetingTimeoutService {
  static MeetingTimeoutService? _instance;
  static MeetingTimeoutService get instance => _instance ??= MeetingTimeoutService._();
  
  MeetingTimeoutService._();
  
  final AppFirebaseService _firebaseService = AppFirebaseService.instance;
  Timer? _heartbeatTimer;
  String? _currentMeetingId;
  int? _currentUserId;
  
  /// Start sending heartbeats for the current meeting
  void startHeartbeat(String meetingId) {
    _currentMeetingId = meetingId;
    _currentUserId = AppLocalStorage.getUserDetails().userId;
    
    // Send heartbeat every 30 seconds
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _sendHeartbeat();
    });
    
    // Send initial heartbeat
    _sendHeartbeat();
    
    AppLogger.print('Started heartbeat for meeting: $meetingId');
  }
  
  /// Stop sending heartbeats
  void stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _currentMeetingId = null;
    _currentUserId = null;
    
    AppLogger.print('Stopped heartbeat');
  }
  
  /// Send heartbeat to server
  Future<void> _sendHeartbeat() async {
    if (_currentMeetingId == null || _currentUserId == null) return;
    
    try {
      await _firebaseService.sendParticipantHeartbeat(
        _currentMeetingId!, 
        _currentUserId!
      );
      AppLogger.print('Heartbeat sent for user $_currentUserId');
    } catch (e) {
      AppLogger.print('Failed to send heartbeat: $e');
    }
  }
  
  /// Check for inactive participants and clean them up
  Future<void> cleanupInactiveParticipants(String meetingId) async {
    try {
      // This would be called by a server-side function
      // or a scheduled job that runs every minute
      await _firebaseService.cleanupInactiveParticipants(meetingId);
    } catch (e) {
      AppLogger.print('Failed to cleanup inactive participants: $e');
    }
  }
}
