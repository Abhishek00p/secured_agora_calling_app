class RecordingFileModel {
  final String key;
  final String playableUrl;
  final DateTime? lastModified;
  final DateTime? startTime;
  final DateTime? stopTime;
  final DateTime? recordingTime;
  final String? userName;
  final int? userId;
  final int size;

  const RecordingFileModel({
    required this.key,
    required this.playableUrl,
    required this.lastModified,
    required this.startTime,
    required this.stopTime,
    required this.size,
    required this.recordingTime,
    this.userName = '',
    this.userId,
  });

  /// -----------------------------
  /// EMPTY MODEL
  /// -----------------------------
  static RecordingFileModel empty() {
    return RecordingFileModel(key: '', playableUrl: '', lastModified: null, size: 0, startTime: null, stopTime: null, recordingTime: null);
  }

  /// -----------------------------
  /// IS EMPTY CHECK
  /// -----------------------------
  bool get isEmpty {
    return key.isEmpty && playableUrl.isEmpty && size == 0;
  }

  bool get isNotEmpty => !isEmpty;

  /// -----------------------------
  /// FROM JSON
  /// -----------------------------
  factory RecordingFileModel.fromJson(Map<String, dynamic> json) {
    return RecordingFileModel(
      key: json['key'] ?? '',
      playableUrl: json['playableUrl'] ?? '',
      lastModified: json['lastModified'] != null ? DateTime.tryParse(json['lastModified']) : null,
      size: (json['size'] ?? 0) is int ? json['size'] : int.tryParse(json['size'].toString()) ?? 0,

      startTime: json['startTime'] != null ? DateTime.tryParse(json['startTime']) : null,
      stopTime: json['stopTime'] != null ? DateTime.tryParse(json['stopTime']) : null,

      recordingTime: 
          json['recordingTime'] != null
              ? json['recordingTime'] is int?
                  ? DateTime.fromMillisecondsSinceEpoch(json['recordingTime'])
                  : DateTime.tryParse(json['recordingTime'])
              : null,
      userName: json['username'] ?? '',
      userId: json['userId'] is String ? int.tryParse(json['userId']) : json['userId'],
    );
  }

  /// -----------------------------
  /// TO JSON
  /// -----------------------------
  Map<String, dynamic> toJson() {
    return {'key': key, 'playableUrl': playableUrl, 'lastModified': lastModified?.toIso8601String(), 'size': size};
  }

  /// -----------------------------
  /// COPY WITH (OPTIONAL BUT USEFUL)
  /// -----------------------------
  RecordingFileModel copyWith({
    String? key,
    String? playableUrl,
    DateTime? lastModified,
    int? size,
    DateTime? startTime,
    DateTime? stopTime,
    DateTime? recordingTime,
    int? userId,
    String? userName,
  }) {
    return RecordingFileModel(
      key: key ?? this.key,
      playableUrl: playableUrl ?? this.playableUrl,
      lastModified: lastModified ?? this.lastModified,
      startTime: startTime ?? this.startTime,
      stopTime: stopTime ?? this.stopTime,
      size: size ?? this.size,
      recordingTime: recordingTime ?? this.recordingTime,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
    );
  }

  /// -----------------------------
  /// TO STRING
  /// -----------------------------
  @override
  String toString() {
    return 'RecordingFileModel('
        'key: $key, '
        'playableUrl: $playableUrl, '
        'lastModified: $lastModified, '
        'size: $size'
        ')';
  }
}
