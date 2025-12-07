import 'package:flutter/material.dart';
import 'package:better_player_plus/better_player_plus.dart';

class AudioHLSPlayer extends StatefulWidget {
  final String url; // The .m3u8 URL
  const AudioHLSPlayer({required this.url, super.key});

  @override
  State<AudioHLSPlayer> createState() => _AudioHLSPlayerState();
}

class _AudioHLSPlayerState extends State<AudioHLSPlayer> {
  late BetterPlayerController _betterPlayerController;

  @override
  void initState() {
    super.initState();

    // Configuration for HLS audio/video
    BetterPlayerConfiguration betterPlayerConfiguration =
        BetterPlayerConfiguration(
          autoPlay: true,
          looping: false,
          controlsConfiguration: BetterPlayerControlsConfiguration(
            showControls: true,
            enableProgressText: true,
            enablePlayPause: true,
            enableProgressBar: true,
          ),
          allowedScreenSleep: false,
          aspectRatio: 16 / 9,
        );

    // Data source - IMPORTANT: Use BetterPlayerDataSourceType.hls
    BetterPlayerDataSource dataSource = BetterPlayerDataSource(
      BetterPlayerDataSourceType
          .network, // ← Change this from 'network' to 'hls'
      widget.url,
      // HLS specific config
      useAsmsSubtitles: true,
      useAsmsAudioTracks: true,
    );

    _betterPlayerController = BetterPlayerController(
      betterPlayerConfiguration,
      betterPlayerDataSource: dataSource, // ← Pass dataSource here
    );
  }

  @override
  void dispose() {
    _betterPlayerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black12,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Audio Player",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: BetterPlayer(controller: _betterPlayerController),
          ),
        ],
      ),
    );
  }
}
