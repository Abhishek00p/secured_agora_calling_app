import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:secured_calling/models/meeting_detail.dart';
import 'package:secured_calling/models/participant_detail.dart';
import 'package:secured_calling/core/services/app_firebase_service.dart';
import 'package:secured_calling/core/services/app_local_storage.dart';
import 'package:secured_calling/utils/app_logger.dart';

class MeetingDetailService {
  final AppFirebaseService _firebaseService = AppFirebaseService.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<MeetingDetail> fetchMeetingDetail(String meetingId) async {
    try {
      final meetingDoc =
          await _firestore.collection('meetings').doc(meetingId).get();

      if (!meetingDoc.exists) {
        throw Exception('Meeting not found');
      }

      final meetingData = meetingDoc.data() as Map<String, dynamic>;

      // Fetch participants
      final participantsSnapshot =
          await _firestore
              .collection('meetings')
              .doc(meetingId)
              .collection('participants')
              .get();

      final participants =
          participantsSnapshot.docs.map((doc) {
            final data = doc.data();
            return ParticipantDetail(
              userId: data['userId']?.toString() ?? 'Unknown',
              username: data['username'] ?? 'Unknown User',
              joinTime: data['joinTime']?.toDate() ?? DateTime.now(),
              leaveTime: data['leaveTime']?.toDate(),
            );
          }).toList();

      // Parse meeting data
      final scheduledStartTime = _parseDateTime(
        meetingData['scheduledStartTime'],
      );
      final scheduledEndTime = _parseDateTime(meetingData['scheduledEndTime']);
      final actualStartTime = _parseNullableDateTime(
        meetingData['actualStartTime'],
      );
      final actualEndTime = _parseNullableDateTime(
        meetingData['actualEndTime'],
      );

      // Calculate duration
      final duration = Duration(minutes: meetingData['duration'] ?? 60);

      // Determine status
      final status = _determineMeetingStatus(
        meetingData['status'],
        scheduledStartTime,
        scheduledEndTime,
        actualStartTime,
        actualEndTime,
      );

      return MeetingDetail(
        meetingTitle: meetingData['meetingName'] ?? 'Untitled Meeting',
        meetingId: meetingId,
        meetingPass: meetingData['password'],
        hostName: meetingData['hostName'] ?? 'Unknown Host',
        hostId: meetingData['hostId'] ?? 'Unknown',
        maxParticipants: meetingData['maxParticipants'] ?? 50,
        duration: duration,
        scheduledStartTime: scheduledStartTime,
        scheduledEndTime: scheduledEndTime,
        actualStartTime: actualStartTime,
        actualEndTime: actualEndTime,
        status: status,
        totalUniqueParticipants: participants.length,
        participants: participants,
      );
    } catch (e) {
      AppLogger.print('Error fetching meeting detail: $e');
      rethrow;
    }
  }

  /// Extend meeting duration
  Future<bool> extendMeeting(
    String meetingId,
    int additionalMinutes, {
    String? reason,
  }) async {
    try {
      // Check if current user is the host
      final currentUser = AppLocalStorage.getUserDetails();
      final meetingDoc =
          await _firestore.collection('meetings').doc(meetingId).get();

      if (!meetingDoc.exists) {
        throw Exception('Meeting not found');
      }

      final meetingData = meetingDoc.data() as Map<String, dynamic>;
      final hostUserId = meetingData['hostUserId'] as int?;

      if (hostUserId != currentUser.userId) {
        throw Exception('Only the meeting host can extend the meeting');
      }

      // Extend the meeting
      await _firebaseService.extendMeetingWithOptions(
        meetingId: meetingId,
        additionalMinutes: additionalMinutes,
        reason: reason,
      );

      return true;
    } catch (e) {
      AppLogger.print('Error extending meeting: $e');
      rethrow;
    }
  }

  /// Get meeting extension history
  Stream<QuerySnapshot> getMeetingExtensionsStream(String meetingId) {
    return _firebaseService.getMeetingExtensionsStream(meetingId);
  }

  /// Check if current user can extend the meeting
  Future<bool> canExtendMeeting(String meetingId) async {
    try {
      final currentUser = AppLocalStorage.getUserDetails();
      final meetingDoc =
          await _firestore.collection('meetings').doc(meetingId).get();

      if (!meetingDoc.exists) return false;

      final meetingData = meetingDoc.data() as Map<String, dynamic>;
      final hostUserId = meetingData['hostUserId'] as int?;
      final status = meetingData['status'] as String?;

      // Only host can extend, and meeting must be active
      return hostUserId == currentUser.userId &&
          (status == 'scheduled' || status == 'live');
    } catch (e) {
      AppLogger.print('Error checking extend permission: $e');
      return false;
    }
  }

  /// Get real-time meeting updates
  Stream<DocumentSnapshot> getMeetingStream(String meetingId) {
    return _firestore.collection('meetings').doc(meetingId).snapshots();
  }

  DateTime _parseDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  DateTime? _parseNullableDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  String _determineMeetingStatus(
    String? status,
    DateTime scheduledStartTime,
    DateTime scheduledEndTime,
    DateTime? actualStartTime,
    DateTime? actualEndTime,
  ) {
    if (status == 'ended' || actualEndTime != null) return 'ended';
    if (status == 'cancelled') return 'cancelled';
    if (status == 'live' || actualStartTime != null) return 'ongoing';

    final now = DateTime.now();
    if (now.isBefore(scheduledStartTime)) return 'upcoming';
    if (now.isAfter(scheduledEndTime)) return 'overdue';

    return 'ongoing';
  }
}
