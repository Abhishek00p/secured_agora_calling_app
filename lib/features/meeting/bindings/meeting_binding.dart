import 'package:get/get.dart';
import 'package:secured_calling/features/meeting/views/live_meeting_controller.dart';

class MeetingBinding extends Bindings {

  @override
  void dependencies() {
    Get.lazyPut(() => MeetingController());
  }
}
