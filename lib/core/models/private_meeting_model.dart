class PrivateMeetingModel {
  final String meetId;
  final String parentMeetingId;
  final String channelName;
  final int hostId;
  final String hostName;
  final int participantId;
  final String participantName;
  final int maxParticipants;
  final DateTime createdAt;
  final DateTime scheduledStartTime;
  final DateTime scheduledEndTime;
  final String status;
  final int duration;
  final Map<String, String> tokens;

  PrivateMeetingModel({
    required this.meetId,
    required this.parentMeetingId,
    required this.channelName,
    required this.hostId,
    required this.hostName,
    required this.participantId,
    required this.participantName,
    required this.maxParticipants,
    required this.createdAt,
    required this.scheduledStartTime,
    required this.scheduledEndTime,
    required this.status,
    required this.duration,
    required this.tokens,
  });

  factory PrivateMeetingModel.fromJson(Map<String, dynamic> json) {
    return PrivateMeetingModel(
      meetId: json['meet_id'],
      parentMeetingId: json['parentMeetingId'],
      channelName: json['channelName'],
      hostId: json['hostId'],
      hostName: json['hostName'],
      participantId: json['participantId'],
      participantName: json['participantName'],
      maxParticipants: json['maxParticipants'],
      createdAt: DateTime.parse(json['createdAt']),
      scheduledStartTime: DateTime.parse(json['scheduledStartTime']),
      scheduledEndTime: DateTime.parse(json['scheduledEndTime']),
      status: json['status'],
      duration: json['duration'],
      tokens: Map<String, String>.from(json['tokens'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'meet_id': meetId,
      'parentMeetingId': parentMeetingId,
      'channelName': channelName,
      'hostId': hostId,
      'hostName': hostName,
      'participantId': participantId,
      'participantName': participantName,
      'maxParticipants': maxParticipants,
      'createdAt': createdAt.toIso8601String(),
      'scheduledStartTime': scheduledStartTime.toIso8601String(),
      'scheduledEndTime': scheduledEndTime.toIso8601String(),
      'status': status,
      'duration': duration,
      'tokens': tokens,
    };
  }

  @override
  String toString() {
    return 'PrivateMeetingModel(meetId: $meetId, parentMeetingId: $parentMeetingId, channelName: $channelName, hostId: $hostId, hostName: $hostName, participantId: $participantId, participantName: $participantName, maxParticipants: $maxParticipants, createdAt: $createdAt, scheduledStartTime: $scheduledStartTime, scheduledEndTime: $scheduledEndTime, status: $status, duration: $duration, tokens: $tokens)';
  }
}
