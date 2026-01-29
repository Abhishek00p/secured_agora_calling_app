class MixRecordingModel {
  final String playableUrl;
  final int startTime;

  const MixRecordingModel({required this.playableUrl, required this.startTime});

  /// -----------------------------
  /// EMPTY MODEL
  /// -----------------------------
  static MixRecordingModel empty() {
    return MixRecordingModel(playableUrl: '', startTime: 0);
  }

  /// -----------------------------
  /// IS EMPTY CHECK
  /// -----------------------------
  bool get isEmpty {
    return playableUrl.isEmpty && startTime == 0;
  }

  bool get isNotEmpty => !isEmpty;

  /// -----------------------------
  /// FROM JSON
  /// -----------------------------
  factory MixRecordingModel.fromJson(Map<String, dynamic> json) {
    return MixRecordingModel(playableUrl: json['url'] ?? '', startTime: json['startTime'] ?? 0);
  }

  /// -----------------------------
  /// TO JSON
  /// -----------------------------
  Map<String, dynamic> toJson() {
    return {'playableUrl': playableUrl};
  }

  /// -----------------------------
  /// COPY WITH (OPTIONAL BUT USEFUL)
  /// -----------------------------
  MixRecordingModel copyWith({String? playableUrl, int? startTime}) {
    return MixRecordingModel(playableUrl: playableUrl ?? this.playableUrl, startTime: startTime ?? this.startTime);
  }

  /// -----------------------------
  /// TO STRING
  /// -----------------------------
  @override
  String toString() {
    return 'MixRecordingModel('
        'playableUrl: $playableUrl, startTime : $startTime'
        ')';
  }
}
