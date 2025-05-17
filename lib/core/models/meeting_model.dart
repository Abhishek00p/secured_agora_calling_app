import 'package:cloud_firestore/cloud_firestore.dart';

class MeetingModel {
  final String meetId;
  final String meetingName;
  final String channelName;
  final String hostId;
  final String hostName;
  final String password;
  final bool requiresApproval;
  final String status;
  final bool isParticipantsMuted;
  final int maxParticipants;
  final int duration;

  final List<int> participants;
  final List<String> pendingApprovals;

  final DateTime scheduledStartTime;
  final DateTime scheduledEndTime;
  final DateTime createdAt;
  final DateTime actualStartTime;
  final DateTime actualEndTime;

  const MeetingModel({
    required this.meetId,
    required this.meetingName,
    required this.channelName,
    required this.hostId,
    required this.hostName,
    required this.password,
    required this.requiresApproval,
    required this.status,
    required this.isParticipantsMuted,
    required this.maxParticipants,
    required this.duration,
    required this.participants,
    required this.pendingApprovals,
    required this.scheduledStartTime,
    required this.scheduledEndTime,
    required this.createdAt,
    required this.actualStartTime,
    required this.actualEndTime,
  });

  /// Default empty instance
  factory MeetingModel.toEmpty() => MeetingModel(
        meetId: '',
        meetingName: '',
        channelName: '',
        hostId: '',
        hostName: '',
        password: '',
        requiresApproval: false,
        status: '',
        isParticipantsMuted: false,
        maxParticipants: 0,
        duration: 0,
        participants: [],
        pendingApprovals: [],
        scheduledStartTime: DateTime.fromMillisecondsSinceEpoch(0),
        scheduledEndTime: DateTime.fromMillisecondsSinceEpoch(0),
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        actualStartTime: DateTime.fromMillisecondsSinceEpoch(0),
        actualEndTime: DateTime.fromMillisecondsSinceEpoch(0),
      );

  bool get isEmpty => this == MeetingModel.toEmpty();

  factory MeetingModel.fromJson(Map<String, dynamic> json) {
    return MeetingModel(
      meetId: json['meet_id'] ?? '',
      meetingName: json['meetingName'] ?? '',
      channelName: json['channelName'] ?? '',
      hostId: json['hostId'] ?? '',
      hostName: json['hostName'] ?? '',
      password: json['password'] ?? '',
      requiresApproval: json['requiresApproval'] ?? false,
      status: json['status'] ?? '',
      isParticipantsMuted: (json['isParticipantsMuted'] as Map?)?.isNotEmpty ?? false,
      maxParticipants: json['maxParticipants'] ?? 0,
      duration: json['duration'] ?? 0,
      participants: List<int>.from(json['participants'] ?? []),
      pendingApprovals: List<String>.from(json['pendingApprovals'] ?? []),
      scheduledStartTime: _toDateTime(json['scheduledStartTime']),
      scheduledEndTime: _toDateTime(json['scheduledEndTime']),
      createdAt: _toDateTime(json['createdAt']),
      actualStartTime: _toDateTime(json['actualStartTime']),
      actualEndTime: _toDateTime(json['actualEndTime']),
    );
  }

  Map<String, dynamic> toJson() => {
        'meet_id': meetId,
        'meetingName': meetingName,
        'channelName': channelName,
        'hostId': hostId,
        'hostName': hostName,
        'password': password,
        'requiresApproval': requiresApproval,
        'status': status ,
        'isParticipantsMuted': isParticipantsMuted,
        'maxParticipants': maxParticipants,
        'duration': duration,
        'participants': participants,
        'pendingApprovals': pendingApprovals,
        'scheduledStartTime': scheduledStartTime.toIso8601String(),
        'scheduledEndTime': scheduledEndTime.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'actualStartTime': actualStartTime.toIso8601String(),
        'actualEndTime': actualEndTime.toIso8601String(),
      };

  MeetingModel copyWith({
    String? meetId,
    String? meetingName,
    String? channelName,
    String? hostId,
    String? hostName,
    String? password,
    bool? requiresApproval,
    String? status,
    bool? isParticipantsMuted,
    int? maxParticipants,
    int? duration,
    List<int>? participants,
    List<String>? pendingApprovals,
    DateTime? scheduledStartTime,
    DateTime? scheduledEndTime,
    DateTime? createdAt,
    DateTime? actualStartTime,
    DateTime? actualEndTime,
  }) {
    return MeetingModel(
      meetId: meetId ?? this.meetId,
      meetingName: meetingName ?? this.meetingName,
      channelName: channelName ?? this.channelName,
      hostId: hostId ?? this.hostId,
      hostName: hostName ?? this.hostName,
      password: password ?? this.password,
      requiresApproval: requiresApproval ?? this.requiresApproval,
      status: status ?? this.status,
      isParticipantsMuted: isParticipantsMuted ?? this.isParticipantsMuted,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      duration: duration ?? this.duration,
      participants: participants ?? this.participants,
      pendingApprovals: pendingApprovals ?? this.pendingApprovals,
      scheduledStartTime: scheduledStartTime ?? this.scheduledStartTime,
      scheduledEndTime: scheduledEndTime ?? this.scheduledEndTime,
      createdAt: createdAt ?? this.createdAt,
      actualStartTime: actualStartTime ?? this.actualStartTime,
      actualEndTime: actualEndTime ?? this.actualEndTime,
    );
  }

  @override
  String toString() {
    return 'MeetingModel(meetId: $meetId, title: $meetingName, statusLive: $status), scheduledStartTime: $scheduledStartTime, scheduledEndTime: $scheduledEndTime, createdAt: $createdAt, actualStartTime: $actualStartTime, actualEndTime: $actualEndTime, hostName: $hostName, hostId: $hostId, password: $password, requiresApproval: $requiresApproval, status: $status, isParticipantsMuted: $isParticipantsMuted, maxParticipants: $maxParticipants, duration: $duration, participants: $participants, pendingApprovals: $pendingApprovals)';
  }

  static DateTime _toDateTime(dynamic value) {
    if (value == null) return DateTime.fromMillisecondsSinceEpoch(0);
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}