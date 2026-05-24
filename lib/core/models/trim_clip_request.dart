class TrimClipRequest {
  final String clipId;
  final int recordingFullStartTime;
  final int recordingFullEndTime;
  final int trimmedStartTime;
  final int trimmedEndTime;

  const TrimClipRequest({
    required this.clipId,
    required this.recordingFullStartTime,
    required this.recordingFullEndTime,
    required this.trimmedStartTime,
    required this.trimmedEndTime,
  });

  Map<String, dynamic> toJson() {
    return {
      'clipId': clipId,
      'recordingFullStartTime': recordingFullStartTime,
      'recordingFullEndTime': recordingFullEndTime,
      'trimmedStartTime': trimmedStartTime,
      'trimmedEndTime': trimmedEndTime,
    };
  }
}
