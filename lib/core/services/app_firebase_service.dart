import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:secured_calling/core/constants.dart';
import 'package:secured_calling/core/models/member_model.dart';
import 'package:secured_calling/core/models/private_meeting_model.dart';
import 'package:secured_calling/core/services/http_service.dart';
import 'package:secured_calling/utils/app_logger.dart';
import 'package:secured_calling/utils/app_meeting_id_genrator.dart';
import 'package:secured_calling/core/models/app_user_model.dart';
import 'package:secured_calling/core/services/app_local_storage.dart';
import 'package:secured_calling/utils/app_tost_util.dart';
import 'package:secured_calling/utils/warm_color_generator.dart';

class AppFirebaseService {
  // Singleton pattern
  AppFirebaseService._();
  static final AppFirebaseService _instance = AppFirebaseService._();
  static AppFirebaseService get instance => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? get currentUser => FirebaseAuth.instance.currentUser;

  // Firestore references
  CollectionReference get usersCollection => _firestore.collection('users');
  CollectionReference get meetingsCollection =>
      _firestore.collection('meetings');
  CollectionReference get callLogsCollection =>
      _firestore.collection('call_logs');

  // Firestore methods
  Future<DocumentSnapshot> getUserData(String uid) async {
    return await usersCollection.doc(uid).get();
  }

  // Firestore methods
  Future<QueryDocumentSnapshot?> getUserDataWhereUserId(int uid) async {
    try {
      return (await usersCollection.where('userId', isEqualTo: uid).get())
          .docs
          .firstOrNull;
    } catch (e) {
      AppLogger.print('error caught in getting user DAta from id:$e');
      return null;
    }
  }

  Future<AppUser> getLoggedInUserDataAsModel() async {
    final currentUser = AppLocalStorage.getUserDetails();
    if (currentUser.userId > 0) {
      AppLogger.print('current user ID : ${currentUser.userId}');
      final res =
          (await usersCollection
                  .where('userId', isEqualTo: currentUser.userId)
                  .get())
              .docs
              .firstOrNull;
      if (res != null) {
        final data = res.data() as Map<String, dynamic>;
        AppLogger.print('user data : $data');
        return AppUser.fromJson(data);
      }
    }
    return AppUser.toEmpty();
  }

  Future<void> updateUserData(String uid, Map<String, dynamic> data) async {
    await usersCollection.doc(uid).update(data);
  }

  // Meeting methods
  Future<DocumentReference> createMeeting({
    required String hostId,
    required String meetingName,
    required DateTime scheduledStartTime,
    required int duration, // in minutes
    String? password,
    bool requiresApproval = false,
    required int maxParticipants,
    required String hostName,
    required int hostUserId,
  }) async {
    final meetingDocId = await AppMeetingIdGenrator.generateMeetingId();
    await meetingsCollection.doc(meetingDocId).set({
      'hostId': hostId,
      'hostUserId': hostUserId,
      'hostName': hostName,
      'meet_id': meetingDocId,
      'meetingName': meetingName,
      'channelName': meetingDocId,
      'maxParticipants': maxParticipants,
      'password': password,
      'duration': duration,
      'isParticipantsMuted': {},
      'scheduledStartTime': scheduledStartTime.toIso8601String(),
      'scheduledEndTime':
          scheduledStartTime.add(Duration(minutes: duration)).toIso8601String(),
      'actualStartTime': null,
      'actualEndTime': null,
      'createdAt': DateTime.now().toIso8601String(),
      'requiresApproval': requiresApproval,
      'status':
          MeetingStatus.scheduled.name, // scheduled, live, ended, cancelled
      'pendingApprovals': [],
      'speakRequests': [],
      'approvedSpeakers': [],
      'pttUsers': [],
      'allParticipants': [],
      'invitedUsers': [],
      'memberCode': AppLocalStorage.getUserDetails().memberCode.toUpperCase(),
      // New tracking fields
      'totalParticipantsCount': 0,
      'actualDuration': 0, // in seconds
    });
    return meetingsCollection.doc(meetingDocId);
  }

