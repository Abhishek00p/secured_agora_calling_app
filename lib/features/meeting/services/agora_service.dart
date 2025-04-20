// import 'dart:async';
// import 'dart:io';

// import 'package:agora_rtc_engine/agora_rtc_engine.dart';
// import 'package:flutter/foundation.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:shared_preferences/shared_preferences.dart';

// // Replace with your Agora App ID
// const String agoraAppId = '225a62f4b5aa4e94ab46f91d0a0257e1';

// // Providers
// final agoraServiceProvider = Provider<AgoraService>((ref) => AgoraService());

// final remoteUsersProvider =
//     StateNotifierProvider<RemoteUsersNotifier, List<int>>(
//       (ref) => RemoteUsersNotifier(),
//     );

// final isMutedProvider = StateProvider<bool>((ref) => false);
// final isVideoEnabledProvider = StateProvider<bool>((ref) => true);
// final isSpeakerFocusEnabledProvider = StateProvider<bool>((ref) => false);
// final focusedUserIdProvider = StateProvider<int?>((ref) => null);

// class RemoteUsersNotifier extends StateNotifier<List<int>> {
//   RemoteUsersNotifier() : super([]);

//   void addUser(int uid) {
//     if (!state.contains(uid)) {
//       state = [...state, uid];
//     }
//   }

//   void removeUser(int uid) {
//     state = state.where((id) => id != uid).toList();
//   }

//   void clearUsers() {
//     state = [];
//   }
// }

// class AgoraService {
//   RtcEngine? _engine;
//   RtcEngine? get engine => _engine;
//   StreamSubscription? _rtcEventSubscription;
//   bool _isInitialized = false;
//   bool _isJoined = false;
//   Timer? _freeTrialTimer;
//   int? _localUid;
//   String? _currentChannel;
//   String? _currentToken;
//   bool _isRecording = false;
//   bool _isScreenSharing = false;

//   // Callbacks
//   Function(int uid)? onUserJoined;
//   Function(int uid)? onUserOffline;
//   Function(int uid, bool audioEnabled)? onUserAudioStateChanged;
//   Function(int uid, bool videoEnabled)? onUserVideoStateChanged;
//   Function()? onMeetingEnded;
//   Function(int remainingSeconds)? onFreeTrialCountdown;

//   bool get isInitialized => _isInitialized;
//   bool get isJoined => _isJoined;
//   bool get isRecording => _isRecording;
//   bool get isScreenSharing => _isScreenSharing;
//   int? get localUid => _localUid;
//   String? get currentChannel => _currentChannel;

//   Future<void> initialize({
//     Function(int uid)? onUserJoined,
//     Function(int uid)? onUserOffline,
//     Function(int uid, bool audioEnabled)? onUserAudioStateChanged,
//     Function(int uid, bool videoEnabled)? onUserVideoStateChanged,
//     Function()? onMeetingEnded,
//     Function(int remainingSeconds)? onFreeTrialCountdown,
//   }) async {
//     if (_isInitialized) return;
//     try {
//       // Set callbacks
//       this.onUserJoined = onUserJoined;
//       this.onUserOffline = onUserOffline;
//       this.onUserAudioStateChanged = onUserAudioStateChanged;
//       this.onUserVideoStateChanged = onUserVideoStateChanged;
//       this.onMeetingEnded = onMeetingEnded;
//       this.onFreeTrialCountdown = onFreeTrialCountdown;

//       // Request permissions
//       await _requestPermissions();

//       // Create RTC engine instance
//       _engine = createAgoraRtcEngine();
//       await _engine!.initialize(
//         const RtcEngineContext(
//           appId: agoraAppId,
//           // channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
//         ),
//       );

//       // Register event handler
//       _registerEventHandler();

//       // Set client role
//       await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);

//       // Enable video & audio
//       await _engine!.enableVideo();
//       await _engine!.enableAudio();
//       await _engine!.startPreview();

//       _isInitialized = true;
//     } catch (e) {
//       debugPrint("error init agora sdk  : $e");
//     }
//   }

//   Future<void> _requestPermissions() async {
//     if (kIsWeb) return; // Web doesn't need permissions

