import 'package:better_player_plus/better_player_plus.dart';
import 'package:flutter/material.dart';
import 'package:secured_calling/core/extensions/app_int_extension.dart';
import 'package:secured_calling/core/extensions/date_time_extension.dart';
import 'package:secured_calling/core/models/individual_recording_model.dart';
import 'package:secured_calling/core/theme/app_theme.dart';

class RecorderAudioTile extends StatefulWidget {
  final String url;

  /// Optional – required only for clipped playback
  final DateTime? recordingStartTime;
  final DateTime? clipStartTime;
  final DateTime? clipEndTime;
  final SpeakingEventModel model;

  /// Called when playback starts. Use e.g. to mute meeting mic so recording is not sent to the call.
  final VoidCallback? onPlaybackStart;
  /// Called when playback stops (pause or finished). Use e.g. to restore meeting mic state.
  final VoidCallback? onPlaybackEnd;

  const RecorderAudioTile({
    required this.model,
    required this.url,
    this.recordingStartTime,
    this.clipStartTime,
    this.clipEndTime,
    this.onPlaybackStart,
    this.onPlaybackEnd,
    super.key,
  });

  @override
  State<RecorderAudioTile> createState() => _RecorderAudioTileState();
}

class _RecorderAudioTileState extends State<RecorderAudioTile> {
  late BetterPlayerController _controller;
  static BetterPlayerController? _currentlyPlaying;

  Duration _absolutePosition = Duration.zero;
  Duration _clipStart = Duration.zero;
  Duration _clipEnd = Duration.zero;
  Duration _clipDuration = Duration.zero;

  bool _isPlaying = false;

  bool get _isClipped => widget.recordingStartTime != null && widget.clipStartTime != null && widget.clipEndTime != null;

  @override
  void initState() {
    super.initState();

    _controller = BetterPlayerController(
      const BetterPlayerConfiguration(autoPlay: false, looping: false, controlsConfiguration: BetterPlayerControlsConfiguration(showControls: false)),
    );
    if (widget.url.isEmpty) {
      debugPrint('\n hey boy -------> watch out url is empty');
    }
    _controller.setupDataSource(
      BetterPlayerDataSource(BetterPlayerDataSourceType.network, widget.url, videoFormat: BetterPlayerVideoFormat.hls, useAsmsAudioTracks: true),
    );

    _controller.addEventsListener(_onEvent);
  }

  void _onEvent(BetterPlayerEvent event) {
    if (event.betterPlayerEventType == BetterPlayerEventType.initialized) {
      if (_isClipped) {
        _calculateClip();
        _controller.seekTo(_clipStart);
      }
    }

    if (event.betterPlayerEventType == BetterPlayerEventType.progress) {
      final p = event.parameters?['progress'] as Duration?;
      if (p == null) return;

      // Auto-stop when clip ends
      if (_isClipped && p >= _clipEnd) {
        _controller.pause();
        _controller.seekTo(_clipStart);
        setState(() => _isPlaying = false);
        return;
      }

      setState(() => _absolutePosition = p);
    }

    if (event.betterPlayerEventType == BetterPlayerEventType.play) {
      setState(() => _isPlaying = true);
      widget.onPlaybackStart?.call();
    }

    if (event.betterPlayerEventType == BetterPlayerEventType.pause || event.betterPlayerEventType == BetterPlayerEventType.finished) {
      setState(() => _isPlaying = false);
      widget.onPlaybackEnd?.call();
    }
  }

  void _calculateClip() {
    final recordingStart = widget.recordingStartTime!;
    final clipStartTime = widget.clipStartTime!;
    final clipEndTime = widget.clipEndTime!;

    _clipStart = clipStartTime.difference(recordingStart);
    _clipEnd = clipEndTime.difference(recordingStart);
    _clipDuration = _clipEnd - _clipStart;
    if (_clipDuration <= Duration.zero) {
      debugPrint("Invalid clip duration calculated: $_clipDuration");
    }
  }

  void _togglePlay() {
    if (_isPlaying) {
      _controller.pause();
      if (_currentlyPlaying == _controller) {
        _currentlyPlaying = null;
      }
    } else {
      // Pause any other playing audio
      if (_currentlyPlaying != null && _currentlyPlaying != _controller) {
        _currentlyPlaying!.pause();
      }

      if (_isClipped && (_absolutePosition < _clipStart || _absolutePosition >= _clipEnd)) {
        _controller.seekTo(_clipStart);
      }

      _currentlyPlaying = _controller;
      _controller.play();
    }
  }

  void _seek(double value) {
    if (_isClipped) {
      if (_clipDuration == Duration.zero) return;
      final target = _clipStart + (_clipDuration * value);
      _controller.seekTo(target);
    } else {
      final total = _controller.videoPlayerController?.value.duration;
      if (total == null || total == Duration.zero) return;
      final target = total * value;
      _controller.seekTo(target);
    }
  }

  @override
  void dispose() {
    if (_currentlyPlaying == _controller) {
      _currentlyPlaying = null;
    }
    _controller.removeEventsListener(_onEvent);
    _controller.dispose();
    super.dispose();
  }

  Duration _clampDuration(Duration value, Duration min, Duration max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final visiblePosition = _isClipped ? _clampDuration(_absolutePosition - _clipStart, Duration.zero, _clipDuration) : _absolutePosition;

    final visibleDuration = _isClipped ? _clipDuration : _controller.videoPlayerController?.value.duration ?? Duration.zero;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(colors: [AppTheme.primaryColor, AppTheme.accentColor]),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: _togglePlay,
            child: CircleAvatar(
              radius: 14, // smaller button
              backgroundColor: Colors.white,
              child: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, size: 16, color: Colors.black),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.model.startTime == 0
                      ? 'Mix recording  ${widget.model.trackStartTime.toDateTime.toLocal().formatTime}'
                      : '${widget.model.userName} ${widget.model.startTime.toDateTime.toLocal().formatTime}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 11),
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                  ),
                  child: Slider(
                    value:
                        visibleDuration.inMilliseconds == 0 ? 0 : (visiblePosition.inMilliseconds / visibleDuration.inMilliseconds).clamp(0.0, 1.0),
                    onChanged: _seek,
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_fmt(visiblePosition), style: const TextStyle(color: Colors.white70, fontSize: 10)),
                    Text(_fmt(visibleDuration), style: const TextStyle(color: Colors.white70, fontSize: 10)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
