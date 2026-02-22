import 'package:cloud_firestore/cloud_firestore.dart';

class MeetingModel {
  final String meetId;
  final String meetingName;
  final String channelName;
  final int hostId;
  final int hostUserId;
  final String hostName;
  final String? password;
  final String? memberCode;
  final bool requiresApproval;
  final String status;

  final Map<String, bool> isParticipantsMuted; // Updated type
  final int maxParticipants;
  final int duration;

  final List<int> participants;
  final List<int> allParticipants;
  final List<int> pendingApprovals;
  final List<int> invitedUsers;

  // Time tracking fields
  final DateTime scheduledStartTime;
  final DateTime scheduledEndTime;
  final DateTime createdAt;
  final DateTime? actualStartTime;
  final DateTime? actualEndTime;

  // Meeting statistics
  final int totalParticipantsCount;
  final Duration actualDuration;
  final int? totalExtensions;

  // Detailed participant tracking
  final List<ParticipantLog> participantHistory;
  final bool isRecordingOn;

  const MeetingModel({
    required this.meetId,
    required this.meetingName,
    required this.channelName,
    required this.hostId,
    required this.hostName,
    this.password,
    this.memberCode,
    required this.requiresApproval,
    required this.status,
    required this.isParticipantsMuted,
    required this.maxParticipants,
    required this.duration,
    required this.participants,
    required this.allParticipants,
    required this.pendingApprovals,
    required this.invitedUsers,
    required this.scheduledStartTime,
    required this.scheduledEndTime,
    required this.createdAt,
    this.actualStartTime,
    this.actualEndTime,
    required this.hostUserId,
    required this.totalParticipantsCount,
    required this.actualDuration,
    this.totalExtensions,
    required this.participantHistory,
    this.isRecordingOn = false,
  });

  bool get isEmpty => this == MeetingModel.toEmpty();

  factory MeetingModel.toEmpty() => MeetingModel(
    meetId: '',
    meetingName: '',
    channelName: '',
    hostId: -1,
    hostUserId: 0,
    hostName: '',
    password: null,
    memberCode: null,
    requiresApproval: false,
    status: '',
    isParticipantsMuted: {},
    maxParticipants: 0,
    duration: 0,
    participants: [],
    allParticipants: [],
    pendingApprovals: [],
    invitedUsers: [],
    scheduledStartTime: DateTime.fromMillisecondsSinceEpoch(0),
    scheduledEndTime: DateTime.fromMillisecondsSinceEpoch(0),
    createdAt: DateTime.fromMillisecondsSinceEpoch(0),
    actualStartTime: null,
    actualEndTime: null,
    totalParticipantsCount: 0,
    actualDuration: Duration.zero,
    totalExtensions: null,
    participantHistory: [],
  );

  static int getHostId(dynamic id) {
    if (id is String) {
      return id.isEmpty ? -1 : int.tryParse(id) ?? -1;
    } else if (id == null) {
      return -1;
    }
    return id;
  }

  factory MeetingModel.fromJson(Map<String, dynamic> json) {
    return MeetingModel(
      hostUserId: json['hostUserId'] ?? 0,
      meetId: json['meet_id'] ?? '',
      meetingName: json['meetingName'] ?? '',
      channelName: json['channelName'] ?? '',
      hostId: getHostId(json['hostId']),
      hostName: json['hostName'] ?? '',
      password: json['password'],
      memberCode: json['memberCode'],
      requiresApproval: json['requiresApproval'] ?? false,
      status: json['status'] ?? '',
      isParticipantsMuted: Map<String, bool>.from(
        json['isParticipantsMuted'] ?? {},
      ),
      maxParticipants: json['maxParticipants'] ?? 0,
      duration: json['duration'] ?? 0,
      participants: List<int>.from(json['participants'] ?? []),
      allParticipants: List<int>.from(json['allParticipants'] ?? []),
      pendingApprovals: List<int>.from(json['pendingApprovals'] ?? []),
      invitedUsers: List<int>.from(json['invitedUsers'] ?? []),
      scheduledStartTime: _toDateTime(json['scheduledStartTime']),
      scheduledEndTime: _toDateTime(json['scheduledEndTime']),
      createdAt: _toDateTime(json['createdAt']),
      actualStartTime: _nullableDateTime(json['actualStartTime']),
      actualEndTime: _nullableDateTime(json['actualEndTime']),
      totalParticipantsCount: json['totalParticipantsCount'] ?? 0,
      actualDuration: _toDuration(json['actualDuration']),
      totalExtensions: json['totalExtensions'],
      participantHistory: _toParticipantLogList(json['participantHistory']),
      isRecordingOn: json['isRecordingOn'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'meet_id': meetId,
    'meetingName': meetingName,
    'channelName': channelName,
    'hostId': hostId,
    'hostName': hostName,
    'hostUserId': hostUserId,
    'password': password,
    'memberCode': memberCode,
    'requiresApproval': requiresApproval,
    'status': status,
    'isParticipantsMuted': isParticipantsMuted,
    'maxParticipants': maxParticipants,
    'duration': duration,
    'participants': participants,
    'allParticipants': allParticipants,
    'pendingApprovals': pendingApprovals,
    'invitedUsers': invitedUsers,
    'scheduledStartTime': scheduledStartTime.toIso8601String(),
    'scheduledEndTime': scheduledEndTime.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'actualStartTime': actualStartTime?.toIso8601String(),
    'actualEndTime': actualEndTime?.toIso8601String(),
    'totalParticipantsCount': totalParticipantsCount,
    'actualDuration': actualDuration.inSeconds,
    'totalExtensions': totalExtensions,
    'participantHistory':
        participantHistory.map((log) => log.toJson()).toList(),
    "isRecordingOn": isRecordingOn,
  };

  static DateTime _toDateTime(dynamic value) {
    if (value == null) return DateTime.fromMillisecondsSinceEpoch(0);
    if (value is Timestamp) return value.toDate();
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  static DateTime? _nullableDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static Duration _toDuration(dynamic value) {
    if (value == null) return Duration.zero;
    if (value is int) return Duration(seconds: value);
    if (value is String) {
      final seconds = int.tryParse(value);
      return seconds != null ? Duration(seconds: seconds) : Duration.zero;
    }
    return Duration.zero;
  }

  static List<ParticipantLog> _toParticipantLogList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((item) => ParticipantLog.fromJson(item)).toList();
    }
    return [];
  }
}

class ParticipantLog {
  final int userId;
  final String userName;
  final DateTime joinTime;
  final DateTime? leaveTime;
  final Duration? duration;

  const ParticipantLog({
    required this.userId,
    required this.userName,
    required this.joinTime,
    this.leaveTime,
    this.duration,
  });

  factory ParticipantLog.fromJson(Map<String, dynamic> json) {
    return ParticipantLog(
      userId: json['userId'] ?? 0,
      userName: json['userName'] ?? '',
      joinTime: MeetingModel._toDateTime(json['joinTime']),
      leaveTime: MeetingModel._nullableDateTime(json['leaveTime']),
      duration: MeetingModel._toDuration(json['duration']),
    );
  }

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'userName': userName,
    'joinTime': joinTime.toIso8601String(),
    'leaveTime': leaveTime?.toIso8601String(),
    'duration': duration?.inSeconds,
  };

  ParticipantLog copyWith({
    int? userId,
    String? userName,
    DateTime? joinTime,
    DateTime? leaveTime,
    Duration? duration,
  }) {
    return ParticipantLog(
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      joinTime: joinTime ?? this.joinTime,
      leaveTime: leaveTime ?? this.leaveTime,
      duration: duration ?? this.duration,
    );
  }
}
