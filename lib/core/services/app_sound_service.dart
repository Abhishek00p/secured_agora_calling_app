// import 'package:audioplayers/audioplayers.dart';

// class AudioService {
//   // Singleton setup
//   static final AudioService _instance = AudioService._internal();
//   factory AudioService() => _instance;
//   AudioService._internal();

//   final AudioPlayer _player = AudioPlayer();

//   Future<void> playJoinRequestSound(String assetPath) async {
//     try {
//       await _player.stop(); // stop any currently playing audio
//       await _player.play(AssetSource(assetPath));
//     } catch (e) {
//       print('Error playing join request sound: $e');
//     }
//   }

//   Future<void> dispose() async {
//     await _player.dispose();
//   }
// }
