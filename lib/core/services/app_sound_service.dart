import 'package:audioplayers/audioplayers.dart';
import 'package:secured_calling/utils/app_logger.dart';

class AppSoundService {
  // Singleton setup
  static final AppSoundService _instance = AppSoundService._internal();
  factory AppSoundService() => _instance;
  AppSoundService._internal();

  final AudioPlayer _player = AudioPlayer();
  bool _isInitialized = false;
  bool _isPlaying = false;

  /// Initialize the sound service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Set audio context for better performance
      await _player.setAudioContext(
        AudioContext(
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
          ),
          android: AudioContextAndroid(
            isSpeakerphoneOn: true,
            stayAwake: true,
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.notification,
            audioFocus: AndroidAudioFocus.gainTransientMayDuck,
          ),
        ),
      );
      
      _isInitialized = true;
      AppLogger.print('AppSoundService initialized successfully');
    } catch (e) {
      AppLogger.print('Error initializing AppSoundService: $e');
    }
  }

  /// Play join request notification sound
  Future<void> playJoinRequestSound(String assetPath) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      // Prevent multiple simultaneous plays
      if (_isPlaying) {
        AppLogger.print('Sound already playing, skipping...');
        return;
      }

      _isPlaying = true;
      
      // Stop any currently playing audio
      await _player.stop();
      
      // Set volume to a reasonable level (0.0 to 1.0)
      await _player.setVolume(0.7);
      
      // Play the sound
      await _player.play(AssetSource(assetPath));
      
      AppLogger.print('Playing join request sound: $assetPath');
      
      // Reset playing flag when sound completes
      _player.onPlayerComplete.listen((_) {
        _isPlaying = false;
        AppLogger.print('Join request sound completed');
      });
      
    } catch (e) {
      _isPlaying = false;
      AppLogger.print('Error playing join request sound: $e');
    }
  }

  /// Play a custom notification sound
  Future<void> playNotificationSound(String assetPath, {double volume = 0.7}) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      if (_isPlaying) {
        AppLogger.print('Sound already playing, skipping...');
        return;
      }

      _isPlaying = true;
      
      await _player.stop();
      await _player.setVolume(volume);
      await _player.play(AssetSource(assetPath));
      
      AppLogger.print('Playing notification sound: $assetPath');
      
      _player.onPlayerComplete.listen((_) {
        _isPlaying = false;
        AppLogger.print('Notification sound completed');
      });
      
    } catch (e) {
      _isPlaying = false;
      AppLogger.print('Error playing notification sound: $e');
    }
  }

  /// Stop any currently playing sound
  Future<void> stopSound() async {
    try {
      await _player.stop();
      _isPlaying = false;
      AppLogger.print('Sound stopped');
    } catch (e) {
      AppLogger.print('Error stopping sound: $e');
    }
  }

  /// Check if sound is currently playing
  bool get isPlaying => _isPlaying;

  /// Dispose of the audio player
  Future<void> dispose() async {
    try {
      await _player.dispose();
      _isInitialized = false;
      _isPlaying = false;
      AppLogger.print('AppSoundService disposed');
    } catch (e) {
      AppLogger.print('Error disposing AppSoundService: $e');
    }
  }
}
