import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:secured_calling/app_logger.dart';
import 'package:secured_calling/app_meeting_id_genrator.dart';
import 'package:secured_calling/core/models/app_user_model.dart';
import 'package:secured_calling/core/services/app_local_storage.dart';

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
        return AppUser.fromJson((res.data() as Map<String, dynamic>));
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

  // Meeting methods
  Future<DocumentReference> createMeeting({
    required String hostId,
    required String meetingName,
    required String channelName,
    required DateTime scheduledStartTime,
    required int duration, // in minutes
    String? password,
    bool requiresApproval = false,
  }) async {
    final meetingDocId = await AppMeetingIdGenrator.generateMeetingId();
    await meetingsCollection.doc(meetingDocId).set({
      'hostId': hostId,
      'meet_id': meetingDocId,
      'meetingName': meetingName,
      'channelName': channelName,
      'password': password,
      'scheduledStartTime': scheduledStartTime.toIso8601String(),
      'scheduledEndTime':
          scheduledStartTime.add(Duration(minutes: duration)).toIso8601String(),
      'actualStartTime': null,
      'actualEndTime': null,
      'createdAt': DateTime.now().toIso8601String(),
      'requiresApproval': requiresApproval,
      'status': 'scheduled', // scheduled, live, ended, cancelled
      'participants': [],
      'pendingApprovals': [],
    });
    return meetingsCollection.doc(meetingDocId);
  }

  Future<void> startMeeting(String meetingId) async {
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

  // Helper methods
  String _generateRandomChannelName() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890';
    final rnd = DateTime.now().millisecondsSinceEpoch.toString();
    return 'meeting_${rnd.substring(rnd.length - 8)}';
  }

  Future<List<String>> getAllMeetDocIds() async {
    return (await meetingsCollection.get()).docs.map((e) => e.id).toList();
  }

  Future<String> getAgoraToken() async {
    return (await _firestore.collection('token').doc('temptoken').get())
            .data()?['token'] ??
        '';
  }
}
