import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

import '../models/webinar_user_model.dart';
import '../services/webinar_meeting_service.dart';

class WebinarMeetingController extends GetxController {
  WebinarMeetingController({
    required this.service,
    required this.roomId,
    required this.channelName,
    required this.selfUser,
  });

  final WebinarMeetingService service;
  final String roomId;
  final String channelName;
  final WebinarUserModel selfUser;

  final RxList<WebinarUserModel> members = <WebinarUserModel>[].obs;
  final RxMap<int, int> speakingVolumes = <int, int>{}.obs; // uid -> volume
  final RxBool isLocalMuted = true.obs;
  final RxBool isPlaybackMuted = false.obs;
  final RxBool selfCanSpeak = false.obs;
  final Rx<WebinarRole> selfCurrentRole = WebinarRole.participant.obs;

  // Private call state
  final RxBool isInPrivateCall = false.obs;
  // ignore: unused_field
  String? _privateChannelName; // kept for potential analytics/debugging
  String? _privatePeerUserId;
  final RxString pendingPrivateChannelName = ''.obs; // invitation holder

  StreamSubscription<List<WebinarUserModel>>? _memberSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _signalSub;

  int get selfUid => selfUser.agoraUid;

  bool get isHost => selfUser.role == WebinarRole.host;
  bool get isSubHost => selfUser.role == WebinarRole.subHost;

  // Mic activity detection: volume > threshold
  bool isSpeaking(int uid) {
    final vol = speakingVolumes[uid] ?? 0;
    return vol > 50;
  }

  Future<void> initialize() async {
    await service.createOrJoinRoom(roomId: roomId, channelName: channelName, self: selfUser);

    // Join Agora with publish capability based on role/canSpeak
    final canPublish = selfUser.role != WebinarRole.participant || selfUser.canSpeak;
    await service.joinAgora(
      channelName: channelName,
      uid: selfUid,
      canPublish: canPublish,
      onUserJoined: (connection, remoteUid, elapsed) {},
      onUserOffline: (connection, remoteUid, reason) {},
      onAudioVolumeIndication: (speaker, totalVol) {
        final uid = speaker.uid ?? 0;
        final vol = speaker.volume ?? 0;
        speakingVolumes[uid] = vol;
      },
    );

    await service.setLocalMute(!canPublish);
    isLocalMuted.value = !canPublish;

    _memberSub = service.watchMembers(roomId).listen((list) {
      members.assignAll(list);
      _onMembersUpdated();
    });

    _signalSub = service.watchSignals(roomId).listen(_handleSignalSnapshot);
  }

  void _onMembersUpdated() {
    // Update self reactive permissions from Firestore
    final selfDoc = members.firstWhereOrNull((m) => m.userId == selfUser.userId);
    if (selfDoc != null) {
      final nextCanPublish = selfDoc.role != WebinarRole.participant || selfDoc.canSpeak;
      if (selfCanSpeak.value != selfDoc.canSpeak || selfCurrentRole.value != selfDoc.role) {
        selfCanSpeak.value = selfDoc.canSpeak;
        selfCurrentRole.value = selfDoc.role;
        // Apply ability to publish
        service.setPublishCapability(nextCanPublish);
        // Keep local mute in sync: if cannot publish, ensure muted
        if (!nextCanPublish) {
          service.setLocalMute(true);
          isLocalMuted.value = true;
        }
      }
    }

    _applyRemoteMutePolicy();
  }

  void _applyRemoteMutePolicy() {
    // Participants should only hear Host/SubHost. Hosts/SubHosts hear everyone.
    final meRole = selfCurrentRole.value;
    for (final user in members) {
      if (user.userId == selfUser.userId) continue;
      bool shouldMuteRemotely = false;
      if (meRole == WebinarRole.participant) {
        // Only allow host/subhost audio
        shouldMuteRemotely = !(user.role == WebinarRole.host || user.role == WebinarRole.subHost);
      } else {
        shouldMuteRemotely = false;
      }
      service.muteRemoteAudio(user.agoraUid, shouldMuteRemotely);
    }
  }

