// agora_controller.dart

import 'package:get/get.dart';
import 'package:secured_calling/app_tost_util.dart';
import 'package:secured_calling/core/services/app_firebase_service.dart';
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
        '',
  }) async {
    final token= await AppFirebaseService.instance.getAgoraToken();
    if(token.trim().isEmpty){
      AppToastUtil.showErrorToast(Get.context!, 'Token not found');
      return;
    }
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
