import 'package:cloud_firestore/cloud_firestore.dart';

enum WebinarRole {
  host,
  subHost,
  participant,
}

extension WebinarRoleX on WebinarRole {
  String get asKey {
    switch (this) {
      case WebinarRole.host:
        return 'HOST';
      case WebinarRole.subHost:
        return 'SUBHOST';
      case WebinarRole.participant:
        return 'PARTICIPANT';
    }
  }

  static WebinarRole fromKey(String key) {
    switch (key) {
      case 'HOST':
        return WebinarRole.host;
      case 'SUBHOST':
        return WebinarRole.subHost;
      case 'PARTICIPANT':
      default:
        return WebinarRole.participant;
    }
  }
}

class WebinarUserModel {
  final String userId; // Firebase Auth uid or app uid
  final int agoraUid; // Deterministic UID for Agora
  final String displayName;
  final WebinarRole role;
  final bool isMicMuted;
  final bool canSpeak; // Granted permission by Host/SubHost
  final bool isKicked;

  const WebinarUserModel({
    required this.userId,
    required this.agoraUid,
    required this.displayName,
    required this.role,
    required this.isMicMuted,
    required this.canSpeak,
    required this.isKicked,
  });

  WebinarUserModel copyWith({
    String? userId,
    int? agoraUid,
    String? displayName,
    WebinarRole? role,
    bool? isMicMuted,
    bool? canSpeak,
    bool? isKicked,
  }) {
    return WebinarUserModel(
      userId: userId ?? this.userId,
      agoraUid: agoraUid ?? this.agoraUid,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      isMicMuted: isMicMuted ?? this.isMicMuted,
      canSpeak: canSpeak ?? this.canSpeak,
      isKicked: isKicked ?? this.isKicked,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'agoraUid': agoraUid,
      'displayName': displayName,
      'role': role.asKey,
      'isMicMuted': isMicMuted,
      'canSpeak': canSpeak,
      'isKicked': isKicked,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory WebinarUserModel.fromMap(Map<String, dynamic> map) {
    return WebinarUserModel(
      userId: map['userId'] as String,
      agoraUid: (map['agoraUid'] as num).toInt(),
      displayName: (map['displayName'] ?? '') as String,
      role: WebinarRoleX.fromKey((map['role'] ?? 'PARTICIPANT') as String),
      isMicMuted: (map['isMicMuted'] ?? true) as bool,
      canSpeak: (map['canSpeak'] ?? false) as bool,
      isKicked: (map['isKicked'] ?? false) as bool,
    );
  }
}


