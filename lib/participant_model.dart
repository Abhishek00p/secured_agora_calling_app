import 'package:flutter/material.dart';
import 'package:secured_calling/warm_color_generator.dart';

class ParticipantModel {
  final int userId;
  final String firebaseUid;
  final String name;
  final bool isUserMuted;
  final bool isUserSpeaking;
  final Color color;

  ParticipantModel({
    required this.userId,
    required this.firebaseUid,
    required this.name,
    required this.isUserMuted,
    required this.isUserSpeaking,
    required this.color,
  });

  factory ParticipantModel.fromJson(Map<String, dynamic> json) {
    return ParticipantModel(
      userId: json['userId'] ?? 0,
      firebaseUid: json['firebaseUid'] ?? '',
      name: json['name'] ?? '',
      isUserMuted: json['isUserMuted'] ?? false,
      isUserSpeaking: json['isUserSpeaking'] ?? false,
      color:json['color']==null? WarmColorGenerator.getRandomWarmColor(): Color(json['color']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'firebaseUid': firebaseUid,
      'name': name,
      'isUserMuted': isUserMuted,
      'isUserSpeaking':isUserSpeaking,
      'color':color.toARGB32(),
    };
  }

  ParticipantModel copyWith({
    int? userId,
    String? firebaseUid,
    String? name,
    bool? isUserMuted,
    bool? isUserSpeaking,
    Color? color,
  }) {
    return ParticipantModel(
      userId: userId ?? this.userId,
      firebaseUid: firebaseUid ?? this.firebaseUid,
      name: name ?? this.name,
      isUserMuted: isUserMuted ?? this.isUserMuted,
      isUserSpeaking:isUserSpeaking?? this.isUserSpeaking,
      color: color ?? this.color,
    );
  }

  @override
  String toString() {
    return 'ParticipantModel(userId: $userId, firebaseUid: $firebaseUid, name: $name, isUserMuted: $isUserMuted, isUserSpeaking : $isUserSpeaking)';
  }
}