//     if (Platform.isAndroid || Platform.isIOS) {
//       await [Permission.microphone, Permission.camera].request();
//     }
//   }

//   void _registerEventHandler() {
//     _rtcEventSubscription?.cancel();

//     _engine!.registerEventHandler(
//       RtcEngineEventHandler(
//         onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
//           debugPrint("Local user ${connection.localUid} joined channel");
//           _isJoined = true;
//           _localUid = connection.localUid;
//         },
//         onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
//           debugPrint("Remote user $remoteUid joined");
//           onUserJoined?.call(remoteUid);
//         },
//         onUserOffline: (
//           RtcConnection connection,
//           int remoteUid,
//           UserOfflineReasonType reason,
//         ) {
//           debugPrint("Remote user $remoteUid left");
//           onUserOffline?.call(remoteUid);
//         },
//         onLeaveChannel: (RtcConnection connection, RtcStats stats) {
//           debugPrint("Local user left channel");
//           _isJoined = false;
//           _currentChannel = null;
//           _currentToken = null;
//         },
//         onError: (ErrorCodeType err, String msg) {
//           debugPrint('Agora error: ${err.toString()} - $msg');
//         },
//         onRemoteAudioStateChanged: (
//           RtcConnection connection,
//           int remoteUid,
//           RemoteAudioState state,
//           RemoteAudioStateReason reason,
//           int elapsed,
//         ) {
//           debugPrint(
//             "Remote user $remoteUid audio state changed to ${state.toString()}",
//           );
//           final bool audioEnabled =
//               state == RemoteAudioState.remoteAudioStateDecoding;
//           onUserAudioStateChanged?.call(remoteUid, audioEnabled);
//         },
//         onRemoteVideoStateChanged: (
//           RtcConnection connection,
//           int remoteUid,
//           RemoteVideoState state,
//           RemoteVideoStateReason reason,
//           int elapsed,
//         ) {
//           debugPrint(
//             "Remote user $remoteUid video state changed to ${state.toString()}",
//           );
//           final bool videoEnabled =
//               state == RemoteVideoState.remoteVideoStateDecoding;
//           onUserVideoStateChanged?.call(remoteUid, videoEnabled);
//         },
//         onTokenPrivilegeWillExpire: (RtcConnection connection, String token) {
//           debugPrint('Token privilege will expire');
//           // Here you would typically fetch a new token and call renewToken
//         },
//       ),
//     );
//   }

//   Future<void> joinChannel({
//     required String channelName,
//     String? token,
//     bool isFreeTrial = false,
//   }) async {
//     if (!_isInitialized) {
//       await initialize();
//     }

//     _currentChannel = channelName;
//     _currentToken =
//         '007eJxTYAjYHvDF4suuCYvt0zgbhP5+4xBZZflCWkah2Ni6pt/Y3EqBwcjINNHMKM0kyTQx0STV0iQxycQszdIwxSDRwMjUPNXwwuMX6Q2BjAwzTFxZGBkgEMRnZyhJLS7JzEtnYAAAJrwfGw==';

//     await _engine!.joinChannel(
//       token:
//           '007eJxTYAjYHvDF4suuCYvt0zgbhP5+4xBZZflCWkah2Ni6pt/Y3EqBwcjINNHMKM0kyTQx0STV0iQxycQszdIwxSDRwMjUPNXwwuMX6Q2BjAwzTFxZGBkgEMRnZyhJLS7JzEtnYAAAJrwfGw==',
//       channelId: 'testing',
//       uid: 0,
//       options: const ChannelMediaOptions(
//         clientRoleType: ClientRoleType.clientRoleBroadcaster,
//         channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
//       ),
//     );

//     // Start free trial timer if needed
//     if (isFreeTrial) {
//       _startFreeTrialTimer();
//     }
//   }

//   void _startFreeTrialTimer() {
//     const freeTrialDurationSeconds = 300; // 5 minutes
//     int remainingSeconds = freeTrialDurationSeconds;

//     _freeTrialTimer?.cancel();
//     _freeTrialTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
//       remainingSeconds--;
//       onFreeTrialCountdown?.call(remainingSeconds);

//       if (remainingSeconds <= 0) {
//         leaveChannel();
//         onMeetingEnded?.call();
//         timer.cancel();
//       }
//     });
//   }