  Future<void> startMeeting(String meetingId) async {
    AppLogger.print('meeting id : $meetingId');
    await meetingsCollection.doc(meetingId).update({
      'status': 'live',
      'actualStartTime': DateTime.now().toIso8601String(),
    });
  }

  Future<void> endMeeting(String meetingId) async {
    await removeParticipants(
      meetingId,
      AppLocalStorage.getUserDetails().userId,
    );
  }

  Future<bool> addParticipants(String meetId, int userId) async {
    try {
      final participantDoc = meetingsCollection
          .doc(meetId)
          .collection('participants')
          .doc('$userId');

      final participantSnapshot = await participantDoc.get();

      if (!participantSnapshot.exists) {
        final userData = await getUserDataWhereUserId(userId);
        final userName =
            (userData?.data() as Map<String, dynamic>?)?['name'] ??
            'Unknown User';

        await participantDoc.set({
          'userId': userId,
          'username': userName,
          'joinTime': FieldValue.serverTimestamp(),
          'leaveTime': null,
          'colorIndex': Random().nextInt(WarmColorGenerator.warmColors.length),
          'isActive': true,
        });

        await meetingsCollection.doc(meetId).update({
          'totalUniqueParticipants': FieldValue.increment(1),
          'allParticipants': FieldValue.arrayUnion([userId]),
        });
      }else{
        await participantDoc.update({
          'joinTime': FieldValue.serverTimestamp(),
          'leaveTime': null,
          'isActive': true,
        });
      }
      return true;
    } catch (e) {
      AppLogger.print('Error adding participant: $e');
      return false;
    }
  }

  Future<bool> removeParticipants(String meetId, int userId) async {
    try {
      final participantDoc = meetingsCollection
          .doc(meetId)
          .collection('participants')
          .doc('$userId');

      await participantDoc.update({'leaveTime': FieldValue.serverTimestamp(),
      'isActive': false,
      });

      // Check if this was the last participant
      final participantsSnapshot =
          await meetingsCollection.doc(meetId).collection('participants').get();

      final activeParticipants =
          participantsSnapshot.docs.where((doc) {
            return (doc.data()['isActive'] as bool?) == true;
          }).toList();

      if (activeParticipants.isEmpty) {
        final meetingDoc = await meetingsCollection.doc(meetId).get();
        final meetingData = meetingDoc.data() as Map<String, dynamic>?;
        final actualStartTime = meetingData?['actualStartTime'];
        Duration actualDuration = Duration.zero;

        if (actualStartTime != null) {
          final startTime = DateTime.tryParse(actualStartTime);
          if (startTime != null) {
            actualDuration = DateTime.now().difference(startTime);
          }
        }

        await meetingsCollection.doc(meetId).update({
          'status': 'ended',
          'actualEndTime': FieldValue.serverTimestamp(),
          'actualDuration': actualDuration.inSeconds,
        });
      }
      return true;
    } catch (e) {
      AppLogger.print('Error removing participant: $e');
      return false;
    }
  }

  Future<void> addInvitedUsers(String meetingId, List<int> userIds) async {
    try {
      await meetingsCollection.doc(meetingId).update({
        'invitedUsers': FieldValue.arrayUnion(userIds),
      });
    } catch (e) {
      AppLogger.print('Error adding invited users: $e');
    }
  }

