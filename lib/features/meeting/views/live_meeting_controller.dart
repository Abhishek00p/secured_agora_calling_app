import 'package:get/get.dart';
import 'package:secured_calling/app_logger.dart';
import 'package:secured_calling/core/services/app_firebase_service.dart';
import 'package:secured_calling/features/meeting/services/agora_service.dart';

class MeetingController extends GetxController {
  final AppFirebaseService _firebaseService = AppFirebaseService.instance;
   String meetingId = '';
   bool isHost = false;
  bool get agoraInitialized => AgoraService().isInitialized;
  // Rx variables
  var isLoading = false.obs;
  var error = RxnString();
  var pendingRequests = <Map<String, dynamic>>[].obs;

  int remainingSeconds = 25200;
  RxBool isMuted = false.obs;
  MeetingController();

  void inint(String meetingid, bool isUserHost) async {
    try{
    meetingId = meetingid;
    isHost = isUserHost;

    AgoraService().initialize().then((V) {
      if (V) {
        if(meetingId.trim().isEmpty){
  
          AppLogger.print('meetingId is empty or null');
          return;
        }
        startTimer();
        AppFirebaseService.instance.startMeeting(meetingId);
      }
    });
    }catch(e){
      AppLogger.print('Something went wrong in init of controller : $e');
    }
    update();
  }

  startTimer() async {
    while (remainingSeconds > 0) {
      await Future.delayed(Duration(seconds: 1));
      remainingSeconds--;
      update();
    }
  }

  Future<void> fetchPendingRequests() async {
    if (meetingId == null) return;

    isLoading.value = true;
    error.value = null;

    try {
      final meetingDoc =
          await _firebaseService.meetingsCollection.doc(meetingId).get();
      final meetingData = meetingDoc.data() as Map<String, dynamic>;
      final pendingUserIds = meetingData['pendingApprovals'] as List<dynamic>;

      final List<Map<String, dynamic>> requests = [];

      for (final userId in pendingUserIds) {
        final userDoc = await _firebaseService.getUserData(userId as String);
        final userData = userDoc.data() as Map<String, dynamic>?;
        if (userData != null) {
          requests.add({
            'userId': userId,
            'name': userData['name'] ?? 'Unknown User',
          });
        }
      }

      pendingRequests.value = requests;
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> rejectJoinRequest(String userId) async {
    if (meetingId == null) return;

    try {
      await _firebaseService.rejectMeetingJoinRequest(meetingId!, userId);
      await fetchPendingRequests();
    } catch (e) {
      error.value = 'Error rejecting request: $e';
    }
  }

  Future<void> endMeeting({required String meetingId}) async {
    try {
      final agoraService = AgoraService();
      await agoraService.leaveChannel();
      if (meetingId.isNotEmpty && isHost) {
        await _firebaseService.endMeeting(meetingId);
      }
    } catch (e) {
      AppLogger.print('Error ending meeting: $e');
    }
  }

  Future<void> toggleMute() async {
    isMuted.toggle();
  }
}
