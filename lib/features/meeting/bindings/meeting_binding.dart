import 'package:get/get.dart';
import 'package:secured_calling/features/meeting/bindings/live_meeting_controller.dart';

class MeetingBinding extends Bindings {
  @override
  void dependencies() {
    // Keep controller alive so user can navigate away from meeting and return
    if (!Get.isRegistered<MeetingController>()) {
      Get.put(MeetingController(), permanent: true);
    }
  }
}
