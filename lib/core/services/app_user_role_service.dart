import 'package:secured_calling/core/models/app_user_model.dart';
import 'package:secured_calling/core/services/app_local_storage.dart';

enum UserRole {
  user,
  member,
  admin,
  superAdmin,
}

class AppUserRoleService {
  static UserRole getUserRole(AppUser user) {
    // Check if user is admin (email contains 'flutter' - this should be improved)
    if (user.email.contains('flutter')) {
      return UserRole.admin;
    }
    
    // Check if user is a member
    if (user.isMember) {
      return UserRole.member;
    }
    
    // Default to regular user
    return UserRole.user;
  }
  
  static UserRole getCurrentUserRole() {
    final user = AppLocalStorage.getUserDetails();
    return getUserRole(user);
  }
  
  static bool isAdmin() {
    final role = getCurrentUserRole();
    return role == UserRole.admin || role == UserRole.superAdmin;
  }
  
  static bool isMember() {
    final role = getCurrentUserRole();
    return role == UserRole.member;
  }
  
  static bool isUser() {
    final role = getCurrentUserRole();
    return role == UserRole.user;
  }
  
  static String getRoleDisplayName(UserRole role) {
    switch (role) {
      case UserRole.user:
        return 'User';
      case UserRole.member:
        return 'Member';
      case UserRole.admin:
        return 'Admin';
      case UserRole.superAdmin:
        return 'Super Admin';
    }
  }
  
  static String getCurrentUserRoleDisplayName() {
    final role = getCurrentUserRole();
    return getRoleDisplayName(role);
  }
}
