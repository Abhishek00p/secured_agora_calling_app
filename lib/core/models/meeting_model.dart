class MeetingModel {
  final String channelName;
  final String meetingId;
  final String hostId;
  final String meetingName;
  final List<int> participants;
  final String password;
  final List<int> pendingApprovals;
  final bool requiresApproval;
  final String status;
  final int duration;

  final DateTime scheduledStartTime;
  final DateTime scheduledEndTime;
  final DateTime actualStartTime;
  final DateTime actualEndTime;
  final DateTime createdAt;

  const MeetingModel({
    required this.hostId,
    required this.channelName,
    required this.meetingId,
    required this.meetingName,
    required this.participants,
    required this.password,
    required this.pendingApprovals,
    required this.requiresApproval,
    required this.status,
    required this.scheduledStartTime,
    required this.scheduledEndTime,
    required this.actualStartTime,
    required this.actualEndTime,
    required this.createdAt,
    this.duration = 0,
  });

  factory MeetingModel.fromJson(Map<String, dynamic> json) {
    return MeetingModel(
      channelName: json['channelName'] ?? '',
      hostId: json['hostId'] ?? '',
      meetingName: json['meetingName'] ?? '',
      participants: List<int>.from(json['participants'] ?? []),
      password: json['password'] ?? '',
      pendingApprovals: List<int>.from(json['pendingApprovals'] ?? []),
      requiresApproval: json['requiresApproval'] ?? false,
      status: json['status'] ?? '',
      scheduledStartTime:
          DateTime.tryParse(json['scheduledStartTime']?.toString() ?? '') ??
          DateTime(2000),
      scheduledEndTime:
          DateTime.tryParse(json['scheduledEndTime']?.toString() ?? '') ??
          DateTime(2000),
      actualStartTime:
          DateTime.tryParse(json['actualStartTime']?.toString() ?? '') ??
          DateTime(2000),
      actualEndTime:
          DateTime.tryParse(json['actualEndTime']?.toString() ?? '') ??
          DateTime(2000),
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime(2000),
      meetingId: json['meet_id'] ?? '',
      duration: json['duration'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'channelName': channelName,
      'hostId': hostId,
      'meet_id': meetingId,
      'meetingName': meetingName,
      'participants': participants,
      'password': password,
      'pendingApprovals': pendingApprovals,
      'requiresApproval': requiresApproval,
      'status': status,
      'scheduledStartTime': scheduledStartTime.toIso8601String(),
      'scheduledEndTime': scheduledEndTime.toIso8601String(),
      'actualStartTime': actualStartTime.toIso8601String(),
      'actualEndTime': actualEndTime.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'duration': duration,
    };
  }

  bool get isEmpty => this == MeetingModel.empty();

  factory MeetingModel.empty() => MeetingModel(
    channelName: '',
    hostId: '',
    meetingName: '',
    meetingId: '',
    participants: [],
    password: '',
    pendingApprovals: [],
    requiresApproval: false,
    status: '',
    scheduledStartTime: DateTime(2000),
    scheduledEndTime: DateTime(2000),
    actualStartTime: DateTime(2000),
    actualEndTime: DateTime(2000),
    createdAt: DateTime(2000),
    duration: 0,
  );

  @override
  String toString() {
    return 'MeetingModel(channelName: $channelName,meet_id: $meetingId, hostId: $hostId, meetingName: $meetingName, participants: $participants, password: $password, pendingApprovals: $pendingApprovals, requiresApproval: $requiresApproval, status: $status, scheduledStartTime: $scheduledStartTime, scheduledEndTime: $scheduledEndTime, actualStartTime: $actualStartTime, actualEndTime: $actualEndTime, createdAt: $createdAt duration: $duration)';
  }

  MeetingModel copyWith({
    String? channelName,
    String? hostId,
    String? meetingName,
    List<int>? participants,
    String? password,
    List<int>? pendingApprovals,
    bool? requiresApproval,
    String? status,
    DateTime? scheduledStartTime,
    DateTime? scheduledEndTime,
    DateTime? actualStartTime,
    DateTime? actualEndTime,
    DateTime? createdAt,
    String? meetingId,
    int? duration,
  }) {
    return MeetingModel(
      channelName: channelName ?? this.channelName,
      hostId: hostId ?? this.hostId,
      meetingName: meetingName ?? this.meetingName,
      participants: participants ?? this.participants,
      password: password ?? this.password,
      pendingApprovals: pendingApprovals ?? this.pendingApprovals,
      requiresApproval: requiresApproval ?? this.requiresApproval,
      status: status ?? this.status,
      scheduledStartTime: scheduledStartTime ?? this.scheduledStartTime,
      scheduledEndTime: scheduledEndTime ?? this.scheduledEndTime,
      actualStartTime: actualStartTime ?? this.actualStartTime,
      actualEndTime: actualEndTime ?? this.actualEndTime,
      createdAt: createdAt ?? this.createdAt,
      meetingId: meetingId ?? this.meetingId,
      duration: duration ?? this.duration,
    );
  }
}
