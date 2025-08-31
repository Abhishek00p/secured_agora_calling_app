import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:secured_calling/utils/app_tost_util.dart';
import 'package:secured_calling/core/services/app_user_role_service.dart';
import 'package:secured_calling/core/services/app_local_storage.dart';

class AppPasswordResetService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Reset password for a user by admin or member
  /// Only admins can reset member passwords
  /// Only members can reset user passwords under their member code
  static Future<bool> resetPassword({
    required String targetEmail,
    required String newPassword,
    required String currentUserEmail,
  }) async {
    try {
      // Get current user details
      final currentUser = AppLocalStorage.getUserDetails();
      final currentUserRole = AppUserRoleService.getCurrentUserRole();

      // Verify permissions
      if (!(await _canResetPassword(currentUserRole, currentUser, targetEmail))) {
        AppToastUtil.showErrorToast('You do not have permission to reset this user\'s password');
        return false;
      }

      // Find the target user in Firestore
      final userQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: targetEmail)
          .get();

      if (userQuery.docs.isEmpty) {
        AppToastUtil.showErrorToast('User not found');
        return false;
      }

      final targetUserDoc = userQuery.docs.first;
      final targetUserData = targetUserDoc.data();

      // Reset password in Firebase Auth
      await _auth.sendPasswordResetEmail(email: targetEmail);

      // Update password in Firestore (store temporary password)
      await targetUserDoc.reference.update({
        'temporaryPassword': newPassword,
        'passwordResetBy': currentUserEmail,
        'passwordResetAt': DateTime.now().toIso8601String(),
      });

      AppToastUtil.showSuccessToast('Password reset email sent to $targetEmail');
      return true;
    } catch (e) {
      AppToastUtil.showErrorToast('Failed to reset password: $e');
      return false;
    }
  }

  /// Check if current user can reset password for target user
  static Future<bool> _canResetPassword(
    UserRole currentUserRole,
    dynamic currentUser,
    String targetEmail,
  ) async {
    // Admin can reset any member's password
    if (currentUserRole == UserRole.admin || currentUserRole == UserRole.superAdmin) {
      // Check if target is a member
      return await _isTargetUserMember(targetEmail);
    }

    // Member can only reset passwords for users under their member code
    if (currentUserRole == UserRole.member) {
      return await _isTargetUserUnderMember(targetEmail, currentUser.memberCode);
    }

    // Regular users cannot reset any passwords
    return false;
  }

  /// Check if target user is a member
  static Future<bool> _isTargetUserMember(String targetEmail) async {
    try {
      final userQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: targetEmail)
          .get();

      if (userQuery.docs.isEmpty) return false;

      final userData = userQuery.docs.first.data();
      return userData['isMember'] == true;
    } catch (e) {
      return false;
    }
  }

  /// Check if target user is under the specified member code
  static Future<bool> _isTargetUserUnderMember(String targetEmail, String memberCode) async {
    try {
      final userQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: targetEmail)
          .where('memberCode', isEqualTo: memberCode)
          .get();

      return userQuery.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Get users that current user can reset passwords for
  static Future<List<Map<String, dynamic>>> getUsersForPasswordReset() async {
    try {
      final currentUser = AppLocalStorage.getUserDetails();
      final currentUserRole = AppUserRoleService.getCurrentUserRole();

      if (currentUserRole == UserRole.admin || currentUserRole == UserRole.superAdmin) {
        // Admin can see all members
        final membersQuery = await _firestore
            .collection('users')
            .where('isMember', isEqualTo: true)
            .get();

        return membersQuery.docs.map((doc) {
          final data = doc.data();
          return {
            'userId': doc.id,
            'name': data['name'] ?? '',
            'email': data['email'] ?? '',
            'memberCode': data['memberCode'] ?? '',
            'isMember': true,
          };
        }).toList();
      } else if (currentUserRole == UserRole.member) {
        // Member can see users under their member code
        final usersQuery = await _firestore
            .collection('users')
            .where('memberCode', isEqualTo: currentUser.memberCode)
            .where('isMember', isEqualTo: false)
            .get();

        return usersQuery.docs.map((doc) {
          final data = doc.data();
          return {
            'userId': doc.id,
            'name': data['name'] ?? '',
            'email': data['email'] ?? '',
            'memberCode': data['memberCode'] ?? '',
            'isMember': false,
          };
        }).toList();
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  /// Get user credentials (email + password) for display
  static Future<Map<String, dynamic>?> getUserCredentials(String email) async {
    try {
      final currentUser = AppLocalStorage.getUserDetails();
      final currentUserRole = AppUserRoleService.getCurrentUserRole();

      // Check permissions
      if (currentUserRole == UserRole.admin || currentUserRole == UserRole.superAdmin) {
        // Admin can see member credentials
        final userQuery = await _firestore
            .collection('users')
            .where('email', isEqualTo: email)
            .where('isMember', isEqualTo: true)
            .get();

        if (userQuery.docs.isNotEmpty) {
          final userData = userQuery.docs.first.data();
          return {
            'email': userData['email'],
            'password': userData['temporaryPassword'] ?? 'No temporary password set',
            'name': userData['name'],
            'memberCode': userData['memberCode'],
          };
        }
      } else if (currentUserRole == UserRole.member) {
        // Member can see user credentials under their member code
        final userQuery = await _firestore
            .collection('users')
            .where('email', isEqualTo: email)
            .where('memberCode', isEqualTo: currentUser.memberCode)
            .where('isMember', isEqualTo: false)
            .get();

        if (userQuery.docs.isNotEmpty) {
          final userData = userQuery.docs.first.data();
          return {
            'email': userData['email'],
            'password': userData['temporaryPassword'] ?? 'No temporary password set',
            'name': userData['name'],
            'memberCode': userData['memberCode'],
          };
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }
}
