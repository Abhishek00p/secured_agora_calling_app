import 'package:get/get.dart';
import 'package:secured_calling/core/routes/app_router.dart';
import 'package:secured_calling/core/services/app_auth_service.dart';
import 'package:secured_calling/features/meeting/bindings/live_meeting_controller.dart';
import 'package:secured_calling/utils/app_logger.dart';
import 'package:secured_calling/utils/app_tost_util.dart';

/// Runs when auth cannot be recovered (401 after refresh, or refresh failure).
/// Registered once from [main] via [AppHttpService.setSessionExpiredHandler].
class AppSessionExpiredHandler {
  AppSessionExpiredHandler._();

  static Future<void> handleSessionExpired() async {
    try {
      AppToastUtil.showErrorToast('Session expired. Please sign in again.');
      AppAuthService.instance.clearLocalSessionOnly();
      if (Get.isRegistered<MeetingController>()) {
        Get.delete<MeetingController>(force: true);
      }
      Get.offAllNamed(AppRouter.loginRoute);
    } catch (e, st) {
      AppLogger.print('Session expired handling error: $e');
      AppLogger.print('$st');
    }
  }
}