//   Future<void> leaveChannel() async {
//     if (!_isInitialized || !_isJoined) return;

//     _freeTrialTimer?.cancel();
//     _freeTrialTimer = null;

//     if (_isRecording) {
//       await stopRecording();
//     }

//     if (_isScreenSharing) {
//       await stopScreenSharing();
//     }

//     await _engine!.leaveChannel();
//     _isJoined = false;
//     _currentChannel = null;
//     _currentToken = null;
//   }

//   Future<void> destroy() async {
//     _freeTrialTimer?.cancel();
//     _freeTrialTimer = null;
//     _rtcEventSubscription?.cancel();
//     _rtcEventSubscription = null;

//     if (_isJoined) {
//       await leaveChannel();
//     }

//     if (_isInitialized) {
//       await _engine!.release();
//       _engine = null;
//       _isInitialized = false;
//     }
//   }

//   Future<void> toggleMute() async {
//     if (!_isInitialized || !_isJoined) return;

//     final prefs = await SharedPreferences.getInstance();
//     final isMuted = prefs.getBool('is_muted') ?? false;
//     await _engine!.muteLocalAudioStream(!isMuted);
//     await prefs.setBool('is_muted', !isMuted);
//   }

//   Future<void> toggleVideo() async {
//     if (!_isInitialized || !_isJoined) return;

//     final prefs = await SharedPreferences.getInstance();
//     final isVideoEnabled = prefs.getBool('is_video_enabled') ?? true;
//     await _engine!.muteLocalVideoStream(isVideoEnabled);
//     await prefs.setBool('is_video_enabled', !isVideoEnabled);
//   }

//   Future<void> toggleRemoteAudio(int uid, bool mute) async {
//     if (!_isInitialized || !_isJoined) return;

//     // Host can mute remote users
//     await _engine!.muteRemoteAudioStream(uid: uid, mute: mute);
//   }

//   Future<void> toggleRemoteVideo(int uid, bool mute) async {
//     if (!_isInitialized || !_isJoined) return;

//     // Host can disable remote user's video
//     await _engine!.muteRemoteVideoStream(uid: uid, mute: mute);
//   }

//   Future<void> startRecording() async {
//     if (!_isInitialized || !_isJoined || _isRecording) return;

//     // Note: Actual implementation would require Agora Cloud Recording
//     // This requires server integration and is not implemented here
//     // For demonstration purposes only
//     _isRecording = true;
//   }

//   Future<void> stopRecording() async {
//     if (!_isInitialized || !_isJoined || !_isRecording) return;

//     // Note: Actual implementation would require Agora Cloud Recording
//     // This requires server integration and is not implemented here
//     // For demonstration purposes only
//     _isRecording = false;
//   }

//   Future<void> startScreenSharing() async {
//     if (!_isInitialized || !_isJoined || _isScreenSharing) return;

//     // This implementation varies by platform
//     // Note: For desktop platforms, this requires additional setup
//     if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
//       await _engine!.startScreenCapture(
//         const ScreenCaptureParameters2(captureAudio: true, captureVideo: true),
//       );
//       _isScreenSharing = true;
//     }
//   }

//   Future<void> stopScreenSharing() async {
//     if (!_isInitialized || !_isJoined || !_isScreenSharing) return;

//     if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
//       await _engine!.stopScreenCapture();
//       _isScreenSharing = false;
//     }
//   }

//   void setFocusedUser(int? uid) {
//     // This is just for UI state, doesn't affect Agora SDK
//   }

//   // Method to request a user to join a private room (1-to-1)
//   Future<void> inviteToPrivateRoom(int uid, String privateRoomChannel) async {
//     if (!_isInitialized || !_isJoined) return;

//     // In a full implementation, you would send this invite through a signaling channel
//     // For demonstration, this is just a placeholder
//     debugPrint('Inviting user $uid to private room: $privateRoomChannel');
//   }

//   // Method to join a private room
//   Future<void> joinPrivateRoom(String privateRoomChannel, String? token) async {
//     if (!_isInitialized) return;

//     // First leave the current channel
//     if (_isJoined) {
//       await leaveChannel();
//     }

