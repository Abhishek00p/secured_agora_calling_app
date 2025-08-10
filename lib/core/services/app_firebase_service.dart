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

class AppFirebaseService {
  // Singleton pattern
  AppFirebaseService._();
  static final AppFirebaseService _instance = AppFirebaseService._();
  static AppFirebaseService get instance => _instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Auth getters
  FirebaseAuth get auth => _auth;
  User? get currentUser => _auth.currentUser;
  bool get isUserLoggedIn => currentUser != null;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Firestore references
  CollectionReference get usersCollection => _firestore.collection('users');
  CollectionReference get meetingsCollection =>
      _firestore.collection('meetings');
  CollectionReference get callLogsCollection =>
      _firestore.collection('call_logs');

  // User methods
  Future<bool> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
    required String memberCode,
  }) async {
    try {
      // Create user with email and password
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        await FirebaseAuth.instance.currentUser?.sendEmailVerification();

        final unqiueUserId = await generateUniqueUserId();
        // Create user profile in Firestore
        final userData = {
          'name': name,
          'email': email,
          'userId': unqiueUserId,
          'memberCode': memberCode,
          'firebaseUserId': userCredential.user!.uid,
          'createdAt': DateTime.now().toIso8601String(),
          'isMember': false, // By default, new users are not members
          'subscription': null,
        };
        await usersCollection.doc('$unqiueUserId').set(userData);
        final inputCode = memberCode.toLowerCase();
        final memberSnapshot =
            await FirebaseFirestore.instance.collection('members').get();

        QueryDocumentSnapshot? matchingDoc;
        try {
          matchingDoc = memberSnapshot.docs.firstWhere(
            (doc) => (doc['memberCode'] as String).toLowerCase() == inputCode,
          );
        } catch (_) {
          matchingDoc = null;
        }

        if (matchingDoc != null) {
          await FirebaseFirestore.instance
              .collection('members')
              .doc(matchingDoc.id)
              .update({
                'userId': unqiueUserId,
                'totalUsers': FieldValue.increment(1),
              });
        }

        AppLocalStorage.storeUserDetails(AppUser.fromJson(userData));
        // Update display name
        await userCredential.user!.updateDisplayName(name);
      }

      return userCredential.user != null;
    } catch (e) {
      AppLogger.print('error caught in fireb service :$e');
      rethrow;
    }
  }

  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<bool?> sendResetPasswordEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      AppToastUtil.showSuccessToast('Password reset email sent successfully');
      return true;
    } on FirebaseAuthException catch (e) {
      AppToastUtil.showErrorToast(
        e.message ?? 'Error occurred while sending reset email',
      );
    }
    return null;
  }

  Future<void> updateLoginPassword({
    required String email,
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Re-authenticate the user
        final credential = EmailAuthProvider.credential(
          email: email,
          password: oldPassword,
        );
        await user.reauthenticateWithCredential(credential);

        // Update the password
        await user.updatePassword(newPassword);
        AppToastUtil.showSuccessToast('Password updated successfully');
      }
    } on FirebaseAuthException catch (e) {
      AppToastUtil.showErrorToast(
        e.message ?? 'Error occurred while updating password',
      );
    }
  }

  Future<bool> signOut() async {
    try {
      await _auth.signOut();
      return true;
    } catch (e) {
      AppLogger.print("cant signout user from firebase : $e");
      return false;
    }
  }

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

  Future<int> generateUniqueUserId() async {
    final Random random = Random();

    int maxAttempts = 10; // Prevents infinite loop
    int attempt = 0;

    while (attempt < maxAttempts) {
      int randomId = random.nextInt(10000000); // 0 to 9,999,999

      // Check if any user has this userId
      final query =
          await AppFirebaseService.instance.usersCollection
              .where('userId', isEqualTo: randomId)
              .limit(1)
              .get();

      if (query.docs.isEmpty) {
        return randomId; // Unique ID found
      }

      attempt++;
    }

    throw Exception(
      'Failed to generate a unique userId after $maxAttempts attempts',
    );
  }

  Future<AppUser> getLoggedInUserDataAsModel() async {
    final uid = _auth.currentUser?.uid ?? '';
    if (uid.trim().isNotEmpty) {
      AppLogger.print('curretn user ID : $uid');
      final res =
          (await usersCollection.where('firebaseUserId', isEqualTo: uid).get())
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

  Stream<DocumentSnapshot> getUserDataStream(String uid) {
    return usersCollection.doc(uid).snapshots();
  }

  Future<void> updateUserData(String uid, Map<String, dynamic> data) async {
    await usersCollection.doc(uid).update(data);
  }

/// return meeting id if created successfully, otherwise null
  Future<String?> createPrivateMeeting(PrivateMeetingModel model) async {
    try {
      final meetingDoc = await meetingsCollection.add(model.toJson());
      return meetingDoc.id;
    } catch (e) {
      AppLogger.print('Error creating private meeting: $e');
      return null;
    }
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
    required String hostName, required int hostUserId,
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
      'participants': [],
      'pendingApprovals': [],
      'speakRequests': [],
      'approvedSpeakers': [],
      'invitedUsers': [],
      'memberCode': AppLocalStorage.getUserDetails().memberCode.toUpperCase(),
    });
    return meetingsCollection.doc(meetingDocId);
  }

  Future<void> startMeeting(String meetingId) async {
    AppLogger.print('meeting id : $meetingId');
    await meetingsCollection.doc(meetingId).update({
      'status': 'live',
      'actualStartTime': FieldValue.serverTimestamp(),
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
      final meetingData =
          (await meetingsCollection.doc(meetId).get()).data()
              as Map<String, dynamic>?;
      final participants =
          (meetingData?['participants'] as List<dynamic>? ?? []);
      participants.add(userId);
      await meetingsCollection.doc(meetId).update({
        'participants': participants,
        'allParticipants': FieldValue.arrayUnion([userId]),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> removeParticipants(String meetId, int userId) async {
    try {
      final meetingData =
          (await meetingsCollection.doc(meetId).get()).data()
              as Map<String, dynamic>?;
      final participants =
          (meetingData?['participants'] as List<dynamic>? ?? []);
      participants.removeWhere((item) => item == userId);
      await meetingsCollection.doc(meetId).update({
        'participants': participants,
      });

      if (participants.isEmpty) {
        await meetingsCollection.doc(meetId).update({
          'status': 'ended',
          'actualEndTime': FieldValue.serverTimestamp(),
        });
      }
      return true;
    } catch (e) {
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
    final meetingDoc = await meetingsCollection.doc(meetingId).get();
    final meetingData = meetingDoc.data() as Map<String, dynamic>;

    final currentEndTime =
        (meetingData['scheduledEndTime'] as Timestamp).toDate();
    final newEndTime = currentEndTime.add(Duration(minutes: additionalMinutes));

    await meetingsCollection.doc(meetingId).update({
      'scheduledEndTime': newEndTime,
    });
  }

  Future<void> requestToJoinMeeting(String meetingId, int userId) async {
    await meetingsCollection.doc(meetingId).update({
      'pendingApprovals': FieldValue.arrayUnion([userId]),
    });
  }

  Future<void> approveMeetingJoinRequest(String meetingId, int userId) async {
    await meetingsCollection.doc(meetingId).update({
      'pendingApprovals': FieldValue.arrayRemove([userId]),
      'participants': FieldValue.arrayUnion([userId]),
      'allParticipants': FieldValue.arrayUnion([userId]),
    });
  }

  Future<void> rejectMeetingJoinRequest(String meetingId, int userId) async {
    await meetingsCollection.doc(meetingId).update({
      'pendingApprovals': FieldValue.arrayRemove([userId]),
    });
  }

  Stream<QuerySnapshot> getHostMeetingsStream(String hostId) {
    return meetingsCollection
        .where('hostId', isEqualTo: hostId)
        .orderBy('scheduledStartTime', descending: true)
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
    required bool isHost
  }) async {
    return await AppHttpService().fetchAgoraToken(
          channelName: channelName,
          uid: uid,userRole: isHost?1:0
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

  removeAllParticipants(String meetingId) {
    meetingsCollection.doc(meetingId).update({'isInstructedToLeave': true});
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

  // Methods for "Request to Speak" feature
  Future<void> requestToSpeak(String meetingId, int userId) async {
    await meetingsCollection.doc(meetingId).update({
      'speakRequests': FieldValue.arrayUnion([userId]),
    });
  }

  Future<void> cancelRequestToSpeak(String meetingId, int userId) async {
    await meetingsCollection.doc(meetingId).update({
      'speakRequests': FieldValue.arrayRemove([userId]),
    });
  }

  Future<void> approveSpeakRequest(String meetingId, int userId) async {
    await meetingsCollection.doc(meetingId).update({
      'speakRequests': FieldValue.arrayRemove([userId]),
      'approvedSpeakers': FieldValue.arrayUnion([userId]),
    });
  }

  Future<void> rejectSpeakRequest(String meetingId, int userId) async {
    await meetingsCollection.doc(meetingId).update({
      'speakRequests': FieldValue.arrayRemove([userId]),
    });
  }

  Future<void> revokeSpeakingPermission(String meetingId, int userId) async {
    await meetingsCollection.doc(meetingId).update({
      'approvedSpeakers': FieldValue.arrayRemove([userId]),
    });
  }

  Stream<DocumentSnapshot> getMeetingStream(String meetingId) {
    return meetingsCollection.doc(meetingId).snapshots();
  }
}
