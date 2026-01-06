import 'package:better_player_plus/better_player_plus.dart';
import 'package:flutter/material.dart';
import 'package:secured_calling/core/theme/app_theme.dart';

// class RecorderAudioTile extends StatefulWidget {
//   final String title;
//   final String url;

//   const RecorderAudioTile({required this.title, required this.url, super.key});

//   @override
//   State<RecorderAudioTile> createState() => _RecorderAudioTileState();
// }

// class _RecorderAudioTileState extends State<RecorderAudioTile> {
//   late BetterPlayerController _controller;

//   Duration _position = Duration.zero;
//   Duration _totalDuration = Duration.zero; // ⭐ actual duration from URL
//   bool _isPlaying = false;

//   void _seek(double value) {
//     if (_totalDuration == Duration.zero) return;

//     final target = _totalDuration.inMilliseconds * value;
//     _controller.seekTo(Duration(milliseconds: target.toInt()));
//   }

//   @override
//   void initState() {
//     super.initState();

//     _controller = BetterPlayerController(
//       const BetterPlayerConfiguration(
//         autoPlay: false,
//         looping: false,
//         controlsConfiguration: BetterPlayerControlsConfiguration(
//           showControls: false,
//         ),
//       ),
//     );

//     _controller.setupDataSource(
//       BetterPlayerDataSource(
//         BetterPlayerDataSourceType.network,
//         widget.url,
//         videoFormat: BetterPlayerVideoFormat.hls,
//         useAsmsAudioTracks: true,
//       ),
//     );

//     _controller.addEventsListener(_onEvent);
//   }

//   void _onEvent(BetterPlayerEvent event) {
//     if (event.betterPlayerEventType == BetterPlayerEventType.initialized) {
//       final vp = _controller.videoPlayerController;
//       final d = vp?.value.duration;

//       if (d != null && mounted) {
//         setState(() => _totalDuration = d);
//       }
//     }

//     if (event.betterPlayerEventType == BetterPlayerEventType.progress) {
//       final p = event.parameters?['progress'] as Duration?;
//       if (p != null && mounted) {
//         setState(() => _position = p);
//       }
//     }

//     if (event.betterPlayerEventType == BetterPlayerEventType.play) {
//       setState(() => _isPlaying = true);
//     }

//     if (event.betterPlayerEventType == BetterPlayerEventType.pause ||
//         event.betterPlayerEventType == BetterPlayerEventType.finished) {
//       setState(() => _isPlaying = false);
//     }
//   }

//   @override
//   void dispose() {
//     _controller.removeEventsListener(_onEvent);
//     _controller.dispose();
//     super.dispose();
//   }

//   void _togglePlay() {
//     _isPlaying ? _controller.pause() : _controller.play();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);

//     return Container(
//       margin: const EdgeInsets.symmetric(vertical: 8),
//       padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.circular(18),
//         gradient: const LinearGradient(
//           colors: [AppTheme.primaryColor, AppTheme.accentColor],
//           begin: Alignment.topLeft,
//           end: Alignment.bottomRight,
//         ),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(.25),
//             blurRadius: 10,
//             offset: const Offset(0, 6),
//           ),
//         ],
//       ),
//       child: Row(
//         children: [
//           // ▶️ Play / Pause
//           InkWell(
//             onTap: _togglePlay,
//             borderRadius: BorderRadius.circular(30),
//             child: Container(
//               padding: const EdgeInsets.all(8),
//               decoration: const BoxDecoration(
//                 color: Colors.white,
//                 shape: BoxShape.circle,
//               ),
//               child: Icon(
//                 _isPlaying ? Icons.pause : Icons.play_arrow,
//                 size: 22,
//                 color: Colors.black,
//               ),
//             ),
//           ),

//           const SizedBox(width: 14),
//           // 🎵 Title + Progress
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 // Title
//                 Text(
//                   widget.title,
//                   maxLines: 1,
//                   overflow: TextOverflow.ellipsis,
//                   style: theme.textTheme.bodyMedium?.copyWith(
//                     color: Colors.white,
//                     fontWeight: FontWeight.w600,
//                     fontSize: 12,
//                   ),
//                 ),

//                 const SizedBox(height: 6),

