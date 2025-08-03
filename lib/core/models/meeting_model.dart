
import 'package:cloud_firestore/cloud_firestore.dart';

class MeetingModel {
  final String meetId;
  final String meetingName;
  final String channelName;
  final String hostId;
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

  final DateTime scheduledStartTime;
  final DateTime scheduledEndTime;
  final DateTime createdAt;
  final DateTime actualStartTime;
  final DateTime? actualEndTime;

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
    required this.scheduledStartTime,
    required this.scheduledEndTime,
    required this.createdAt,
    required this.actualStartTime,
    this.actualEndTime,
    required this.hostUserId,
  });

  bool get isEmpty => this == MeetingModel.toEmpty();

  factory MeetingModel.toEmpty() => MeetingModel(
        meetId: '',
        meetingName: '',
        channelName: '',
        hostId: '',
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
        scheduledStartTime: DateTime.fromMillisecondsSinceEpoch(0),
        scheduledEndTime: DateTime.fromMillisecondsSinceEpoch(0),
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        actualStartTime: DateTime.fromMillisecondsSinceEpoch(0),

        actualEndTime: null,
      );

  factory MeetingModel.fromJson(Map<String, dynamic> json) {
    return MeetingModel(
      hostUserId: json['hostUserId'] ?? 0,
      meetId: json['meet_id'] ?? '',
      meetingName: json['meetingName'] ?? '',
      channelName: json['channelName'] ?? '',
      hostId: json['hostId'] ?? '',
      hostName: json['hostName'] ?? '',
      password: json['password'],
      memberCode: json['memberCode'],
      requiresApproval: json['requiresApproval'] ?? false,
      status: json['status'] ?? '',
      isParticipantsMuted: Map<String, bool>.from(json['isParticipantsMuted'] ?? {}),
      maxParticipants: json['maxParticipants'] ?? 0,
      duration: json['duration'] ?? 0,
      participants: List<int>.from(json['participants'] ?? []),
      allParticipants: List<int>.from(json['allParticipants'] ?? []),
      pendingApprovals: List<int>.from(json['pendingApprovals'] ?? []),
      scheduledStartTime: _toDateTime(json['scheduledStartTime']),
      scheduledEndTime: _toDateTime(json['scheduledEndTime']),
      createdAt: _toDateTime(json['createdAt']),
      actualStartTime: _toDateTime(json['actualStartTime']),
      actualEndTime: _nullableDateTime(json['actualEndTime']),
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
        'scheduledStartTime': scheduledStartTime.toIso8601String(),
        'scheduledEndTime': scheduledEndTime.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'actualStartTime': actualStartTime.toIso8601String(),
        'actualEndTime': actualEndTime?.toIso8601String(),
      };

  static DateTime _toDateTime(dynamic value) {
    if (value == null) return DateTime.fromMillisecondsSinceEpoch(0);
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  static DateTime? _nullableDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
