// agora_controller.dart

import 'package:get/get.dart';
import 'agora_service.dart';

class AgoraController extends GetxController {
  final AgoraService _agoraService = AgoraService();

  var isJoined = false.obs;
  var isMuted = false.obs;
  var isVideoEnabled = true.obs;
  var isScreenSharing = false.obs;

  Future<void> initializeAgora() async {
    await _agoraService.initialize();
  }

  Future<void> joinChannel({
    String channelName = 'testing',
    String token =
        '007eJxTYLhb8rs4LJpTaIHshGNX9v35fnH260TX5JDS4D6l23ofzcwUGIyMTBPNjNJMkkwTE01SLU0Sk0zM0iwNUwwSDYxMzVMNHRayZDQEMjIsW1/AysgAgSA+O0NJanFJZl46AwMACO8haw==',
  }) async {
    await _agoraService.joinChannel(channelName: channelName, token: token);

    isJoined.value = true;
  }

  Future<void> leaveChannel() async {
    await _agoraService.leaveChannel();
    isJoined.value = false;
  }

  Future<void> toggleMute() async {
    isMuted.value = !isMuted.value;
    await _agoraService.muteLocalAudio(isMuted.value);
  }

  Future<void> toggleVideo() async {
    isVideoEnabled.value = !isVideoEnabled.value;
    await _agoraService.muteLocalVideo(!isVideoEnabled.value);
  }

  Future<void> toggleScreenSharing() async {
    if (isScreenSharing.value) {
      await _agoraService.stopScreenSharing();
    } else {
      await _agoraService.startScreenSharing();
    }
    isScreenSharing.value = !isScreenSharing.value;
  }

  @override
  void onClose() {
    _agoraService.destroy();
    super.onClose();
  }
}
