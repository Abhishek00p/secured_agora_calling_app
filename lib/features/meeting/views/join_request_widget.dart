import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:secured_calling/app_logger.dart';
import 'package:secured_calling/core/services/app_sound_service.dart';
import 'package:secured_calling/core/services/asset_paths.dart';
import 'package:secured_calling/features/meeting/views/join_request_popup.dart';
import 'package:secured_calling/features/meeting/views/live_meeting_controller.dart';

class JoinRequestWidget extends StatefulWidget {
  const JoinRequestWidget({Key? key}) : super(key: key);
  @override
  State<JoinRequestWidget> createState() => _JoinRequestWidgetState();
}

class _JoinRequestWidgetState extends State<JoinRequestWidget> {
  final MeetingController meetingController = Get.find<MeetingController>();
  final ValueNotifier<List<Map<String, dynamic>>> _requestsNotifier = ValueNotifier([]);
  List<Map<String, dynamic>> _previousRequests = [];

  @override
  void initState() {
    super.initState();

    meetingController.fetchPendingRequests().listen((newRequests) {
      if (!_areListsEqual(_previousRequests, newRequests)) {
        AppLogger.print('prv list: $_previousRequests \nnew list: $newRequests');

        if (newRequests.length > _previousRequests.length) {
          AudioService().playJoinRequestSound(AssetPaths.joinSound);
        }

        _previousRequests = List.from(newRequests);
        _requestsNotifier.value = newRequests;
      }
    });
  }

  @override
  void dispose() {
    _requestsNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<Map<String, dynamic>>>(
      valueListenable: _requestsNotifier,
      builder: (context, requests, _) {
        if (requests.isEmpty) return const SizedBox.shrink();

        return Column(
          children: List.generate(
            requests.length,
            (i) => JoinRequestPopup(
              userName: requests[i]['name'],
              onAdmit: () => meetingController.approveJoinRequest(requests[i]['userId']),
              onDeny: () => meetingController.rejectJoinRequest(requests[i]['userId']),
            ),
          ),
        );
      },
    );
  }

  bool _areListsEqual(List<Map<String, dynamic>> a, List<Map<String, dynamic>> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i]['userId'] != b[i]['userId']) return false;
    }
    return true;
  }
}
