// import 'package:better_player_plus/better_player_plus.dart';
// import 'package:flutter/material.dart';

// class AudioHLSPlayer extends StatefulWidget {
//   final String url;
//   final Duration duration;

//   const AudioHLSPlayer({required this.url, required this.duration, super.key});

//   @override
//   State<AudioHLSPlayer> createState() => _AudioHLSPlayerState();
// }

// class _AudioHLSPlayerState extends State<AudioHLSPlayer> {
//   late BetterPlayerController _controller;

//   Duration _position = Duration.zero;
//   bool _isPlaying = false;

//   @override
//   void initState() {
//     super.initState();

//     _controller = BetterPlayerController(
//       const BetterPlayerConfiguration(
//         autoPlay: false,
//         looping: false,
//         allowedScreenSleep: true,
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

//     _controller.addEventsListener(_onPlayerEvent);
//   }

//   void _onPlayerEvent(BetterPlayerEvent event) {
//     if (event.betterPlayerEventType == BetterPlayerEventType.progress) {
//       final progress = event.parameters?['progress'] as Duration?;
//       if (progress != null && mounted) {
//         setState(() => _position = progress);
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
//     _controller.removeEventsListener(_onPlayerEvent);
//     _controller.dispose();
//     super.dispose();
//   }

//   void _togglePlay() {
//     _isPlaying ? _controller.pause() : _controller.play();
//   }

//   void _seek(double value) {
//     final target = widget.duration.inMilliseconds * value;
//     _controller.seekTo(Duration(milliseconds: target.toInt()));
//   }

//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);

//     return Column(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         // Invisible player
//         const SizedBox.shrink(),

//         Row(
//           children: [
//             // 🔹 Play / Pause Button
//             InkWell(
//               onTap: _togglePlay,
//               borderRadius: BorderRadius.circular(30),
//               child: Container(
//                 padding: const EdgeInsets.all(6),
//                 decoration: BoxDecoration(
//                   shape: BoxShape.circle,
//                   color: theme.colorScheme.primary.withOpacity(.15),
//                 ),
//                 child: Icon(
//                   _isPlaying ? Icons.pause : Icons.play_arrow,
//                   size: 22,
//                   color: theme.colorScheme.primary,
//                 ),
//               ),
//             ),

//             const SizedBox(width: 10),

//             // 🔹 Slider
//             Expanded(
//               child: SliderTheme(
//                 data: SliderTheme.of(context).copyWith(
//                   trackHeight: 2.5,
//                   thumbShape: const RoundSliderThumbShape(
//                     enabledThumbRadius: 6,
//                   ),
//                 ),
//                 child: Slider(
//                   value:
//                       widget.duration.inMilliseconds == 0
//                           ? 0
//                           : (_position.inMilliseconds /
//                                   widget.duration.inMilliseconds)
//                               .clamp(0.0, 1.0),
//                   onChanged: _seek,
//                 ),
//               ),
//             ),

//             const SizedBox(width: 8),

//             // 🔹 Duration
//             Text(
//               '${_format(_position)} / ${_format(widget.duration)}',
//               style: theme.textTheme.labelSmall,
//             ),
//           ],
//         ),
//       ],
//     );
//   }

//   String _format(Duration d) {
//     final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
//     final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
//     return '$m:$s';
//   }
// }