//     // Then join the private room channel
//     await joinChannel(channelName: privateRoomChannel, token: token);
//   }
// }

import 'dart:async';
import 'dart:io';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Replace with your Agora App ID
const String agoraAppId = '225a62f4b5aa4e94ab46f91d0a0257e1';

// Providers
final agoraServiceProvider = Provider<AgoraService>((ref) => AgoraService());

final remoteUsersProvider =
    StateNotifierProvider<RemoteUsersNotifier, List<int>>(
      (ref) => RemoteUsersNotifier(),
    );

final isMutedProvider = StateProvider<bool>((ref) => false);
final isVideoEnabledProvider = StateProvider<bool>((ref) => true);
final isSpeakerFocusEnabledProvider = StateProvider<bool>((ref) => false);
final focusedUserIdProvider = StateProvider<int?>((ref) => null);
final isAudioOnlyModeProvider = StateProvider<bool>((ref) => false);

class RemoteUsersNotifier extends StateNotifier<List<int>> {
  RemoteUsersNotifier() : super([]);

  void addUser(int uid) {
    if (!state.contains(uid)) {
      state = [...state, uid];
    }
  }

  void removeUser(int uid) {
    state = state.where((id) => id != uid).toList();
  }

  void clearUsers() {
    state = [];
  }
}

class AgoraService {
  RtcEngine? _engine;
  RtcEngine? get engine => _engine;
  StreamSubscription? _rtcEventSubscription;
  bool _isInitialized = false;
  bool _isJoined = false;
  Timer? _freeTrialTimer;
  int? _localUid;
  String? _currentChannel;
  String? _currentToken;
  bool _isRecording = false;
  bool _isScreenSharing = false;
  bool _isAudioOnlyMode = true;

  bool get isAudioOnlyMode => _isAudioOnlyMode;

  // Callbacks
  Function(int uid)? onUserJoined;
  Function(int uid)? onUserOffline;
  Function(int uid, bool audioEnabled)? onUserAudioStateChanged;
  Function(int uid, bool videoEnabled)? onUserVideoStateChanged;
  Function()? onMeetingEnded;
  Function(int remainingSeconds)? onFreeTrialCountdown;

  bool get isInitialized => _isInitialized;
  bool get isJoined => _isJoined;
  bool get isRecording => _isRecording;
  bool get isScreenSharing => _isScreenSharing;
  int? get localUid => _localUid;
  String? get currentChannel => _currentChannel;

  Future<void> initialize({
    Function(int uid)? onUserJoined,
    Function(int uid)? onUserOffline,
    Function(int uid, bool audioEnabled)? onUserAudioStateChanged,
    Function(int uid, bool videoEnabled)? onUserVideoStateChanged,
    Function()? onMeetingEnded,
    Function(int remainingSeconds)? onFreeTrialCountdown,
  }) async {
    try{
    if (_isInitialized) return;

    // Set callbacks
    this.onUserJoined = onUserJoined;
    this.onUserOffline = onUserOffline;
    this.onUserAudioStateChanged = onUserAudioStateChanged;
    this.onUserVideoStateChanged = onUserVideoStateChanged;
    this.onMeetingEnded = onMeetingEnded;
    this.onFreeTrialCountdown = onFreeTrialCountdown;

    // Request permissions
    await _requestPermissions();

    // Create RTC engine instance
    _engine = createAgoraRtcEngine();
    await _engine!.initialize(
      const RtcEngineContext(
        appId: agoraAppId,
        // channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ),
    );

    // Register event handler
    _registerEventHandler();

    // Set client role
    await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);

    // Enable video & audio
    // await _engine!.enableVideo();
    await _engine!.enableAudio();
    await _engine!.startPreview();

    _isInitialized = true;
    }catch(e){
      debugPrint("error in init agora serive :$e");
    }
  }

  Future<void> _requestPermissions() async {
    if (kIsWeb) return; // Web doesn't need permissions

    if (Platform.isAndroid || Platform.isIOS) {
      await [Permission.microphone, Permission.camera].request();
    }
  }

