class IndividualRecordingModel {
  int trackId;
  String url;
  List<SpeakingEventModel> speakingEvents;

  IndividualRecordingModel({required this.trackId, required this.url, required this.speakingEvents});

  factory IndividualRecordingModel.fromJson(Map<String, dynamic> json) {
    return IndividualRecordingModel(
      trackId: json['trackId'],
      url: json['recordingUrl'],
      speakingEvents: (json['speakingEvents'] as List<dynamic>).map((e) => SpeakingEventModel.fromJson(e)).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'trackId': trackId, 'recordingUrl': url, 'speakingEvents': speakingEvents.map((e) => e.toJson()).toList()};
  }
}

class SpeakingEventModel {
  final String userId;
  final String userName;
  final int startTime;
  final int endTime;
  final String recordingUrl;
  final int trackStartTime;
  final int trackStopTime;

  SpeakingEventModel({
    required this.userId,
    required this.userName,
    required this.startTime,
    required this.endTime,
    required this.recordingUrl,
    required this.trackStartTime,
    required this.trackStopTime,
  });

  factory SpeakingEventModel.fromJson(Map<String, dynamic> json) {
    return SpeakingEventModel(
      userId: (json['userId'] ?? '').toString(),
      userName: json['userName'] ?? '',
      startTime: json['start'] ?? 0,
      endTime: json['stop'] ?? 0,
      recordingUrl: json['recordingUrl'],
      trackStartTime: json['trackStartTime'] ?? 0,
      trackStopTime: json['trackStopTime'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'userName': userName,
      'startTime': startTime,
      'endTime': endTime,
      'recordingUrl': recordingUrl,
      'trackStartTime': trackStartTime,
      'trackStopTime': trackStopTime,
    };
  }
}
