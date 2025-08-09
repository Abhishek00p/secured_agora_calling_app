import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/webinar_user_model.dart';

class WebinarMeetingService {
  WebinarMeetingService({
    required this.appId,
    required this.functionsBaseUrl,
    FirebaseFirestore? firestore,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        super();

  final String appId;
  final String functionsBaseUrl; // e.g., https://us-central1-<project>.cloudfunctions.net/api
  final FirebaseFirestore _firestore;

  RtcEngine? _engine;

  // Firestore collections
  CollectionReference<Map<String, dynamic>> _roomsCol() => _firestore.collection('webinarRooms');

  Future<RtcEngine> createEngineIfNeeded() async {
    if (_engine != null) return _engine!;
    final engine = createAgoraRtcEngine();
    await engine.initialize(RtcEngineContext(appId: appId));
    _engine = engine;
    return engine;
  }

  Future<void> leaveAndDestroy() async {
    try {
      await _engine?.leaveChannel();
    } finally {
      await _engine?.release(sync: true);
      _engine = null;
    }
  }

  Future<String> _fetchRtcToken({required String channelName, required int uid, required bool canPublish}) async {
    final roleParam = canPublish ? '1' : '0';
    final uri = Uri.parse('$functionsBaseUrl/generateToken?channelName=$channelName&uid=$uid&userRole=$roleParam');
    final client = HttpClient();
    final request = await client.getUrl(uri);
    final response = await request.close();
    if (response.statusCode != 200) {
      throw Exception('Failed to get token: ${response.statusCode}');
    }
    final responseBody = await response.transform(const Utf8Decoder()).join();
    final Map<String, dynamic> json = jsonDecode(responseBody) as Map<String, dynamic>;
    final token = json['token'] as String?;
    if (token == null) {
      throw Exception('Invalid token response');
    }
    return token;
  }

  // Room schema:
  // webinarRooms/{roomId}
  //   - channelName
  //   - hostId
  //   - createdAt
  // webinarRooms/{roomId}/members/{userId}
  //   - WebinarUserModel map
  // webinarRooms/{roomId}/signals/{autoId}
  //   - type, fromUserId, toUserId?, payload, createdAt

  Future<void> createOrJoinRoom({
    required String roomId,
    required String channelName,
    required WebinarUserModel self,
  }) async {
    final roomRef = _roomsCol().doc(roomId);
    await _firestore.runTransaction((tx) async {
      final roomSnap = await tx.get(roomRef);
      if (!roomSnap.exists) {
        tx.set(roomRef, {
          'roomId': roomId,
          'channelName': channelName,
          'hostId': self.role == WebinarRole.host ? self.userId : null,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      final memberRef = roomRef.collection('members').doc(self.userId);
      tx.set(memberRef, self.toMap(), SetOptions(merge: true));
    });
  }

  Stream<List<WebinarUserModel>> watchMembers(String roomId) {
    return _roomsCol()
        .doc(roomId)
        .collection('members')
        .snapshots()
        .map((qs) => qs.docs.map((d) => WebinarUserModel.fromMap(d.data())).toList());
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchSignals(String roomId) {
    return _roomsCol()
        .doc(roomId)
        .collection('signals')
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  Future<void> sendSignal({
    required String roomId,
    required String type,
    required String fromUserId,
    String? toUserId,
    Map<String, dynamic>? payload,
  }) async {
    await _roomsCol().doc(roomId).collection('signals').add({
      'type': type,
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'payload': payload ?? <String, dynamic>{},
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateMember(String roomId, WebinarUserModel user) async {
    await _roomsCol().doc(roomId).collection('members').doc(user.userId).set(user.toMap(), SetOptions(merge: true));
  }

  Future<void> removeMember(String roomId, String userId) async {
    await _roomsCol().doc(roomId).collection('members').doc(userId).delete();
  }

  Future<void> joinAgora({
    required String channelName,
    required int uid,
    required bool canPublish,
    required Function(RtcConnection, int, int) onUserJoined,
    required Function(RtcConnection, int, UserOfflineReasonType) onUserOffline,
    required Function(AudioVolumeInfo, int) onAudioVolumeIndication,
  }) async {
    final engine = await createEngineIfNeeded();
    await engine.enableAudio();
    await engine.setChannelProfile(ChannelProfileType.channelProfileLiveBroadcasting);
    await engine.enableAudioVolumeIndication(interval: 200, smooth: 3, reportVad: true);

    engine.registerEventHandler(RtcEngineEventHandler(
      onUserJoined: onUserJoined,
      onUserOffline: onUserOffline,
      onAudioVolumeIndication: (connection, speakers, speakerCount, totalVolume) {
        if (speakers.isNotEmpty) {
          for (final speaker in speakers) {
            onAudioVolumeIndication(speaker, totalVolume);
          }
        }
      },
    ));

    // Set role based on publish capability
    await engine.setClientRole(role: canPublish ? ClientRoleType.clientRoleBroadcaster : ClientRoleType.clientRoleAudience);

    final token = await _fetchRtcToken(channelName: channelName, uid: uid, canPublish: canPublish);

    await engine.joinChannel(
      token: token,
      channelId: channelName,
      uid: uid,
      options: const ChannelMediaOptions(
        publishMicrophoneTrack: true,
        autoSubscribeAudio: true,
      ),
    );
  }

  Future<void> setPublishCapability(bool canPublish) async {
    final engine = _engine;
    if (engine == null) return;
    await engine.setClientRole(role: canPublish ? ClientRoleType.clientRoleBroadcaster : ClientRoleType.clientRoleAudience);
    await engine.muteLocalAudioStream(!canPublish);
  }

  Future<void> muteRemoteAudio(int uid, bool mute) async {
    final engine = _engine;
    if (engine == null) return;
    await engine.muteRemoteAudioStream(uid: uid, mute: mute);
  }

  Future<void> setLocalMute(bool mute) async {
    final engine = _engine;
    if (engine == null) return;
    await engine.muteLocalAudioStream(mute);
  }

  Future<void> setPlaybackMute(bool mute) async {
    final engine = _engine;
    if (engine == null) return;
    await engine.muteAllRemoteAudioStreams(mute);
  }
}


