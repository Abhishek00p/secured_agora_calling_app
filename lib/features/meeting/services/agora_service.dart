// agora_service.dart

import 'dart:async';
import 'dart:io';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:secured_calling/app_logger.dart';

// Replace with your Agora App ID
const String agoraAppId = '225a62f4b5aa4e94ab46f91d0a0257e1';

class AgoraService {
  static final AgoraService _instance = AgoraService._internal();

  factory AgoraService() {
    return _instance;
  }

  AgoraService._internal();

  RtcEngine? _engine;
  bool _isInitialized = false;

  RtcEngine? get engine => _engine;
  bool get isInitialized => _isInitialized;

  Future<bool> initialize({
    required RtcEngineEventHandler rtcEngineEventHandler,
  }) async {
    try {
      if (_isInitialized) {
        AppLogger.print('already initi  agora returnning...');
        return true;
      }

      await _requestPermissions();
      _engine = createAgoraRtcEngine();
      await _engine!.initialize(const RtcEngineContext(appId: agoraAppId));
      await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
      await _engine!.enableAudio();

      _engine!.registerEventHandler(rtcEngineEventHandler);

      _isInitialized = true;
      return true;
    } catch (e) {
      AppLogger.print('error while init agora service : $e');
      return false;
    }
  }

  Future<void> _requestPermissions() async {
    if (kIsWeb) return;
    if (Platform.isAndroid || Platform.isIOS) {
      await [Permission.microphone, Permission.camera].request();
    }
  }

  Future<void> joinChannel({
    required String channelName,
    required String token,
    required int userId,
  }) async {
    if (!_isInitialized) {
      throw Exception('Agora Not Initialize , ........');
    }
    await _engine!.joinChannel(
      token: token,
      channelId: channelName,
      uid: userId,
      options: const ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ),
    );
  }

  Future<void> leaveChannel() async {
    await _engine?.leaveChannel();
  }

  Future<void> destroy() async {
    await _engine?.release();
    _engine = null;
    _isInitialized = false;
  }

  // Basic audio/video toggles
  Future<void> muteLocalAudio(bool mute) async {
    await _engine?.muteLocalAudioStream(mute);
  }

  Future<void> muteLocalVideo(bool mute) async {
    await _engine?.muteLocalVideoStream(mute);
  }

  // Start/stop screen sharing
  Future<void> startScreenSharing() async {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      await _engine!.startScreenCapture(
        const ScreenCaptureParameters2(captureAudio: true, captureVideo: true),
      );
    }
  }

  Future<void> stopScreenSharing() async {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      await _engine!.stopScreenCapture();
    }
  }
}
