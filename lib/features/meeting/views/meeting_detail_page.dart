import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:secured_calling/core/extensions/app_int_extension.dart';
import 'package:secured_calling/models/meeting_detail.dart';
import 'package:secured_calling/features/meeting/services/meeting_detail_service.dart';
import 'package:secured_calling/widgets/meeting_info_card.dart';
import 'package:secured_calling/widgets/participant_list_item.dart';
import 'package:secured_calling/utils/app_logger.dart';
import 'package:secured_calling/features/meeting/controllers/meeting_detail_controller.dart';

class MeetingDetailPage extends GetView<MeetingDetailController> {
  final String meetingId;

  const MeetingDetailPage({super.key, required this.meetingId});

  @override
  Widget build(BuildContext context) {
    // Initialize controller with meeting ID
    Get.put(MeetingDetailController(meetingId: meetingId));

    return Scaffold(
      body: Obx(() {
        if (controller.isLoading.value && controller.meetingDetail.value == null) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.hasError.value) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text('Failed to load meeting details', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  controller.errorMessage.value ?? 'Unknown error occurred',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: controller.refreshMeetingDetails,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                ),
              ],
            ),
          );
        }

        final meetingDetail = controller.meetingDetail.value;
        if (meetingDetail == null) {
          return const Center(child: Text('Meeting details not found.'));
        }

        return RefreshIndicator(
          onRefresh: controller.refreshMeetingDetails,
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                title: Text(meetingDetail.meetingTitle),
                floating: true,
                pinned: true,
                snap: false,
                actions: [
                  // Refresh button in app bar
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh',
                    onPressed: controller.refreshMeetingDetails,
                  ),
                  // IconButton(
                  //   icon: const Icon(Icons.share),
                  //   tooltip: 'Share Meeting',
                  //   onPressed: () {
                  //     // Implement sharing logic
                  //   },
                  // ),
                ],
              ),
              SliverToBoxAdapter(child: MeetingInfoCard(meeting: meetingDetail)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
                  child: TabBar(tabs: ['Participants', 'Recordings']
                      .map((tabTitle) => Tab(
                            text: tabTitle +
                                (tabTitle == 'Participants'
                                    ? ' (${meetingDetail.participants.length})':'0'),
                                    // : ' (${meetingDetail.recordings.length})'),
                          ))
                      .toList(),
                  ),
                ),
              ),
              _buildParticipantsList(meetingDetail),
            ],
          ),
        );
      }),
    );
  }

  // Widget _buildRecordingsList(MeetingDetail meetingDetail) {
  //   if (meetingDetail.recordings.isEmpty) {
  //     return const SliverFillRemaining(
  //       child: Center(
  //         child: Text('No recordings available.', style: TextStyle(fontSize: 16, color: Colors.grey)),
  //       ),
  //     );
  //   }

  //   return SliverList(
  //     delegate: SliverChildBuilderDelegate((context, index) {
  //       final recording = meetingDetail.recordings[index];
  //       return ListTile(
  //         leading: const Icon(Icons.audio_file),
  //         title: Text('Recording ${index + 1}'),
  //         subtitle: Text('Duration: ${recording.duration.inMinutes} mins'),
  //         trailing: IconButton(
  //           icon: const Icon(Icons.download),
  //           onPressed: () {
  //             // Implement download logic
  //           },
  //         ),
  //       );
  //     }, childCount: meetingDetail.recordings.length),
  //   );
  // }
  Widget _buildParticipantsList(MeetingDetail meetingDetail) {
    if (meetingDetail.participants.isEmpty) {
      return const SliverFillRemaining(
        child: Center(
          child: Text('No participants have joined yet.', style: TextStyle(fontSize: 16, color: Colors.grey)),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final participant = meetingDetail.participants[index];
        return ParticipantListItem(participant: participant, index: index);
      }, childCount: meetingDetail.participants.length),
    );
  }
}
