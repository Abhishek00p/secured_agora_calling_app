import 'package:get/get.dart';
import 'package:secured_calling/features/auth/views/login_register_controller.dart';

class AuthBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => LoginRegisterController());
  }
}
