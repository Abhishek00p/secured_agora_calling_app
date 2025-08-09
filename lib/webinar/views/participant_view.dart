import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/webinar_meeting_controller.dart';
import '../models/webinar_user_model.dart';
import 'common_widgets.dart';

class ParticipantView extends StatelessWidget {
  const ParticipantView({super.key, required this.controller});
  final WebinarMeetingController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Webinar'),
        actions: [
          Obx(() => controller.pendingPrivateChannelName.value.isNotEmpty
              ? TextButton(
                  onPressed: controller.acceptPrivateCall,
                  child: const Text('Accept Private', style: TextStyle(color: Colors.white)),
                )
              : const SizedBox.shrink()),
          Obx(() => controller.isInPrivateCall.value
              ? TextButton(
                  onPressed: controller.endPrivateCall,
                  child: const Text('End Private', style: TextStyle(color: Colors.white)),
                )
              : const SizedBox.shrink()),
          IconButton(
            icon: Obx(() => Icon(controller.isPlaybackMuted.value ? Icons.volume_off : Icons.volume_up)),
            onPressed: controller.togglePlaybackMute,
          ),
          IconButton(
            icon: const Icon(Icons.call_end),
            onPressed: controller.leave,
          ),
        ],
      ),
      body: Obx(() {
        final host = controller.members.firstWhereOrNull((m) => m.role == WebinarRole.host);
        final subHosts = controller.members.where((m) => m.role == WebinarRole.subHost).toList();
        final self = controller.selfUser;
        return Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: GridView(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1,
                  ),
                  children: [
                    if (host != null)
                      NameTile(
                        name: host.displayName,
                        isSpeaking: controller.isSpeaking(host.agoraUid),
                        isMicMuted: host.isMicMuted,
                      ),
                    for (final sh in subHosts)
                      NameTile(
                        name: sh.displayName,
                        isSpeaking: controller.isSpeaking(sh.agoraUid),
                        isMicMuted: sh.isMicMuted,
                      ),
                    NameTile(
                      name: self.displayName,
                      isSpeaking: controller.isSpeaking(self.agoraUid),
                      isMicMuted: controller.isLocalMuted.value,
                    ),
                  ],
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: controller.requestToSpeak,
                      icon: const Icon(Icons.record_voice_over),
                      label: const Text('Request to Speak'),
                    ),
                    Obx(() => IconButton(
                          onPressed: controller.selfUser.canSpeak ? controller.toggleLocalMute : null,
                          icon: Icon(controller.isLocalMuted.value ? Icons.mic_off : Icons.mic),
                        )),
                    Obx(() => IconButton(
                          onPressed: controller.togglePlaybackMute,
                          icon: Icon(controller.isPlaybackMuted.value ? Icons.volume_off : Icons.volume_up),
                        )),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}


