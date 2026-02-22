import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:secured_calling/core/services/app_local_storage.dart';
import 'package:secured_calling/core/services/app_firebase_service.dart';
import 'package:secured_calling/features/meeting/bindings/live_meeting_controller.dart';
import 'package:secured_calling/utils/app_logger.dart';

/// Manages app lifecycle events and ensures proper cleanup when app is terminated
class AppLifecycleManager extends GetxService with WidgetsBindingObserver {
  static AppLifecycleManager get instance => Get.find<AppLifecycleManager>();

  final AppFirebaseService _firebaseService = AppFirebaseService.instance;
  // AppLocalStorage is used statically

  // Track if user is currently in a meeting
  bool _isInMeeting = false;
  String _currentMeetingId = '';
  bool _isHost = false;

  // Timer to handle delayed cleanup (in case app is quickly reopened)
  Timer? _cleanupTimer;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    AppLogger.print('AppLifecycleManager initialized');
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _cleanupTimer?.cancel();
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.paused:
        _handleAppPaused();
        break;
      case AppLifecycleState.detached:
        _handleAppDetached();
        break;
      case AppLifecycleState.resumed:
        _handleAppResumed();
        break;
      case AppLifecycleState.inactive:
        // App is transitioning between states, no action needed
        break;
      case AppLifecycleState.hidden:
        // App is hidden but still running, no action needed
        break;
    }
  }

  /// Called when app is paused (moved to background)
  void _handleAppPaused() {
    AppLogger.print('App paused - checking meeting status');

    // Check if user is in a meeting
    _checkMeetingStatus();

    if (_isInMeeting) {
      // Do NOT run delayed cleanup here: user may return via the
      // persistent notification or call bar. Cleanup only on detached (app process killed).
    }
  }

  /// Called when app is detached (forcefully terminated)
  void _handleAppDetached() {
    AppLogger.print('App detached - performing immediate cleanup');

    // Cancel any pending cleanup timer
    _cleanupTimer?.cancel();

    // Perform immediate cleanup
    _performMeetingCleanup();
  }

  /// Handle app termination from background (Android specific)
  // void _handleAppTerminated() {
  //   AppLogger.print('App terminated from background - performing cleanup');

  //   // Cancel any pending cleanup timer
  //   _cleanupTimer?.cancel();

  //   // Perform immediate cleanup
  //   _performMeetingCleanup();
  // }

  /// Called when app is resumed
  void _handleAppResumed() {
    AppLogger.print('App resumed - canceling cleanup timer');

    // Cancel cleanup timer if app is resumed quickly
    _cleanupTimer?.cancel();
  }

  /// Check if user is currently in a meeting
  void _checkMeetingStatus() {
    try {
      // Check if MeetingController exists and user is joined
      if (Get.isRegistered<MeetingController>()) {
        final meetingController = Get.find<MeetingController>();
        _isInMeeting = meetingController.isJoined.value;
        _currentMeetingId = meetingController.meetingId;
        _isHost = meetingController.isHost;

        AppLogger.print('Meeting status - InMeeting: $_isInMeeting, MeetingId: $_currentMeetingId, IsHost: $_isHost');
      } else {
        _isInMeeting = false;
        _currentMeetingId = '';
        _isHost = false;
      }
    } catch (e) {
      AppLogger.print('Error checking meeting status: $e');
      _isInMeeting = false;
      _currentMeetingId = '';
      _isHost = false;
    }
  }

  /// Perform cleanup when app is terminated
  Future<void> _performMeetingCleanup() async {
    if (!_isInMeeting || _currentMeetingId.isEmpty) {
      AppLogger.print('No active meeting to cleanup');
      return;
    }

    try {
      AppLogger.print('Performing meeting cleanup for meeting: $_currentMeetingId');

      final currentUser = AppLocalStorage.getUserDetails();

      // Remove user from meeting participants
      await _firebaseService.removeParticipantFromMeeting(_currentMeetingId, currentUser.userId);

      // If user was host, end the meeting for everyone
      if (_isHost) {
        AppLogger.print('Host terminated app - ending meeting for all participants');
        await _firebaseService.removeAllParticipants(_currentMeetingId);
        await _firebaseService.endMeeting(_currentMeetingId);
      }

      AppLogger.print('Meeting cleanup completed successfully');
    } catch (e) {
      AppLogger.print('Error during meeting cleanup: $e');
    } finally {
      // Reset meeting status
      _isInMeeting = false;
      _currentMeetingId = '';
      _isHost = false;
    }
  }

  /// Manually set meeting status (called by MeetingController)
  void setMeetingStatus({required bool isInMeeting, required String meetingId, required bool isHost}) {
    _isInMeeting = isInMeeting;
    _currentMeetingId = meetingId;
    _isHost = isHost;

    AppLogger.print('Meeting status updated - InMeeting: $isInMeeting, MeetingId: $meetingId, IsHost: $isHost');
  }

  /// Clear meeting status (called when meeting ends normally)
  void clearMeetingStatus() {
    _isInMeeting = false;
    _currentMeetingId = '';
    _isHost = false;

    // Cancel any pending cleanup
    _cleanupTimer?.cancel();

    AppLogger.print('Meeting status cleared');
  }

  /// Force cleanup (for testing or manual cleanup)
  Future<void> forceCleanup() async {
    AppLogger.print('Force cleanup requested');
    await _performMeetingCleanup();
  }
}
