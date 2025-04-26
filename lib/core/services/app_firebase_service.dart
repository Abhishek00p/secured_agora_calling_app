import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:secured_calling/app_logger.dart';
import 'package:secured_calling/app_meeting_id_genrator.dart';
import 'package:secured_calling/core/models/app_user_model.dart';

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
  Future<UserCredential> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      // Create user with email and password
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Create user profile in Firestore
      await usersCollection.doc(userCredential.user!.uid).set({
        'name': name,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
        'isMember': false, // By default, new users are not members
        'subscription': null,
      });

      // Update display name
      await userCredential.user!.updateDisplayName(name);

      return userCredential;
    } catch (e) {
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

  Future<AppUser> getLoggedInUserDataAsModel() async {
    final uid = _auth.currentUser?.uid ?? '';
    if (uid.trim().isNotEmpty) {
      final res = (await usersCollection.doc(uid).get()).data();
      if (res != null) {
        return AppUser.fromJson((res as Map<String, dynamic>));
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
    required DateTime scheduledStartTime,
    required int duration, // in minutes
    String? password,
    bool requiresApproval = false,
  }) async {
    final meetingDocId = await AppMeetingIdGenrator.generateMeetingId();
    await meetingsCollection.doc(meetingDocId).set({
      'hostId': hostId,
      'meetingName': meetingName,
      'channelName': _generateRandomChannelName(),
      'password': password,
      'scheduledStartTime': scheduledStartTime,
      'scheduledEndTime': scheduledStartTime.add(Duration(minutes: duration)),
      'actualStartTime': null,
      'actualEndTime': null,
      'createdAt': FieldValue.serverTimestamp(),
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
    await meetingsCollection.doc(meetingId).update({
      'status': 'ended',
      'actualEndTime': FieldValue.serverTimestamp(),
    });
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

  Future<void> requestToJoinMeeting(String meetingId, String userId) async {
    await meetingsCollection.doc(meetingId).update({
      'pendingApprovals': FieldValue.arrayUnion([userId]),
    });
  }

  Future<void> approveMeetingJoinRequest(
    String meetingId,
    String userId,
  ) async {
    await meetingsCollection.doc(meetingId).update({
      'pendingApprovals': FieldValue.arrayRemove([userId]),
      'participants': FieldValue.arrayUnion([userId]),
    });
  }

  Future<void> rejectMeetingJoinRequest(String meetingId, String userId) async {
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
}