  Future<void> extendMeeting(String meetingId, int additionalMinutes) async {
    try {
      // Validate input
      if (additionalMinutes <= 0) {
        throw ArgumentError('Additional minutes must be greater than 0');
      }

      final meetingDoc = await meetingsCollection.doc(meetingId).get();
      if (!meetingDoc.exists) {
        throw Exception('Meeting not found');
      }

      final meetingData = meetingDoc.data() as Map<String, dynamic>;

      // Check if meeting is still active
      final status = meetingData['status'] as String?;
      if (status == 'ended' || status == 'cancelled') {
        throw Exception(
          'Cannot extend a meeting that has ended or been cancelled',
        );
      }

      // Parse current end time
      final currentEndTime = meetingData['scheduledEndTime'];
      DateTime endTime;

      if (currentEndTime is Timestamp) {
        endTime = currentEndTime.toDate();
      } else if (currentEndTime is String) {
        endTime = DateTime.tryParse(currentEndTime) ?? DateTime.now();
      } else {
        endTime = DateTime.now();
      }

      // Calculate new end time
      final newEndTime = endTime.add(Duration(minutes: additionalMinutes));

      // Get current duration
      final currentDuration = meetingData['duration'] as int? ?? 0;
      final newDuration = currentDuration + additionalMinutes;

      // Update meeting with new end time and duration
      await meetingsCollection.doc(meetingId).update({
        'scheduledEndTime': newEndTime.toIso8601String(),
        'duration': newDuration,
        'lastExtendedAt': FieldValue.serverTimestamp(),
        'totalExtensions': FieldValue.increment(1),
      });

      AppLogger.print(
        'Meeting $meetingId extended by $additionalMinutes minutes. New end time: $newEndTime',
      );
    } catch (e) {
      AppLogger.print('Error extending meeting: $e');
      rethrow;
    }
  }

  /// Extended version with additional options
  Future<void> extendMeetingWithOptions({
    required String meetingId,
    required int additionalMinutes,
    String? reason,
    bool notifyParticipants = true,
  }) async {
    try {
      await extendMeeting(meetingId, additionalMinutes);

      // Add extension log
      await meetingsCollection.doc(meetingId).collection('extensions').add({
        'additionalMinutes': additionalMinutes,
        'reason': reason,
        'extendedAt': FieldValue.serverTimestamp(),
        'extendedBy': AppLocalStorage.getUserDetails().userId,
        'notifyParticipants': notifyParticipants,
      });

      // TODO: Implement participant notification if needed
      if (notifyParticipants) {
        // This could send push notifications or update participant streams
        AppLogger.print(
          'Participant notification for meeting extension not yet implemented',
        );
      }
    } catch (e) {
      AppLogger.print('Error extending meeting with options: $e');
      rethrow;
    }
  }

  /// Get meeting extension history
  Stream<QuerySnapshot> getMeetingExtensionsStream(String meetingId) {
    return meetingsCollection
        .doc(meetingId)
        .collection('extensions')
        .orderBy('extendedAt', descending: true)
        .snapshots();
  }

  Future<void> requestToJoinMeeting(String meetingId, int userId) async {
    await meetingsCollection.doc(meetingId).update({
      'pendingApprovals': FieldValue.arrayUnion([userId]),
    });
  }

  Future<void> approveMeetingJoinRequest(String meetingId, int userId) async {
    await meetingsCollection.doc(meetingId).update({
      'pendingApprovals': FieldValue.arrayRemove([userId]),
    });
    await addParticipants(meetingId, userId);
  }

  Future<void> rejectMeetingJoinRequest(String meetingId, int userId) async {
    await meetingsCollection.doc(meetingId).update({
      'pendingApprovals': FieldValue.arrayRemove([userId]),
    });
  }

