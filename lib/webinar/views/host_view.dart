import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/webinar_meeting_controller.dart';
import '../models/webinar_user_model.dart';
import 'common_widgets.dart';

class HostView extends StatelessWidget {
  const HostView({super.key, required this.controller});
  final WebinarMeetingController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Host Room'),
        actions: [
          Obx(() => controller.isInPrivateCall.value
              ? TextButton(
                  onPressed: controller.endPrivateCall,
                  child: const Text('End Private', style: TextStyle(color: Colors.white)),
                )
              : const SizedBox.shrink()),
          Obx(() => controller.pendingPrivateChannelName.value.isNotEmpty
              ? TextButton(
                  onPressed: controller.acceptPrivateCall,
                  child: const Text('Accept Private', style: TextStyle(color: Colors.white)),
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
        final sorted = [...controller.members];
        sorted.sort((a, b) {
          // host first, then subhost, then participant; self first among equals
          int rank(WebinarUserModel u) {
            if (u.role == WebinarRole.host) return 0;
            if (u.role == WebinarRole.subHost) return 1;
            return 2;
          }
        
          final r = rank(a).compareTo(rank(b));
          if (r != 0) return r;
          if (a.userId == controller.selfUser.userId) return -1;
          if (b.userId == controller.selfUser.userId) return 1;
          return a.displayName.compareTo(b.displayName);
        });

        return PageView.builder(
          controller: PageController(viewportFraction: 0.96),
          itemBuilder: (context, pageIndex) {
            final start = pageIndex * 6;
            if (start >= sorted.length) return const SizedBox.shrink();
            final end = (start + 6).clamp(0, sorted.length);
            final slice = sorted.sublist(start, end);
            return GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1,
              ),
              itemCount: slice.length,
              itemBuilder: (context, idx) {
                final user = slice[idx];
                return _UserCard(controller: controller, user: user);
              },
            );
          },
        );
      }),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.controller, required this.user});
  final WebinarMeetingController controller;
  final WebinarUserModel user;

  @override
  Widget build(BuildContext context) {
    final isSpeaking = controller.isSpeaking(user.agoraUid);
    return PopupMenuButton<String>(
      color: Colors.grey.shade900,
      itemBuilder: (context) {
        final items = <PopupMenuEntry<String>>[];
        items.add(
          PopupMenuItem(
            value: user.isMicMuted ? 'unmute' : 'mute',
            child: Text(user.isMicMuted ? 'Unmute' : 'Mute'),
          ),
        );
        items.add(
          PopupMenuItem(
            value: user.canSpeak ? 'revoke_speak' : 'approve_speak',
            child: Text(user.canSpeak ? 'Revoke Speak' : 'Grant Speak'),
          ),
        );
        if (user.role == WebinarRole.participant) {
          items.add(const PopupMenuItem(value: 'promote', child: Text('Promote to SubHost')));
        } else if (user.role == WebinarRole.subHost) {
          items.add(const PopupMenuItem(value: 'demote', child: Text('Demote to Participant')));
        }
        if (user.role != WebinarRole.host) {
          items.add(const PopupMenuItem(value: 'kick', child: Text('Kick')));
        }
        // Private call option
        if (user.role == WebinarRole.participant) {
          items.add(const PopupMenuItem(value: 'private', child: Text('Private Call')));
        }
        return items;
      },
      onSelected: (value) async {
        switch (value) {
          case 'mute':
            await controller.muteUser(user, true);
            break;
          case 'unmute':
            await controller.muteUser(user, false);
            break;
          case 'approve_speak':
            await controller.approveSpeak(user);
            break;
          case 'revoke_speak':
            await controller.revokeSpeak(user);
            break;
          case 'promote':
            await controller.promoteToSubHost(user);
            break;
          case 'demote':
            await controller.demoteToParticipant(user);
            break;
          case 'kick':
            await controller.kickUser(user);
            break;
          case 'private':
            await controller.startPrivateCall(user);
            break;
        }
      },
      child: NameTile(
        name: user.displayName,
        isSpeaking: isSpeaking,
        isMicMuted: user.isMicMuted,
      ),
    );
  }
}


