class ParticipantModel {
  final int userId;
  final String firebaseUid;
  final String name;
  final bool isUserMuted;

  ParticipantModel({
    required this.userId,
    required this.firebaseUid,
    required this.name,
    required this.isUserMuted,
  });

  factory ParticipantModel.fromJson(Map<String, dynamic> json) {
    return ParticipantModel(
      userId: json['userId'] ?? 0,
      firebaseUid: json['firebaseUid'] ?? '',
      name: json['name'] ?? '',
      isUserMuted: json['isUserMuted'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'firebaseUid': firebaseUid,
      'name': name,
      'isUserMuted': isUserMuted,
    };
  }

  ParticipantModel copyWith({
    int? userId,
    String? firebaseUid,
    String? name,
    bool? isUserMuted,
  }) {
    return ParticipantModel(
      userId: userId ?? this.userId,
      firebaseUid: firebaseUid ?? this.firebaseUid,
      name: name ?? this.name,
      isUserMuted: isUserMuted ?? this.isUserMuted,
    );
  }

  @override
  String toString() {
    return 'ParticipantModel(userId: $userId, firebaseUid: $firebaseUid, name: $name, isUserMuted: $isUserMuted)';
  }
}