  Stream<QuerySnapshot> getHostMeetingsStream(int hostId) {
    return meetingsCollection
        .where('hostUserId', isEqualTo: hostId)
        .orderBy('scheduledStartTime', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getParticipantsStream(String meetingId) {
    return meetingsCollection
        .doc(meetingId)
        .collection('participants')
        .snapshots();
  }

  Stream<QuerySnapshot> getParticipatedMeetingsStream(int userId) {
    try {
      return meetingsCollection
          .where('allParticipants', arrayContains: userId)
          .orderBy('scheduledStartTime', descending: true)
          .snapshots();
    } catch (e) {
      AppLogger.print('Error getting participated meetings: $e');
      return Stream.empty();
    }
  }

  Stream<QuerySnapshot> getUpcomingMeetingsStream(String memberCode) {
    final now = DateTime.now();
    return meetingsCollection
        .where('memberCode', isEqualTo: memberCode.toUpperCase())
        .where('scheduledStartTime', isGreaterThan: now)
        .where('status', isEqualTo: 'scheduled')
        .orderBy('scheduledStartTime', descending: false)
        .snapshots();
  }

  Stream<QuerySnapshot> getUpcomingMeetingsForUserStream(
    String memberCode,
    int userId,
  ) {
    final now = DateTime.now();
    return meetingsCollection
        .where('memberCode', isEqualTo: memberCode.toUpperCase())
        .where('scheduledStartTime', isGreaterThan: now)
        .where('status', isEqualTo: 'scheduled')
        .where('invitedUsers', arrayContains: userId)
        .orderBy('scheduledStartTime', descending: false)
        .snapshots();
  }

  Future<QuerySnapshot?> getAllMeetingsFromCodeStream(String memberCode) async {
    try {
      return meetingsCollection
          .where('memberCode', isEqualTo: memberCode.toUpperCase())
          .get();
    } catch (e) {
      AppLogger.print('error caught in getting all meetings from code : $e');
      return null;
    }
  }

  Future<QuerySnapshot> searchMeetingByChannelName(String channelName) {
    return meetingsCollection
        .where('channelName', isEqualTo: channelName)
        .where('status', isEqualTo: 'live')
        .get();
  }

  Future<Map<String, dynamic>?> getMeetingData(String meetindID) async {
    return (await meetingsCollection.doc(meetindID).get()).data()
        as Map<String, dynamic>?;
  }

  Future<DocumentSnapshot<Object?>?> searchMeetingByMeetId(
    String meetId,
    String channelName,
  ) async {
    try {
      return await meetingsCollection.doc(meetId).get();
    } catch (e) {
      AppLogger.print("can not find meet : $e");
      return null;
    }
  }

  // Call logs
  Future<void> logCallParticipation({
    required String meetingId,
    required String userId,
    required DateTime joinTime,
  }) async {
    await callLogsCollection.add({
      'meetingId': meetingId,
      'userId': userId,
      'joinTime': joinTime,
      'leaveTime': null,
    });
  }

  Future<void> updateCallLogOnLeave({
    required String meetingId,
    required String userId,
    required DateTime leaveTime,
  }) async {
    final QuerySnapshot logs =
        await callLogsCollection
            .where('meetingId', isEqualTo: meetingId)
            .where('userId', isEqualTo: userId)
            .where('leaveTime', isNull: true)
            .get();

    if (logs.docs.isNotEmpty) {
      await callLogsCollection.doc(logs.docs.first.id).update({
        'leaveTime': leaveTime,
      });
    }
  }

  Future<List<String>> getAllMeetDocIds() async {
    return (await meetingsCollection.get()).docs.map((e) => e.id).toList();
  }

  Future<String> getAgoraToken({
    required String channelName,
    required int uid,
    required bool isHost,
  }) async {
    return await AppHttpService().fetchAgoraToken(
          channelName: channelName,
          uid: uid,
          userRole: isHost ? 1 : 0,
        ) ??
        '';
  }

  Stream<bool> isCurrentUserMutedByHost(String meetingId) async* {
    final userId = AppLocalStorage.getUserDetails().userId;
    yield* meetingsCollection.doc(meetingId).snapshots().map((snapshot) {
      final data = snapshot.data() as Map<String, dynamic>?;
      if (data != null && data['isParticipantsMuted'] != null) {
        final rawMap = data['isParticipantsMuted'] as Map<String, dynamic>;
        final mutedMap = rawMap.map(
          (key, value) => MapEntry(key, value as bool),
        );
        return mutedMap[userId.toString()] ?? false;
      }
      return false;
    });
  }

  void muteParticipants(String meetingId, int userId, bool isMute) async {
    final meetingDoc = await meetingsCollection.doc(meetingId).get();
    final data = meetingDoc.data() as Map<String, dynamic>?;

    if (data != null) {
      final Map<String, dynamic> mutedMap = data['isParticipantsMuted'] ?? {};
      final Map<int, bool> isParticipantsMuted = {
        for (var entry in mutedMap.entries)
          int.parse(entry.key): entry.value as bool,
      };

      isParticipantsMuted[userId] = isMute;

      // Convert keys back to String before uploading
      final Map<String, bool> updatedMutedMap = {
        for (var entry in isParticipantsMuted.entries)
          entry.key.toString(): entry.value,
      };

      await meetingsCollection.doc(meetingId).update({
        'isParticipantsMuted': updatedMutedMap,
      });
    }
  }

  Future<List<AppUser>> getAllUserOfMember(String memberCode) async {
    final QuerySnapshot querySnapshot =
        await usersCollection.where('memberCode', isEqualTo: memberCode).get();

    return querySnapshot.docs
        .map((doc) => AppUser.fromJson(doc.data() as Map<String, dynamic>))
        .toList();
  }

  Stream<QuerySnapshot> getUsersByMemberCodeStream(String memberCode) {
    return usersCollection
        .where('memberCode', isEqualTo: memberCode)
        .snapshots();
  }

  Future<List<AppUser>> getAllUsers() async {
    try {
      final snapshot = await _firestore.collection('users').get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return AppUser.fromJson(data);
      }).toList();
    } catch (e) {
      AppLogger.print('Error getting users: $e');
      rethrow;
    }
  }

