import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/webinar_meeting_controller.dart';
import '../models/webinar_user_model.dart';
import '../services/webinar_meeting_service.dart';
import 'host_view.dart';
import 'participant_view.dart';
import 'subhost_view.dart';

class WebinarEntryPage extends StatefulWidget {
  const WebinarEntryPage({
    super.key,
    required this.appId,
    required this.functionsBaseUrl,
    required this.roomId,
    required this.channelName,
    required this.selfUser,
  });

  final String appId;
  final String functionsBaseUrl;
  final String roomId;
  final String channelName;
  final WebinarUserModel selfUser;

  @override
  State<WebinarEntryPage> createState() => _WebinarEntryPageState();
}

class _WebinarEntryPageState extends State<WebinarEntryPage> {
  late final WebinarMeetingController controller;

  @override
  void initState() {
    super.initState();
    final service = WebinarMeetingService(appId: widget.appId, functionsBaseUrl: widget.functionsBaseUrl);
    controller = WebinarMeetingController(
      service: service,
      roomId: widget.roomId,
      channelName: widget.channelName,
      selfUser: widget.selfUser,
    );
    controller.initialize();
  }

  @override
  void dispose() {
    controller.leave();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final role = controller.selfCurrentRole.value == WebinarRole.participant && widget.selfUser.role == WebinarRole.participant
          ? WebinarRole.participant
          : (controller.selfCurrentRole.value);

      switch (role) {
        case WebinarRole.host:
          return HostView(controller: controller);
        case WebinarRole.subHost:
          return SubHostView(controller: controller);
        case WebinarRole.participant:
          return ParticipantView(controller: controller);
      }
    });
  }
}


