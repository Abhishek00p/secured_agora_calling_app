import 'package:secured_calling/core/models/individual_recording_model.dart';
import 'package:secured_calling/core/models/trim_clip_request.dart';

/// Firestore metadata shown immediately; [recordingUrl] is filled when the backend resolves audio.
class IndividualRecordingItem {
  final String clipId;
  final String trackId;
  final String eventId;
  final String userId;
  final String userName;
  final int startTime;
  final int endTime;
  final int trackStartTime;
  final int trackStopTime;
  final String recordingUrl;
  final bool isAudioLoading;
  final bool audioLoadFailed;

  const IndividualRecordingItem({
    required this.clipId,
    required this.trackId,
    required this.eventId,
    required this.userId,
    required this.userName,
    required this.startTime,
    required this.endTime,
    required this.trackStartTime,
    required this.trackStopTime,
    this.recordingUrl = '',
    this.isAudioLoading = true,
    this.audioLoadFailed = false,
  });

  bool get hasPlayableUrl => recordingUrl.trim().isNotEmpty && !audioLoadFailed;

  SpeakingEventModel toSpeakingEventModel() {
    return SpeakingEventModel(
      userId: userId,
      userName: userName,
      startTime: startTime,
      endTime: endTime,
      recordingUrl: recordingUrl,
      trackStartTime: trackStartTime,
      trackStopTime: trackStopTime,
    );
  }

  TrimClipRequest toTrimClipRequest() {
    return TrimClipRequest(
      clipId: clipId,
      recordingFullStartTime: trackStartTime,
      recordingFullEndTime: trackStopTime,
      trimmedStartTime: startTime,
      trimmedEndTime: endTime,
    );
  }

  IndividualRecordingItem copyWith({
    String? recordingUrl,
    bool? isAudioLoading,
    bool? audioLoadFailed,
  }) {
    return IndividualRecordingItem(
      clipId: clipId,
      trackId: trackId,
      eventId: eventId,
      userId: userId,
      userName: userName,
      startTime: startTime,
      endTime: endTime,
      trackStartTime: trackStartTime,
      trackStopTime: trackStopTime,
      recordingUrl: recordingUrl ?? this.recordingUrl,
      isAudioLoading: isAudioLoading ?? this.isAudioLoading,
      audioLoadFailed: audioLoadFailed ?? this.audioLoadFailed,
    );
  }
}
