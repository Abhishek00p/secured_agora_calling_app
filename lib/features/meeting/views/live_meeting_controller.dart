
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:secured_calling/core/services/app_firebase_service.dart';

class MeetingState {
  final bool isLoading;
  final String? error;
  final List<Map<String, dynamic>> pendingRequests;

  const MeetingState({
    this.isLoading = false,
    this.error,
    this.pendingRequests = const [],
  });

  MeetingState copyWith({
    bool? isLoading,
    String? error,
    List<Map<String, dynamic>>? pendingRequests,
  }) {
    return MeetingState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      pendingRequests: pendingRequests ?? this.pendingRequests,
    );
  }
}

class MeetingController extends StateNotifier<MeetingState> {
  final AppFirebaseService _firebaseService;
  final String? meetingId;
  final bool isHost;

  MeetingController({
    required AppFirebaseService firebaseService,
    required this.meetingId,
    required this.isHost,
  })  : _firebaseService = firebaseService,
        super(const MeetingState());

  Future<void> fetchPendingRequests() async {
    if (meetingId == null) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final meetingDoc =
          await _firebaseService.meetingsCollection.doc(meetingId).get();
      final meetingData = meetingDoc.data() as Map<String, dynamic>;
      final pendingUserIds = meetingData['pendingApprovals'] as List<dynamic>;

      final pendingRequests = <Map<String, dynamic>>[];

      for (final userId in pendingUserIds) {
        final userDoc = await _firebaseService.getUserData(userId as String);
        final userData = userDoc.data() as Map<String, dynamic>?;
        if (userData != null) {
          pendingRequests.add({
            'userId': userId,
            'name': userData['name'] ?? 'Unknown User',
          });
        }
      }

      state = state.copyWith(
        isLoading: false,
        pendingRequests: pendingRequests,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }



  Future<void> rejectJoinRequest(String userId) async {
    if (meetingId == null) return;

    try {
      await _firebaseService.rejectMeetingJoinRequest(meetingId!, userId);
      await fetchPendingRequests();
    } catch (e) {
      state = state.copyWith(error: 'Error rejecting request: $e');
    }
  }

  Future<void> endMeeting({required Future<void> Function() leaveAgora,required String meetingId}) async {
    try {
      if (meetingId.isNotEmpty && isHost) {
        await _firebaseService.endMeeting(meetingId);
      }
      leaveAgora.call();
    //       await _agoraService.leaveChannel();
    //         if (mounted) {
    //   Navigator.pop(context);
    // }

    } catch (e) {
      debugPrint('Error ending meeting: $e');
    } finally {
     
    }
  }
}

final meetingControllerProvider = StateNotifierProvider.autoDispose
    .family<MeetingController, MeetingState, ({String? meetingId, bool isHost})>(
  (ref, args) => MeetingController(
    firebaseService: AppFirebaseService.instance,
    meetingId: args.meetingId,
    isHost: args.isHost,
  ),
);
