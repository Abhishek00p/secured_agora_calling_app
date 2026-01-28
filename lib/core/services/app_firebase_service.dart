import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:secured_calling/core/constants.dart';
import 'package:secured_calling/core/models/individual_recording_model.dart';
import 'package:secured_calling/core/models/member_model.dart';
import 'package:secured_calling/core/models/recording_file_model.dart';
import 'package:secured_calling/core/services/agora_token_helper.dart';
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
  // CollectionReference get membersCollection => _firestore.collection('members');
  CollectionReference get meetingsCollection => _firestore.collection('meetings');
  CollectionReference get callLogsCollection => _firestore.collection('call_logs');
  CollectionReference get recordingsCollection => _firestore.collection('recordings');

  // Firestore methods
  Future<DocumentSnapshot> getUserData(String uid) async {
    return await usersCollection.doc(uid).get();
  }

  // Firestore methods
  Future<QueryDocumentSnapshot?> getUserDataWhereUserId(int uid) async {
    try {
      return (await usersCollection.where('userId', isEqualTo: uid).get()).docs.firstOrNull;
    } catch (e) {
      AppLogger.print('error caught in getting user DAta from id:$e');
      return null;
    }
  }

  Future<AppUser> getLoggedInUserDataAsModel() async {
    final currentUser = AppLocalStorage.getUserDetails();
    if (currentUser.userId > 0) {
      AppLogger.print('current user ID : ${currentUser.userId}');
      final res = (await usersCollection.where('userId', isEqualTo: currentUser.userId).get()).docs.firstOrNull;
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
    required int hostId,
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
    final data = {
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
      'scheduledEndTime': scheduledStartTime.add(Duration(minutes: duration)).toIso8601String(),
      'actualStartTime': null,
      'actualEndTime': null,
      'createdAt': DateTime.now().toIso8601String(),
      'requiresApproval': requiresApproval,
      'status': MeetingStatus.scheduled.name, // scheduled, live, ended, cancelled
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
    };
    AppLogger.print("\ndata to be stored in firebase firestore before creating a meeting...... $data\n");
    await meetingsCollection.doc(meetingDocId).set(data);
    return meetingsCollection.doc(meetingDocId);
  }

  Future<void> startMeeting(String meetingId) async {
    AppLogger.print('meeting id : $meetingId');
    await meetingsCollection.doc(meetingId).update({'status': 'live', 'actualStartTime': DateTime.now().toIso8601String()});
  }

  Future<void> endMeeting(String meetingId) async {
    await removeParticipants(meetingId, AppLocalStorage.getUserDetails().userId, isRemovedByHost: false);
  }

  Future<bool> addParticipants(String meetId, int userId) async {
    try {
      final participantDoc = meetingsCollection.doc(meetId).collection('participants').doc('$userId');

      final participantSnapshot = await participantDoc.get();

      if (!participantSnapshot.exists) {
        final userData = await getUserDataWhereUserId(userId);
        final userName = (userData?.data() as Map<String, dynamic>?)?['name'] ?? 'Unknown User';

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
      } else {
        await participantDoc.update({'joinTime': FieldValue.serverTimestamp(), 'leaveTime': null, 'isActive': true});
      }
      return true;
    } catch (e) {
      AppLogger.print('Error adding participant: $e');
      return false;
    }
  }

  Future<bool> removeParticipants(String meetId, int userId, {bool isRemovedByHost = false}) async {
    try {
      final participantDoc = meetingsCollection.doc(meetId).collection('participants').doc('$userId');

      await participantDoc.update({'leaveTime': FieldValue.serverTimestamp(), 'isActive': false, 'removedByHost': isRemovedByHost});

      // Check if this was the last participant
      final participantsSnapshot = await meetingsCollection.doc(meetId).collection('participants').get();

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
      await meetingsCollection.doc(meetingId).update({'invitedUsers': FieldValue.arrayUnion(userIds)});
    } catch (e) {
      AppLogger.print('Error adding invited users: $e');
    }
  }

  Future<void> extendMeeting(String meetingId, int additionalMinutes) async {
    try {
      // Validate input
      if (additionalMinutes <= 0) {
        AppToastUtil.showErrorToast('Additional minutes must be greater than 0');
      }

      final meetingDoc = await meetingsCollection.doc(meetingId).get();
      if (!meetingDoc.exists) {
        AppToastUtil.showErrorToast('Meeting not found');
      }

      final meetingData = meetingDoc.data() as Map<String, dynamic>;

      // Check if meeting is still active
      final status = meetingData['status'] as String?;
      if (status == 'ended' || status == 'cancelled') {
        AppToastUtil.showErrorToast('Cannot extend a meeting that has ended or been cancelled');
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

      AppLogger.print('Meeting $meetingId extended by $additionalMinutes minutes. New end time: $newEndTime');
    } catch (e) {
      AppLogger.print('Error extending meeting: $e');
      AppToastUtil.showErrorToast(e.toString());
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

      // Notify participants about meeting extension
      if (notifyParticipants) {
        try {
          // Update a notification field that participants can listen to
          await meetingsCollection.doc(meetingId).update({
            'lastExtensionNotification': FieldValue.serverTimestamp(),
            'lastExtensionMinutes': additionalMinutes,
            'lastExtensionReason': reason,
          });
          AppLogger.print('Meeting extension notification sent to participants');
        } catch (e) {
          AppLogger.print('Error sending extension notification: $e');
          // Don't rethrow as this is not critical
        }
      }
    } catch (e) {
      AppLogger.print('Error extending meeting with options: $e');
      rethrow;
    }
  }

  /// Get meeting extension history
  Stream<QuerySnapshot> getMeetingExtensionsStream(String meetingId) {
    return meetingsCollection.doc(meetingId).collection('extensions').orderBy('extendedAt', descending: true).snapshots();
  }

  /// Request to join a meeting using sub-collection approach
  /// Creates a document in /meetings/{meetingId}/joinRequests/{userId}
  Future<void> requestToJoinMeeting(String meetingId, int userId, {String? userName, String? userEmail}) async {
    try {
      final requestData = {
        'userId': userId,
        'status': 'pending',
        'requestedAt': FieldValue.serverTimestamp(),
        if (userName != null) 'userName': userName,
        if (userEmail != null) 'userEmail': userEmail,
      };

      AppLogger.print('Creating join request for user $userId in meeting $meetingId');
      AppLogger.print('Request data: $requestData');

      await meetingsCollection.doc(meetingId).collection('joinRequests').doc(userId.toString()).set(requestData);

      AppLogger.print('Join request created successfully for user $userId in meeting $meetingId');
    } catch (e) {
      AppLogger.print('Error creating join request: $e');
      rethrow;
    }
  }

  /// Approve a join request and add user to participants
  Future<void> approveMeetingJoinRequest(String meetingId, int userId) async {
    try {
      // Update the join request status to accepted
      await meetingsCollection.doc(meetingId).collection('joinRequests').doc(userId.toString()).update({'status': 'accepted'});

      // Add user to participants
      await addParticipants(meetingId, userId);

      AppLogger.print('Join request approved for user $userId in meeting $meetingId');
    } catch (e) {
      AppLogger.print('Error approving join request: $e');
      rethrow;
    }
  }

  /// Reject a join request
  Future<void> rejectMeetingJoinRequest(String meetingId, int userId) async {
    try {
      await meetingsCollection.doc(meetingId).collection('joinRequests').doc(userId.toString()).update({'status': 'rejected'});

      AppLogger.print('Join request rejected for user $userId in meeting $meetingId');
    } catch (e) {
      AppLogger.print('Error rejecting join request: $e');
      rethrow;
    }
  }

  /// Mark join request as joined (when user successfully joins the meeting)
  Future<void> markJoinRequestAsJoined(String meetingId, int userId) async {
    try {
      await meetingsCollection.doc(meetingId).collection('joinRequests').doc(userId.toString()).update({'status': 'joined'});

      AppLogger.print('Join request marked as joined for user $userId in meeting $meetingId');
    } catch (e) {
      AppLogger.print('Error marking join request as joined: $e');
    }
  }

  /// Get stream of pending join requests for a meeting
  Stream<QuerySnapshot> getPendingJoinRequestsStream(String meetingId) {
    AppLogger.print('Setting up pending join requests stream for meeting: $meetingId');

    return meetingsCollection.doc(meetingId).collection('joinRequests').where('status', isEqualTo: 'pending').snapshots().map((snapshot) {
      AppLogger.print('Firebase query result: ${snapshot.docs.length} pending requests found');
      for (final doc in snapshot.docs) {
        AppLogger.print('Pending request doc: ${doc.id} - ${doc.data()}');
      }
      return snapshot;
    });
  }

  /// Get stream of all join requests for a meeting
  Stream<QuerySnapshot> getAllJoinRequestsStream(String meetingId) {
    return meetingsCollection.doc(meetingId).collection('joinRequests').orderBy('requestedAt', descending: false).snapshots();
  }

  /// Get a specific join request document
  Stream<DocumentSnapshot> getJoinRequestStream(String meetingId, int userId) {
    return meetingsCollection.doc(meetingId).collection('joinRequests').doc(userId.toString()).snapshots();
  }

  /// Cancel a join request (remove the document)
  Future<void> cancelJoinRequest(String meetingId, int userId) async {
    try {
      await meetingsCollection.doc(meetingId).collection('joinRequests').doc(userId.toString()).delete();

      AppLogger.print('Join request cancelled for user $userId in meeting $meetingId');
    } catch (e) {
      AppLogger.print('Error cancelling join request: $e');
      rethrow;
    }
  }

  Stream<QuerySnapshot> getHostMeetingsStream(int hostId) {
    return meetingsCollection.where('hostUserId', isEqualTo: hostId).orderBy('scheduledStartTime', descending: true).snapshots();
  }

  Stream<QuerySnapshot> getParticipantsStream(String meetingId) {
    return meetingsCollection.doc(meetingId).collection('participants').snapshots();
  }

  Stream<QuerySnapshot> getParticipatedMeetingsStream(int userId) {
    try {
      return meetingsCollection.where('allParticipants', arrayContains: userId).orderBy('scheduledStartTime', descending: true).snapshots();
    } catch (e) {
      AppLogger.print('Error getting participated meetings: $e');
      return Stream.empty();
    }
  }

  Stream<QuerySnapshot> getUpcomingMeetingsStream(String memberCode) {
    return meetingsCollection.where('memberCode', isEqualTo: memberCode.toUpperCase()).orderBy('scheduledStartTime', descending: true).snapshots();
  }

  Stream<QuerySnapshot> getUpcomingMeetingsForUserStream(String memberCode, int userId) {
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
      return meetingsCollection.where('memberCode', isEqualTo: memberCode.toUpperCase()).get();
    } catch (e) {
      AppLogger.print('error caught in getting all meetings from code : $e');
      return null;
    }
  }

  Future<QuerySnapshot> searchMeetingByChannelName(String channelName) {
    return meetingsCollection.where('channelName', isEqualTo: channelName).where('status', isEqualTo: 'live').get();
  }

  Future<Map<String, dynamic>?> getMeetingData(String meetindID) async {
    return (await meetingsCollection.doc(meetindID).get()).data() as Map<String, dynamic>?;
  }

  Future<DocumentSnapshot<Object?>?> searchMeetingByMeetId(String meetId, String channelName) async {
    try {
      return await meetingsCollection.doc(meetId).get();
    } catch (e) {
      AppLogger.print("can not find meet : $e");
      return null;
    }
  }

  // Call logs
  Future<void> logCallParticipation({required String meetingId, required String userId, required DateTime joinTime}) async {
    await callLogsCollection.add({'meetingId': meetingId, 'userId': userId, 'joinTime': joinTime, 'leaveTime': null});
  }

  Future<void> updateCallLogOnLeave({required String meetingId, required String userId, required DateTime leaveTime}) async {
    final QuerySnapshot logs =
        await callLogsCollection.where('meetingId', isEqualTo: meetingId).where('userId', isEqualTo: userId).where('leaveTime', isNull: true).get();

    if (logs.docs.isNotEmpty) {
      await callLogsCollection.doc(logs.docs.first.id).update({'leaveTime': leaveTime});
    }
  }

  Future<List<String>> getAllMeetDocIds() async {
    return (await meetingsCollection.get()).docs.map((e) => e.id).toList();
  }

  Future<String> getAgoraToken({required String channelName, required int uid, required bool isHost}) async {
    return await AgoraTokenHelper.fetchAgoraToken(channelName: channelName, uid: uid, userRole: isHost ? 1 : 0) ?? '';
  }

  Future<String> verifyAgoraToken({required String channelName, required int uid, required bool isHost}) async {
    return await AgoraTokenHelper.verifyAgoraToken(channelName: channelName, uid: uid, userRole: isHost ? '1' : '0') ?? '';
  }

  Stream<bool> isCurrentUserMutedByHost(String meetingId) {
    if (meetingId.trim().isEmpty) {
      debugPrint('[isCurrentUserMutedByHost] Meeting ID is empty. Listener setup failed.');
      // Return a stream that emits false immediately and closes
      return Stream.value(false);
    }
    final userId = AppLocalStorage.getUserDetails().userId;
    return meetingsCollection.doc(meetingId).snapshots().map((snapshot) {
      final data = snapshot.data() as Map<String, dynamic>?;
      if (data != null && data['isParticipantsMuted'] != null) {
        final rawMap = data['isParticipantsMuted'] as Map<String, dynamic>;

        final isMuted = rawMap[userId.toString()];
        if (isMuted is bool) {
          return isMuted;
        } else {
          debugPrint('[isCurrentUserMutedByHost] Mute status not found or not a bool for user $userId.');
          return false;
        }
      }
      return false;
    });
  }

  Future<void> muteParticipants(String meetingId, int userId, bool isMute) async {
    try {
      if (meetingId.trim().isEmpty) {
        print("meetingId cannot be empty");
        return;
      }
      final meetingDoc = await meetingsCollection.doc(meetingId).get();

      if (!meetingDoc.exists) {
        print('Meeting document not found for ID: $meetingId');
        return;
      }

      final data = meetingDoc.data() as Map<String, dynamic>? ?? {};

      final mutedMap = Map<String, dynamic>.from(data['isParticipantsMuted'] ?? {});

      // Convert to Map<int, bool>
      final isParticipantsMuted = mutedMap.map<int, bool>((key, value) {
        return MapEntry(int.tryParse(key) ?? -1, value as bool);
      })..removeWhere((key, _) => key == -1); // Remove invalid keys

      isParticipantsMuted[userId] = isMute;

      // Convert back to Map<String, bool> for Firestore
      final updatedMutedMap = isParticipantsMuted.map((key, value) {
        return MapEntry(key.toString(), value);
      });

      await meetingsCollection.doc(meetingId).update({'isParticipantsMuted': updatedMutedMap});

      print("Participant muted Successfully...");
    } catch (e, stackTrace) {
      // Logging or error reporting
      print('Error in muteParticipants: $e');
      // Optionally send to error reporting service
    }
  }

  Future<List<AppUser>> getAllUserOfMember(String memberCode) async {
    final QuerySnapshot querySnapshot = await usersCollection.where('memberCode', isEqualTo: memberCode).get();

    return querySnapshot.docs.map((doc) => AppUser.fromJson(doc.data() as Map<String, dynamic>)).toList();
  }

  Stream<QuerySnapshot> getUsersByMemberCodeStream(String memberCode) {
    return usersCollection.where('memberCode', isEqualTo: memberCode).snapshots();
  }

  Future<List<AppUser>> getUsersByMemberCodeData(String memberCode) async {
    final QuerySnapshot querySnapshot = await usersCollection.where('memberCode', isEqualTo: memberCode.toUpperCase()).get();
    print('Fetched ${querySnapshot.docs.length} users for member code $memberCode');
    return querySnapshot.docs
        .map((doc) => AppUser.fromJson(doc.data() as Map<String, dynamic>))
        .toList()
        .where((e) => e.userId != AppLocalStorage.getUserDetails().userId)
        .toList();
  }

  Future<List<AppUser>> getAllUsers() async {
    try {
      final snapshot = await _firestore.collection('users').get();
      return snapshot.docs.map((doc) {
        final data = doc.data();

        return AppUser.fromJson(data);
      }).toList();
    } catch (e) {
      AppLogger.print('Error getting users: $e');
      rethrow;
    }
  }

  Future<AppUser> getMemberData(String userId) async {
    try {
      final snapshot = await _firestore.collection('users').doc(userId).get();
      if (snapshot.exists) {
        final data = snapshot.data();
        return AppUser.fromJson(data ?? {});
      } else {
        return AppUser.toEmpty();
      }
    } catch (e) {
      AppLogger.print('Error getting member data: $e');
      return AppUser.toEmpty();
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

  Stream<DocumentSnapshot> getMeetingStream(String meetingId) {
    return meetingsCollection.doc(meetingId).snapshots();
  }

  Future<void> removeAllParticipants(String meetingId) async {
    try {
      // Get all participants for this meeting
      final participantsSnapshot = await meetingsCollection.doc(meetingId).collection('participants').get();

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

  /// Remove a specific participant from meeting (for app termination cleanup)
  Future<void> removeParticipantFromMeeting(String meetingId, int userId) async {
    try {
      final participantDoc = meetingsCollection.doc(meetingId).collection('participants').doc('$userId');

      // Mark participant as left with current timestamp
      await participantDoc.update({'leaveTime': FieldValue.serverTimestamp(), 'isActive': false});

      // Check if this was the last participant
      final participantsSnapshot = await meetingsCollection.doc(meetingId).collection('participants').get();

      final activeParticipants =
          participantsSnapshot.docs.where((doc) {
            return (doc.data()['isActive'] as bool?) == true;
          }).toList();

      if (activeParticipants.isEmpty) {
        final meetingDoc = await meetingsCollection.doc(meetingId).get();
        final meetingData = meetingDoc.data() as Map<String, dynamic>?;
        final actualStartTime = meetingData?['actualStartTime'];
        Duration actualDuration = Duration.zero;

        if (actualStartTime != null) {
          final startTime = DateTime.tryParse(actualStartTime);
          if (startTime != null) {
            actualDuration = DateTime.now().difference(startTime);
          }
        }

        await meetingsCollection.doc(meetingId).update({
          'status': 'ended',
          'actualEndTime': FieldValue.serverTimestamp(),
          'actualDuration': actualDuration.inSeconds,
        });
      }

      AppLogger.print('Participant $userId removed from meeting $meetingId');
    } catch (e) {
      AppLogger.print('Error removing participant from meeting: $e');
      rethrow;
    }
  }

  /// Send heartbeat to indicate participant is still active
  Future<void> sendParticipantHeartbeat(String meetingId, int userId) async {
    try {
      AppLogger.print("app firebase id : ${Firebase.app().options.projectId}");
      await meetingsCollection.doc(meetingId).collection('participants').doc('$userId').update({
        'lastHeartbeat': FieldValue.serverTimestamp(),
        'isActive': true,
      });
    } catch (e) {
      AppLogger.print('Error sending heartbeat: $e');
      rethrow;
    }
  }

  /// Clean up participants who haven't sent heartbeat in the last 2 minutes
  Future<void> cleanupInactiveParticipants(String meetingId) async {
    try {
      final twoMinutesAgo = DateTime.now().subtract(const Duration(minutes: 2));

      // Get all participants
      final participantsSnapshot = await meetingsCollection.doc(meetingId).collection('participants').get();

      final batch = _firestore.batch();
      final now = FieldValue.serverTimestamp();

      for (final doc in participantsSnapshot.docs) {
        final data = doc.data();
        final lastHeartbeat = data['lastHeartbeat'] as Timestamp?;

        // If no heartbeat in last 2 minutes, mark as inactive
        if (lastHeartbeat == null || lastHeartbeat.toDate().isBefore(twoMinutesAgo)) {
          batch.update(doc.reference, {'isActive': false, 'leaveTime': now, 'reason': 'timeout'});

          AppLogger.print('Marked participant ${data['userId']} as inactive due to timeout');
        }
      }

      await batch.commit();

      // Check if meeting should be ended (no active participants)
      final activeParticipants = await meetingsCollection.doc(meetingId).collection('participants').where('isActive', isEqualTo: true).get();

      if (activeParticipants.docs.isEmpty) {
        await meetingsCollection.doc(meetingId).update({'status': 'ended', 'actualEndTime': now, 'endReason': 'all_participants_timeout'});

        AppLogger.print('Meeting $meetingId ended due to all participants timing out');
      }
    } catch (e) {
      AppLogger.print('Error cleaning up inactive participants: $e');
      rethrow;
    }
  }

  Future<bool?> stopRecordingMix({required String meetingId}) async {
    final mixRecording = await AppHttpService().post(
      'api/agora/recording/stop',
      body: {'cname': meetingId, 'type': 'mix', 'uid': AppLocalStorage.getUserDetails().userId},
    );

    if (mixRecording == null) {
      debugPrint("mixRecording response is null while stopping recording");
    }

    if (mixRecording?['success'] == true) {
      debugPrint("recording stopped successfully");

      return true;
    } else {
      AppToastUtil.showErrorToast(mixRecording?['error_message'] ?? "Failed to stop recording");
    }
    return null;
  }

  Future<bool?> stopRecordingIndividuals({required String meetingId}) async {
    final singleRecording = await AppHttpService().post(
      'api/agora/recording/stop',
      body: {'cname': meetingId, 'type': 'individual', 'uid': AppLocalStorage.getUserDetails().userId},
    );

    if (singleRecording == null) {
      debugPrint("singleRecording response is null while stopping recording");
    }

    if (singleRecording?['success'] == true) {
      debugPrint("recording stopped successfully");

      return true;
    } else {
      AppToastUtil.showErrorToast(singleRecording?['error_message'] ?? "Failed to stop recording");
    }
    return null;
  }

  Future<bool?> startRecordingMix(String meetingId, {String token = ''}) async {
    if (token.isEmpty) {
      AppLogger.print('  Cannot start recording: Agora token is empty.');
      return false;
    }

    final mixRecording = await AppHttpService().post(
      'api/agora/recording/start',
      body: {'cname': meetingId, 'uid': AppLocalStorage.getUserDetails().userId, 'type': 'mix', "token": token},
    );

    if (mixRecording == null) {
      debugPrint("mixRecording response is null while starting recording");
    }

    if (mixRecording?['success'] == true) {
      debugPrint("recording started successfully");

      return true;
    } else {
      final mixError = mixRecording?['error_message'] ?? "Failed to start recording";
      AppToastUtil.showErrorToast(" $mixError");
    }
    return null;
  }

  Future<bool?> startRecordingIndividual(String meetingId, {String token = ''}) async {
    if (token.isEmpty) {
      AppLogger.print('  Cannot start recording: Agora token is empty.');
      return false;
    }

    final singleRecording = await AppHttpService().post(
      'api/agora/recording/start',
      body: {'cname': meetingId, 'uid': AppLocalStorage.getUserDetails().userId, 'type': 'individual', "token": token},
    );

    if (singleRecording == null) {
      debugPrint("singleRecording response is null while starting recording");
    }

    if (singleRecording?['success'] == true) {
      debugPrint("recording started successfully");

      return true;
    } else {
      final singleErrormessage = singleRecording?['error_message'] ?? "Failed to start recording";
      AppToastUtil.showErrorToast(" $singleErrormessage");
    }
    return null;
  }

  Future<bool> queryAgoraRecordingStatus(String meetingId, String type, int recorderId) async {
    final response = await AppHttpService().post(
      'api/agora/recording/status',
      body: {'cname': meetingId, 'uid': AppLocalStorage.getUserDetails().userId, 'type': type},
    );

    if (response == null) {
      debugPrint("response is null while querying recording status");
      return false;
    }

    return response['success'] == true;
  }

  Future<bool> updateRecordingUserStreamList(String meetingId, String type, List<String> userIds) async {
    final response = await AppHttpService().post(
      'api/agora/recording/update',
      body: {'cname': meetingId, 'uid': AppLocalStorage.getUserDetails().userId.toString(), 'type': type, 'audioSubscribeUids': userIds},
    );

    if (response == null) {
      debugPrint("response is null while querying recording status");
      return false;
    }

    return response['success'] ?? false;
  }

  Future<List<RecordingFileModel>?> getAllMixRecordings(String meetingId) async {
    final response = await AppHttpService().post('api/agora/recording/list/mix', body: {'channelName': meetingId, 'meetingId': meetingId});

    if (response == null) {
      debugPrint("response is null while fetching recording list");
      return null;
    }
    if (response['success'] == true) {
      if (response['data'] is List) {
        return (response['data'] as List).map((e) => RecordingFileModel.fromJson(e)).toList();
      }
    } else {
      AppLogger.print(" failed to fetch list of recording : $response, message: ${response['error_message']}");
    }

    return [];
  }

  Future<List<SpeakingEventModel>> getAllMeetingRecordings({required String meetingId}) async {
    try {
      List<SpeakingEventModel> allItems = [];
      final allRecordingDocs = (await AppFirebaseService.instance.meetingsCollection.doc(meetingId).collection('recordingTrack').get()).docs;

      for (QueryDocumentSnapshot doc in allRecordingDocs) {
        String recordingUrl = '';
        final docData = doc.data() as Map<String, dynamic>? ?? {};
        final startTime = docData['startTime'] as int? ?? 0;
        final endTime = docData['stopTime'] as int? ?? 0;

        // fetch recordingUrl from server
        final response = await AppHttpService().post(
          'api/agora/recording/list/individual',
          body: {'channelName': meetingId, 'type': 'mix', 'startTime': startTime, 'endTime': endTime},
        );

        if (response != null && response['success'] == true && response['data'] != null) {
          recordingUrl = response['data']['playableUrl'] ?? '';
        }

        if (recordingUrl.isNotEmpty) {
          final allSpeakingEventsOfThisRecordingDocs =
              (await AppFirebaseService.instance.meetingsCollection
                      .doc(meetingId)
                      .collection('recordingTrack')
                      .doc(doc.id)
                      .collection('speakingEvents')
                      .get())
                  .docs;

          for (QueryDocumentSnapshot item in allSpeakingEventsOfThisRecordingDocs) {
            final speakingEventDocData = item.data() as Map<String, dynamic>? ?? {};

            allItems.add(
              SpeakingEventModel(
                userId: speakingEventDocData['userId'].toString(),
                userName: speakingEventDocData['userName'],
                startTime: speakingEventDocData['start'],
                endTime: speakingEventDocData['stop'],
                recordingUrl: recordingUrl,
                trackStartTime: startTime,
                trackStopTime: endTime,
              ),
            );
          }
        }
      }
      return allItems;
    } catch (e, s) {
      debugPrint("error while fetching meeting recordings... $e, $s");
      return [];
    }
  }

  // Future<List<SpeakingEventModel>?> getAllIndividualRecordings(String meetingId) async {
  //   final response = await AppHttpService().post('api/agora/recording/list/individual', body: {'channelName': meetingId});

  //   if (response == null) {
  //     debugPrint("response is null while fetching individual recording list");
  //     return null;
  //   }
  //   AppLogger.print("data........ : ${response['success']} item lenth : ${response['data']?.length}");
  //   if (response['success'] == true) {
  //     final list = (response['data'] as List<dynamic>).map((e) => IndividualRecordingModel.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  //     final outPut = <SpeakingEventModel>[];
  //     for (var element in list) {
  //       if (element.speakingEvents.isNotEmpty) {
  //         for (var i = 0; i < element.speakingEvents.length; i++) {
  //           final item = element.speakingEvents[i];
  //           if (item.startTime != 0 && item.userId.isNotEmpty) {
  //             outPut.add(element.speakingEvents[i]);
  //           }
  //         }
  //       }
  //     }
  //     return outPut;
  //   } else {
  //     AppLogger.print(" failed to fetch list of individual recording : $response, message: ${response['error_message']}");
  //     return [];
  //   }
  // }

  /// Generates a random 7-digit number (1000000 - 9999999)
  int generate7DigitId() {
    final random = Random();
    return 1000000 + random.nextInt(9000000);
  }

  /// Generates a unique 7-digit user ID by checking Firestore
  Future<int> generateUniqueUserId() async {
    int uniqueId = -1;
    bool docExists = true;

    while (docExists) {
      uniqueId = generate7DigitId();

      final docRef = _firestore.collection('users').doc(uniqueId.toString());

      final docSnap = await docRef.get();
      docExists = docSnap.exists;
    }

    return uniqueId;
  }

  Future<void> cleanUpServiceSecureFiles() async {
    try {
      final resp = await AppHttpService().post('api/agora/recording/cleanupSecureFiles', body: {});
    } catch (e) {
      debugPrint("error caught in cleaning up secure files : $e");
    }
  }
}
