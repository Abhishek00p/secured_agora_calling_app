class RecordingTrackModel {
  bool isIndividual;
  bool isMix;
  int startTime;
  int endTime;

  RecordingTrackModel({
    required this.isIndividual,
    required this.isMix,
    required this.startTime,
    required this.endTime,
  });

  factory RecordingTrackModel.fromJson(Map<String, dynamic> json) {
    return RecordingTrackModel(
      isIndividual: json['isIndividual'] ?? false,
      isMix: json['isMix'] ?? false,
      startTime: json['startTime'] ?? 0,
      endTime: json['endTime'] ?? 0,
    );
  }
  toJson() {
    return {
      'isIndividual': isIndividual,
      'isMix': isMix,
      'startTime': startTime,
      'endTime': endTime,
    };
  }

  toempty() {
    return {
      'isIndividual': false,
      'isMix': false,
      'startTime': 0,
      'endTime': 0,
    };
  }

  isempty() {
    return !isIndividual && !isMix && startTime == 0 && endTime == 0;
  }

  copywith({bool? isIndividual, bool? isMix, int? startTime, int? endTime}) {
    return RecordingTrackModel(
      isIndividual: isIndividual ?? this.isIndividual,
      isMix: isMix ?? this.isMix,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }

  @override
  String toString() {
    return 'RecordingTrackModel{isIndividual: $isIndividual, isMix: $isMix, startTime: $startTime, endTime: $endTime}';
  }
}