//                 // Progress bar
//                 SliderTheme(
//                   data: SliderTheme.of(context).copyWith(
//                     trackHeight: 2.5,
//                     thumbShape: const RoundSliderThumbShape(
//                       enabledThumbRadius: 6,
//                     ),
//                     overlayShape: const RoundSliderOverlayShape(
//                       overlayRadius: 12,
//                     ),
//                     activeTrackColor: Colors.white,
//                     inactiveTrackColor: Colors.white.withOpacity(.35),
//                     thumbColor: Colors.white,
//                   ),
//                   child: Slider(
//                     value:
//                         _totalDuration.inMilliseconds == 0
//                             ? 0
//                             : (_position.inMilliseconds /
//                                     _totalDuration.inMilliseconds)
//                                 .clamp(0.0, 1.0),
//                     onChanged: _seek,
//                   ),
//                 ),

//                 // Time labels
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     Text(
//                       _fmt(_position),
//                       style: theme.textTheme.labelSmall?.copyWith(
//                         color: Colors.white70,
//                       ),
//                     ),
//                     Text(
//                       _fmt(_totalDuration),
//                       style: theme.textTheme.labelSmall?.copyWith(
//                         color: Colors.white70,
//                       ),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   String _fmt(Duration d) {
//     if (d == Duration.zero) return '00:00';
//     final h = d.inHours.remainder(60).toString().padLeft(2, '0');
//     final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
//     final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
//     return '${h == '00' ? '' : '$h:'}$m:$s';
//   }
// }
class RecorderAudioTile extends StatefulWidget {
  final String title;
  final String url;

  /// Optional – required only for clipped playback
  final DateTime? recordingStartTime;
  final DateTime? clipStartTime;
  final DateTime? clipEndTime;

  const RecorderAudioTile({
    required this.title,
    required this.url,
    this.recordingStartTime,
    this.clipStartTime,
    this.clipEndTime,
    super.key,
  });

  @override
  State<RecorderAudioTile> createState() => _RecorderAudioTileState();
}

class _RecorderAudioTileState extends State<RecorderAudioTile> {
  late BetterPlayerController _controller;

  Duration _absolutePosition = Duration.zero;
  Duration _clipStart = Duration.zero;
  Duration _clipEnd = Duration.zero;
  Duration _clipDuration = Duration.zero;

  bool _isPlaying = false;

  bool get _isClipped =>
      widget.recordingStartTime != null &&
      widget.clipStartTime != null &&
      widget.clipEndTime != null;

  @override
  void initState() {
    super.initState();

    _controller = BetterPlayerController(
      const BetterPlayerConfiguration(
        autoPlay: false,
        looping: false,
        controlsConfiguration: BetterPlayerControlsConfiguration(
          showControls: false,
        ),
      ),
    );

    _controller.setupDataSource(
      BetterPlayerDataSource(
        BetterPlayerDataSourceType.network,
        widget.url,
        videoFormat: BetterPlayerVideoFormat.hls,
        useAsmsAudioTracks: true,
      ),
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
    }

    if (event.betterPlayerEventType == BetterPlayerEventType.pause ||
        event.betterPlayerEventType == BetterPlayerEventType.finished) {
      setState(() => _isPlaying = false);
    }
  }

  void _calculateClip() {
    final recordingStart = widget.recordingStartTime!;
    final clipStartTime = widget.clipStartTime!;
    final clipEndTime = widget.clipEndTime!;

    _clipStart = clipStartTime.difference(recordingStart);
    _clipEnd = clipEndTime.difference(recordingStart);
    _clipDuration = _clipEnd - _clipStart;
  }

  void _togglePlay() {
    if (_isPlaying) {
      _controller.pause();
    } else {
      if (_isClipped && _absolutePosition < _clipStart ||
          _absolutePosition >= _clipEnd) {
        _controller.seekTo(_clipStart);
      }
      _controller.play();
    }
  }

  void _seek(double value) {
    final target = _clipStart + (_clipDuration * value);
    _controller.seekTo(target);
  }

  @override
  void dispose() {
    _controller.removeEventsListener(_onEvent);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final visiblePosition =
        _isClipped ? _absolutePosition - _clipStart : _absolutePosition;

    final visibleDuration =
        _isClipped
            ? _clipDuration
            : _controller.videoPlayerController?.value.duration ??
                Duration.zero;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [AppTheme.primaryColor, AppTheme.accentColor],
        ),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: _togglePlay,
            child: CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                Slider(
                  value:
                      visibleDuration.inMilliseconds == 0
                          ? 0
                          : (visiblePosition.inMilliseconds /
                                  visibleDuration.inMilliseconds)
                              .clamp(0.0, 1.0),
                  onChanged: _isClipped ? _seek : null,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _fmt(visiblePosition),
                      style: const TextStyle(color: Colors.white70),
                    ),
                    Text(
                      _fmt(visibleDuration),
                      style: const TextStyle(color: Colors.white70),
                    ),
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
