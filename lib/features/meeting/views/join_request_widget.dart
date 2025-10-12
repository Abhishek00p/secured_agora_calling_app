import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:secured_calling/utils/app_logger.dart';
import 'package:secured_calling/core/services/app_sound_service.dart';
import 'package:secured_calling/core/services/asset_paths.dart';
import 'package:secured_calling/features/meeting/views/user_join_request_popup.dart';
import 'package:secured_calling/features/meeting/bindings/live_meeting_controller.dart';

class JoinRequestWidget extends StatefulWidget {
  const JoinRequestWidget({super.key});
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
    AppLogger.print('JoinRequestWidget: Initializing join request listener');

    meetingController.fetchPendingRequests().listen(
      (newRequests) {
        AppLogger.print('JoinRequestWidget: Received ${newRequests.length} requests');

        if (!_areListsEqual(_previousRequests, newRequests)) {
          AppLogger.print(
            'JoinRequestWidget: Request list changed - prv: ${_previousRequests.length}, new: ${newRequests.length}',
          );
          AppLogger.print('Previous list: $_previousRequests');
          AppLogger.print('New list: $newRequests');

          // Play sound when new join requests arrive
          if (newRequests.length > _previousRequests.length) {
            AppLogger.print('JoinRequestWidget: Playing join request sound');
            AppSoundService().playJoinRequestSound(AssetPaths.joinSound);
          }

          _previousRequests = List.from(newRequests);
          _requestsNotifier.value = newRequests;
        } else {
          AppLogger.print('JoinRequestWidget: No change in request list');
        }
      },
      onError: (error) {
        AppLogger.print('JoinRequestWidget: Error listening to requests: $error');
      },
    );
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
        AppLogger.print('JoinRequestWidget: Building with ${requests.length} requests');

        if (requests.isEmpty) {
          AppLogger.print('JoinRequestWidget: No requests to display');
          return const SizedBox.shrink();
        }

        AppLogger.print('JoinRequestWidget: Displaying ${requests.length} join requests');
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
