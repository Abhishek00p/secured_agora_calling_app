import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:secured_calling/core/extensions/app_int_extension.dart';
import 'package:secured_calling/core/extensions/date_time_extension.dart';
import 'package:secured_calling/core/models/individual_recording_model.dart';
import 'package:secured_calling/core/theme/app_theme.dart';

/// Minimal audio player for a single URL (e.g. full mix or backend-trimmed `.m4a`).
class RecorderAudioTile extends StatefulWidget {
  final String url;
  final SpeakingEventModel model;
  final VoidCallback? onPlaybackStart;
  final VoidCallback? onPlaybackEnd;

  const RecorderAudioTile({required this.model, required this.url, this.onPlaybackStart, this.onPlaybackEnd, super.key});

  @override
  State<RecorderAudioTile> createState() => _RecorderAudioTileState();
}

class _RecorderAudioTileState extends State<RecorderAudioTile> {
  late AudioPlayer _player;
  static AudioPlayer? _currentlyPlaying;

  Duration _position = Duration.zero;

  /// Set from [AudioPlayer.durationStream] as soon as the URL is parsed (often before play).
  Duration? _duration;

  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _initAudio();

    _player.durationStream.listen((d) {
      if (!mounted) return;
      setState(() => _duration = d);
    });

    _player.positionStream.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });

    _player.playerStateStream.listen((state) {
      final playing = state.playing;
      if (playing != _isPlaying && mounted) {
        setState(() => _isPlaying = playing);
        if (playing) {
          widget.onPlaybackStart?.call();
        } else {
          widget.onPlaybackEnd?.call();
        }
      }
    });

    // Stop cleanly at end. Do not seek here — `seek(Duration.zero)` after `completed`
    // can restart playback on some platforms (looks like a loop).
    _player.processingStateStream.listen((processingState) async {
      if (!mounted || processingState != ProcessingState.completed) return;
      final wasPlaying = _isPlaying;
      try {
        await _player.pause();
        await _player.setLoopMode(LoopMode.off);
      } catch (_) {}
      if (!mounted) return;
      setState(() => _isPlaying = false);
      if (wasPlaying) widget.onPlaybackEnd?.call();
    });
  }

  Future<void> _initAudio() async {
    try {
      await _player.setUrl(widget.url);
      await _player.setLoopMode(LoopMode.off);
      if (mounted) {
        setState(() => _duration = _player.duration);
      }
    } catch (e) {
      debugPrint('Audio load error: $e');
    }
  }

  Duration get _effectiveDuration => _duration ?? _player.duration ?? Duration.zero;

  bool get _isAtEnd {
    if (_player.processingState == ProcessingState.completed) return true;
    final total = _effectiveDuration;
    if (total == Duration.zero) return false;
    return _player.position >= total - const Duration(milliseconds: 80);
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _player.pause();
      if (_currentlyPlaying == _player) _currentlyPlaying = null;
    } else {
      if (_currentlyPlaying != null && _currentlyPlaying != _player) {
        await _currentlyPlaying!.pause();
      }
      if (_isAtEnd) {
        await _player.seek(Duration.zero);
      }
      _currentlyPlaying = _player;
      await _player.play();
    }
  }

  Future<void> _seek(double value) async {
    final total = _effectiveDuration;
    if (total == Duration.zero) return;
    await _player.seek(total * value);
  }

  @override
  void dispose() {
    if (_currentlyPlaying == _player) _currentlyPlaying = null;
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final duration = _effectiveDuration;
    final hasDuration = duration > Duration.zero;
    final progress =
        !hasDuration ? 0.0 : (_position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);

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
              radius: 14,
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
                      ? 'Mix recording ${widget.model.trackStartTime.toDateTimeWithSec.toLocal().formatTimeWithSeconds}'
                      : '${widget.model.userName} ${widget.model.startTime.toDateTimeWithSec.toLocal().formatTimeWithSeconds}',
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
                    value: progress,
                    onChanged: hasDuration ? _seek : null,
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_fmt(_position), style: const TextStyle(color: Colors.white70, fontSize: 10)),
                    Text(hasDuration ? _fmt(duration) : '--:--', style: const TextStyle(color: Colors.white70, fontSize: 10)),
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
