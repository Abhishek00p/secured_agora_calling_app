import 'package:get/get.dart';
import 'package:secured_calling/features/auth/views/login_register_controller.dart';

class AuthBinding extends Bindings {
  @override
  void dependencies() {
    // Use Get.put instead of Get.lazyPut to prevent premature disposal
    // This ensures the controller persists until explicitly removed
    Get.put(LoginRegisterController(), permanent: true);
  }
}
