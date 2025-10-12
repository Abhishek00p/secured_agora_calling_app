import 'package:secured_calling/utils/app_tost_util.dart';
import 'package:secured_calling/core/services/app_auth_service.dart';

class AppPasswordResetService {
  /// Reset password for a user by admin or member
  /// Only admins can reset member passwords
  /// Only members can reset user passwords under their member code
  static Future<bool?> resetPassword({
    required String targetEmail,
    required String newPassword,
    required String currentUserEmail,
  }) async {
    try {
      // Use the new auth service to reset password
      final success = await AppAuthService.instance.resetPassword(targetEmail: targetEmail, newPassword: newPassword);
      if (success == null) {
        AppToastUtil.showErrorToast('Something went wrong, please try again');
        return null;
      }

      if (success) {
        AppToastUtil.showSuccessToast('Password reset successfully');
        return true;
      } else {
        AppToastUtil.showErrorToast('Failed to reset password');
        return false;
      }
    } catch (e) {
      AppToastUtil.showErrorToast('Failed to reset password: $e');
      return false;
    }
  }

  /// Get users that current user can reset passwords for
  static Future<List<Map<String, dynamic>>?> getUsersForPasswordReset() async {
    try {
      final users = await AppAuthService.instance.getUsersForPasswordReset();
      return users;
    } catch (e) {
      AppToastUtil.showErrorToast('Failed to get users: $e');
      return [];
    }
  }

  /// Get user credentials (email + password) for display
  static Future<Map<String, dynamic>?> getUserCredentials(String email) async {
    try {
      final credentials = await AppAuthService.instance.getUserCredentials(email);
      return credentials;
    } catch (e) {
      AppToastUtil.showErrorToast('Failed to get credentials: $e');
      return null;
    }
  }
}
