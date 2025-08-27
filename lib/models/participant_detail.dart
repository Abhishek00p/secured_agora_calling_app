class ParticipantDetail {
  final String userId;
  final String username;
  final DateTime joinTime;
  final DateTime? leaveTime;

  ParticipantDetail({
    required this.userId,
    required this.username,
    required this.joinTime,
    this.leaveTime,
  });
}