  void _registerEventHandler() {
    _rtcEventSubscription?.cancel();

    _engine!.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          debugPrint("Local user ${connection.localUid} joined channel");
          _isJoined = true;
          _localUid = connection.localUid;
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          debugPrint("Remote user $remoteUid joined");
          onUserJoined?.call(remoteUid);
        },
        onUserOffline: (
          RtcConnection connection,
          int remoteUid,
          UserOfflineReasonType reason,
        ) {
          debugPrint("Remote user $remoteUid left");
          onUserOffline?.call(remoteUid);
        },
        onLeaveChannel: (RtcConnection connection, RtcStats stats) {
          debugPrint("Local user left channel");
          _isJoined = false;
          _currentChannel = null;
          _currentToken = null;
        },
        onError: (ErrorCodeType err, String msg) {
          debugPrint('Agora error: ${err.toString()} - $msg');
        },
        onRemoteAudioStateChanged: (
          RtcConnection connection,
          int remoteUid,
          RemoteAudioState state,
          RemoteAudioStateReason reason,
          int elapsed,
        ) {
          debugPrint(
            "Remote user $remoteUid audio state changed to ${state.toString()}",
          );
          final bool audioEnabled =
              state == RemoteAudioState.remoteAudioStateDecoding;
          onUserAudioStateChanged?.call(remoteUid, audioEnabled);
        },
        onRemoteVideoStateChanged: (
          RtcConnection connection,
          int remoteUid,
          RemoteVideoState state,
          RemoteVideoStateReason reason,
          int elapsed,
        ) {
          debugPrint(
            "Remote user $remoteUid video state changed to ${state.toString()}",
          );
          final bool videoEnabled =
              state == RemoteVideoState.remoteVideoStateDecoding;
          onUserVideoStateChanged?.call(remoteUid, videoEnabled);
        },
        onTokenPrivilegeWillExpire: (RtcConnection connection, String token) {
          debugPrint('Token privilege will expire');
          // Here you would typically fetch a new token and call renewToken
        },
      ),
    );
  }

  Future<void> joinChannel({
    required String channelName,
    String? token,
    bool isFreeTrial = false,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    _currentChannel = channelName;
    _currentToken = token;

    await _engine!.joinChannel(
      token:
          '007eJxTYLhb8rs4LJpTaIHshGNX9v35fnH260TX5JDS4D6l23ofzcwUGIyMTBPNjNJMkkwTE01SLU0Sk0zM0iwNUwwSDYxMzVMNHRayZDQEMjIsW1/AysgAgSA+O0NJanFJZl46AwMACO8haw==',
      channelId: 'testing',
      uid: 0,
      options: const ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ),
    );

    // Start free trial timer if needed
    if (isFreeTrial) {
      _startFreeTrialTimer();
    }
  }

  void _startFreeTrialTimer() {
    const freeTrialDurationSeconds = 300; // 5 minutes
    int remainingSeconds = freeTrialDurationSeconds;

    _freeTrialTimer?.cancel();
    _freeTrialTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      remainingSeconds--;
      onFreeTrialCountdown?.call(remainingSeconds);

      if (remainingSeconds <= 0) {
        leaveChannel();
        onMeetingEnded?.call();
        timer.cancel();
      }
    });
  }

  Future<void> leaveChannel() async {
    if (!_isInitialized || !_isJoined) return;

    _freeTrialTimer?.cancel();
    _freeTrialTimer = null;

    if (_isRecording) {
      await stopRecording();
    }

    if (_isScreenSharing) {
      await stopScreenSharing();
    }

    await _engine!.leaveChannel();
    _isJoined = false;
    _currentChannel = null;
    _currentToken = null;
  }

  Future<void> destroy() async {
    _freeTrialTimer?.cancel();
    _freeTrialTimer = null;
    _rtcEventSubscription?.cancel();
    _rtcEventSubscription = null;

    if (_isJoined) {
      await leaveChannel();
    }

    if (_isInitialized) {
      await _engine!.release();
      _engine = null;
      _isInitialized = false;
    }
  }

  Future<void> toggleMute() async {
    if (!_isInitialized || !_isJoined) return;

    final prefs = await SharedPreferences.getInstance();
    final isMuted = prefs.getBool('is_muted') ?? false;
    await _engine!.muteLocalAudioStream(!isMuted);
    await prefs.setBool('is_muted', !isMuted);
  }

  Future<void> toggleVideo() async {
    if (!_isInitialized || !_isJoined) return;

    final prefs = await SharedPreferences.getInstance();
    final isVideoEnabled = prefs.getBool('is_video_enabled') ?? true;
    await _engine!.muteLocalVideoStream(isVideoEnabled);
    await prefs.setBool('is_video_enabled', !isVideoEnabled);
  }

  Future<void> toggleAudioOnlyMode() async {
    if (!_isInitialized || !_isJoined) return;

    final prefs = await SharedPreferences.getInstance();
    _isAudioOnlyMode = !_isAudioOnlyMode;

    if (_isAudioOnlyMode) {
      // Disable video for everyone including local user
      await _engine!.muteLocalVideoStream(true);
      await prefs.setBool('is_video_enabled', false);
      await _engine!.disableVideo();
    } else {
      // Re-enable video capability
      await _engine!.enableVideo();
      await _engine!.startPreview();

      // Check if video was enabled before audio-only mode
      final shouldEnableVideo =
          !(prefs.getBool('is_video_enabled_before_audio_only') ?? false);
      if (shouldEnableVideo) {
        await _engine!.muteLocalVideoStream(false);
        await prefs.setBool('is_video_enabled', true);
      }
    }

    // Save current state to preferences
    await prefs.setBool('is_audio_only_mode', _isAudioOnlyMode);

    // If enabling audio-only mode, save current video state
    if (_isAudioOnlyMode) {
      final currentVideoState = prefs.getBool('is_video_enabled') ?? true;
      await prefs.setBool(
        'is_video_enabled_before_audio_only',
        !currentVideoState,
      );
    }
  }

  Future<void> toggleRemoteAudio(int uid, bool mute) async {
    if (!_isInitialized || !_isJoined) return;

    // Host can mute remote users
    await _engine!.muteRemoteAudioStream(uid: uid, mute: mute);
  }

  Future<void> toggleRemoteVideo(int uid, bool mute) async {
    if (!_isInitialized || !_isJoined) return;

    // Host can disable remote user's video
    await _engine!.muteRemoteVideoStream(uid: uid, mute: mute);
  }

  Future<void> startRecording() async {
    if (!_isInitialized || !_isJoined || _isRecording) return;

    // Note: Actual implementation would require Agora Cloud Recording
    // This requires server integration and is not implemented here
    // For demonstration purposes only
    _isRecording = true;
  }

  Future<void> stopRecording() async {
    if (!_isInitialized || !_isJoined || !_isRecording) return;

    // Note: Actual implementation would require Agora Cloud Recording
    // This requires server integration and is not implemented here
    // For demonstration purposes only
    _isRecording = false;
  }

  Future<void> startScreenSharing() async {
    if (!_isInitialized || !_isJoined || _isScreenSharing) return;

    // This implementation varies by platform
    // Note: For desktop platforms, this requires additional setup
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      await _engine!.startScreenCapture(
        const ScreenCaptureParameters2(captureAudio: true, captureVideo: true),
      );
      _isScreenSharing = true;
    }
  }

  Future<void> stopScreenSharing() async {
    if (!_isInitialized || !_isJoined || !_isScreenSharing) return;

    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      await _engine!.stopScreenCapture();
      _isScreenSharing = false;
    }
  }

  void setFocusedUser(int? uid) {
    // This is just for UI state, doesn't affect Agora SDK
  }

  // Method to request a user to join a private room (1-to-1)
  Future<void> inviteToPrivateRoom(int uid, String privateRoomChannel) async {
    if (!_isInitialized || !_isJoined) return;

    // In a full implementation, you would send this invite through a signaling channel
    // For demonstration, this is just a placeholder
    debugPrint('Inviting user $uid to private room: $privateRoomChannel');
  }

  // Method to join a private room
  Future<void> joinPrivateRoom(String privateRoomChannel, String? token) async {
    if (!_isInitialized) return;

    // First leave the current channel
    if (_isJoined) {
      await leaveChannel();
    }

    // Then join the private room channel
    await joinChannel(channelName: privateRoomChannel, token: token);
  }
}