  void _handleSignalSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
    for (final doc in snapshot.docChanges) {
      if (doc.type != DocumentChangeType.added) continue;
      final data = doc.doc.data();
      if (data == null) continue;
      final type = data['type'] as String?;
      switch (type) {
        case 'request_to_speak':
          // Host/SubHost can react in UI from members list
          break;
        case 'approve_speak':
          if (data['toUserId'] == selfUser.userId) {
            _grantLocalSpeakPermission();
          }
          break;
        case 'revoke_speak':
          if (data['toUserId'] == selfUser.userId) {
            _revokeLocalSpeakPermission();
          }
          break;
        case 'promote_to_subhost':
          if (data['toUserId'] == selfUser.userId) {
            _promoteLocalToSubHost();
          }
          break;
        case 'demote_to_participant':
          if (data['toUserId'] == selfUser.userId) {
            _demoteLocalToParticipant();
          }
          break;
        case 'kick_user':
          if (data['toUserId'] == selfUser.userId) {
            leave();
          }
          break;
        case 'start_private_call':
          if (data['toUserId'] == selfUser.userId) {
            final pv = (data['payload']?['channel'] ?? '') as String;
            if (pv.isNotEmpty) {
              pendingPrivateChannelName.value = pv;
              _privatePeerUserId = data['fromUserId'] as String?;
            }
          }
          break;
        case 'end_private_call':
          if (isInPrivateCall.value) {
            rejoinOriginalMeeting();
          }
          break;
        case 'mic_status_update':
          if (data['toUserId'] == selfUser.userId) {
            final mute = (data['payload']?['mute'] ?? true) as bool;
            service.setLocalMute(mute);
            isLocalMuted.value = mute;
          }
          break;
        default:
          break;
      }
    }
  }

  // Local role updates
  Future<void> _grantLocalSpeakPermission() async {
    await service.setPublishCapability(true);
    await service.setLocalMute(false);
    isLocalMuted.value = false;
  }

  Future<void> _revokeLocalSpeakPermission() async {
    await service.setPublishCapability(false);
    await service.setLocalMute(true);
    isLocalMuted.value = true;
  }

  Future<void> _promoteLocalToSubHost() async {
    await service.setPublishCapability(true);
    await service.setLocalMute(false);
    isLocalMuted.value = false;
  }

  Future<void> _demoteLocalToParticipant() async {
    await service.setPublishCapability(false);
    await service.setLocalMute(true);
    isLocalMuted.value = true;
  }

  // Public actions
  Future<void> requestToSpeak() async {
    await service.sendSignal(
      roomId: roomId,
      type: 'request_to_speak',
      fromUserId: selfUser.userId,
    );
  }

  Future<void> approveSpeak(WebinarUserModel user) async {
    await service.sendSignal(
      roomId: roomId,
      type: 'approve_speak',
      fromUserId: selfUser.userId,
      toUserId: user.userId,
    );
    await service.updateMember(roomId, user.copyWith(canSpeak: true, isMicMuted: false));
  }

  Future<void> revokeSpeak(WebinarUserModel user) async {
    await service.sendSignal(
      roomId: roomId,
      type: 'revoke_speak',
      fromUserId: selfUser.userId,
      toUserId: user.userId,
    );
    await service.updateMember(roomId, user.copyWith(canSpeak: false, isMicMuted: true));
  }

  Future<void> promoteToSubHost(WebinarUserModel user) async {
    await service.sendSignal(
      roomId: roomId,
      type: 'promote_to_subhost',
      fromUserId: selfUser.userId,
      toUserId: user.userId,
    );
    await service.updateMember(roomId, user.copyWith(role: WebinarRole.subHost, canSpeak: true));
  }

  Future<void> demoteToParticipant(WebinarUserModel user) async {
    await service.sendSignal(
      roomId: roomId,
      type: 'demote_to_participant',
      fromUserId: selfUser.userId,
      toUserId: user.userId,
    );
    await service.updateMember(roomId, user.copyWith(role: WebinarRole.participant, canSpeak: false, isMicMuted: true));
  }

  Future<void> kickUser(WebinarUserModel user) async {
    await service.sendSignal(
      roomId: roomId,
      type: 'kick_user',
      fromUserId: selfUser.userId,
      toUserId: user.userId,
    );
    await service.removeMember(roomId, user.userId);
  }

  Future<void> toggleLocalMute() async {
    final next = !isLocalMuted.value;
    await service.setLocalMute(next);
    isLocalMuted.value = next;
  }

  Future<void> togglePlaybackMute() async {
    final next = !isPlaybackMuted.value;
    await service.setPlaybackMute(next);
    isPlaybackMuted.value = next;
  }

  Future<void> muteUser(WebinarUserModel user, bool mute) async {
    // Send a signal to force remote user to change local mic state
    await service.sendSignal(
      roomId: roomId,
      type: 'mic_status_update',
      fromUserId: selfUser.userId,
      toUserId: user.userId,
      payload: {'mute': mute},
    );
    await service.updateMember(roomId, user.copyWith(isMicMuted: mute));
  }

  Future<void> leave() async {
    await service.leaveAndDestroy();
    await _memberSub?.cancel();
    await _signalSub?.cancel();
  }

  // ===== Private call APIs =====
  Future<void> startPrivateCall(WebinarUserModel participant) async {
    // Only host/subhost should initiate
    if (!(isHost || isSubHost)) return;
    // Require approved speaker per spec
    if (!participant.canSpeak) return;
    final pvName = '${channelName}__pv__${participant.userId}';
    _privateChannelName = pvName;
    _privatePeerUserId = participant.userId;
    await service.sendSignal(
      roomId: roomId,
      type: 'start_private_call',
      fromUserId: selfUser.userId,
      toUserId: participant.userId,
      payload: {'channel': pvName},
    );
    await _switchToPrivate(channel: pvName);
  }

  Future<void> acceptPrivateCall() async {
    final pv = pendingPrivateChannelName.value;
    if (pv.isEmpty) return;
    _privateChannelName = pv;
    pendingPrivateChannelName.value = '';
    await _switchToPrivate(channel: pv);
  }

  Future<void> declinePrivateCall() async {
    pendingPrivateChannelName.value = '';
  }

  Future<void> endPrivateCall() async {
    // Notify peer and rejoin original
    final peer = _privatePeerUserId;
    if (peer != null) {
      await service.sendSignal(
        roomId: roomId,
        type: 'end_private_call',
        fromUserId: selfUser.userId,
        toUserId: peer,
      );
    }
    await rejoinOriginalMeeting();
  }

  Future<void> _switchToPrivate({required String channel}) async {
    isInPrivateCall.value = true;
    _privateChannelName = channel;
    await service.leaveAndDestroy();
    // In private both are broadcasters
    await service.joinAgora(
      channelName: channel,
      uid: selfUid,
      canPublish: true,
      onUserJoined: (connection, remoteUid, elapsed) {},
      onUserOffline: (connection, remoteUid, reason) {},
      onAudioVolumeIndication: (speaker, totalVol) {
        final uid = speaker.uid ?? 0;
        final vol = speaker.volume ?? 0;
        speakingVolumes[uid] = vol;
      },
    );
    await service.setLocalMute(false);
    isLocalMuted.value = false;
  }

  Future<void> rejoinOriginalMeeting() async {
    isInPrivateCall.value = false;
    _privateChannelName = null;
    await service.leaveAndDestroy();
    final roleNow = selfCurrentRole.value;
    final canPublish = roleNow != WebinarRole.participant; // default: host/subhost broadcaster, participant audience
    await service.joinAgora(
      channelName: channelName,
      uid: selfUid,
      canPublish: canPublish,
      onUserJoined: (connection, remoteUid, elapsed) {},
      onUserOffline: (connection, remoteUid, reason) {},
      onAudioVolumeIndication: (speaker, totalVol) {
        final uid = speaker.uid ?? 0;
        final vol = speaker.volume ?? 0;
        speakingVolumes[uid] = vol;
      },
    );
    await service.setLocalMute(!canPublish);
    isLocalMuted.value = !canPublish;
    _applyRemoteMutePolicy();
  }
}


