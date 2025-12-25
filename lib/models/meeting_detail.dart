import 'package:secured_calling/models/participant_detail.dart';

class MeetingDetail {
  String meetingTitle;
  String meetingId;
  String? meetingPass;
  String hostName;
  int hostId;
  int maxParticipants;
  Duration duration;
  DateTime scheduledStartTime;
  DateTime scheduledEndTime;
  DateTime? actualStartTime;
  DateTime? actualEndTime;
  String status; // "upcoming", "ongoing", "ended"
  int totalUniqueParticipants;
  List<ParticipantDetail> participants;

  MeetingDetail({
    required this.meetingTitle,
    required this.meetingId,
    this.meetingPass,
    required this.hostName,
    required this.hostId,
    required this.maxParticipants,
    required this.duration,
    required this.scheduledStartTime,
    required this.scheduledEndTime,
    this.actualStartTime,
    this.actualEndTime,
    required this.status,
    required this.totalUniqueParticipants,
    required this.participants,
  });
}