  Future<Member> getMemberData(String memberCode) async {
    try {
      final snapshot =
          await _firestore
              .collection('members')
              .where('memberCode', isEqualTo: memberCode)
              .get();
      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        return Member.fromMap(snapshot.docs.first.id, data);
      } else {
        return Member.toEmpty();
      }
    } catch (e) {
      AppLogger.print('Error getting member data: $e');
      return Member.toEmpty();
    }
  }

  Stream<bool> isInstructedToLeave(String meetingId) async* {
    yield* meetingsCollection.doc(meetingId).snapshots().map((snapshot) {
      final data = snapshot.data() as Map<String, dynamic>?;
      if (data != null && data['isInstructedToLeave'] != null) {
        return data['isInstructedToLeave'] as bool;
      }
      return false;
    });
  }

  void cancelJoinRequest(int userId, String s) {
    try {
      meetingsCollection
          .doc(s)
          .update({
            'pendingApprovals': FieldValue.arrayRemove([userId]),
          })
          .then((value) {
            AppToastUtil.showSuccessToast('Request cancelled successfully');
          })
          .catchError((error) {
            AppLogger.print('Error cancelling request: $error');
            AppToastUtil.showErrorToast('Failed to cancel request');
          });
    } catch (e) {
      AppLogger.print('Error cancelling request: $e');
      AppToastUtil.showErrorToast('Failed to cancel request');
    }
  }

  Stream<DocumentSnapshot> getMeetingStream(String meetingId) {
    return meetingsCollection.doc(meetingId).snapshots();
  }

  Future<void> removeAllParticipants(String meetingId) async {
    try {
      // Get all participants for this meeting
      final participantsSnapshot =
          await meetingsCollection
              .doc(meetingId)
              .collection('participants')
              .get();

      // Mark all participants as left with current timestamp
      final batch = _firestore.batch();
      final now = FieldValue.serverTimestamp();

      for (final doc in participantsSnapshot.docs) {
        batch.update(doc.reference, {'leaveTime': now});
      }

      // Update meeting status to ended
      batch.update(meetingsCollection.doc(meetingId), {
        'status': 'ended',
        'actualEndTime': now,
        'isInstructedToLeave': true, // Signal all participants to leave
      });

      // Commit all changes
      await batch.commit();

      AppLogger.print('All participants removed from meeting $meetingId');
    } catch (e) {
      AppLogger.print('Error removing all participants: $e');
      rethrow;
    }
  }
}
