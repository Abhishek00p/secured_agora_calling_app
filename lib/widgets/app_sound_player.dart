import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';

class AssetAudioService {
  static final AssetAudioService _instance = AssetAudioService._internal();
  factory AssetAudioService() => _instance;

  AssetAudioService._internal();

  final AudioPlayer _player = AudioPlayer();

  /// Plays an asset audio file.
  /// Example: play('assets/sounds/recording_started.mp3');
  Future<void> play(String assetPath) async {
    try {
      // If something is already playing, restart cleanly
      if (_player.playing) {
        await _player.stop();
      }

      await _player.setAsset(assetPath);
      await _player.play();
    } catch (e) {
      debugPrint('AssetAudioService error: $e');
    }
  }

  Future<void> dispose() async {
    await _player.dispose();
  }
}
