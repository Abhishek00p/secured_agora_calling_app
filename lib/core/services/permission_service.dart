import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:secured_calling/utils/permission_popup.dart';

class PermissionService {
  static Future<bool> requestPermission({
    required BuildContext context,
    required AppPermissionType type,
  }) async {
    final permission = type.permission;
    final status = await permission.status;

    if (status.isGranted) return true;

    final shouldRequest = await showDialog<bool>(
      context: context,
      builder:
          (_) => PermissionPopup(
            icon: type.icon,
            title: type.title,
            description: type.description,
          ),
    );

    if (shouldRequest == true) {
      final newStatus = await permission.request();
      return newStatus.isGranted;
    }

    return false;
  }
}

enum AppPermissionType {
  microphone,
  camera,
  storage,
  photos,
  notification,
  location,
  bluetooth,
}

extension AppPermissionTypeExtension on AppPermissionType {
  /// Get corresponding system permission
  Permission get permission {
    switch (this) {
      case AppPermissionType.microphone:
        return Permission.microphone;
      case AppPermissionType.camera:
        return Permission.camera;
      case AppPermissionType.storage:
        return Permission.storage;
      case AppPermissionType.photos:
        return Permission.photos;
      case AppPermissionType.notification:
        return Permission.notification;
      case AppPermissionType.location:
        return Permission.location;
      case AppPermissionType.bluetooth:
        return Permission.bluetooth;
    }
  }

  /// Optional: Icon to show in popup
  IconData get icon {
    switch (this) {
      case AppPermissionType.microphone:
        return Icons.mic;
      case AppPermissionType.camera:
        return Icons.videocam;
      case AppPermissionType.storage:
        return Icons.folder;
      case AppPermissionType.photos:
        return Icons.photo;
      case AppPermissionType.notification:
        return Icons.notifications;
      case AppPermissionType.location:
        return Icons.location_on;
      case AppPermissionType.bluetooth:
        return Icons.bluetooth;
    }
  }

  /// Optional: Default title
  String get title {
    return '${name[0].toUpperCase()}${name.substring(1)} Access';
  }

  /// Optional: Default description
  String get description {
    switch (this) {
      case AppPermissionType.microphone:
        return 'We need access to your microphone for audio communication.';
      case AppPermissionType.camera:
        return 'We need access to your camera for video calling.';
      case AppPermissionType.storage:
        return 'Storage access is required to read and save files.';
      case AppPermissionType.photos:
        return 'Photo access is needed to pick or upload images.';
      case AppPermissionType.notification:
        return 'Allow notifications to stay updated with important alerts.';
      case AppPermissionType.location:
        return 'Location access helps provide location-based features.';
      case AppPermissionType.bluetooth:
        return 'Bluetooth is required to connect with nearby devices.';
    }
  }
}
