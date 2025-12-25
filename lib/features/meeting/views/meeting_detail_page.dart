import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:secured_calling/core/extensions/app_int_extension.dart';
import 'package:secured_calling/core/extensions/date_time_extension.dart';
import 'package:secured_calling/core/services/app_firebase_service.dart';
import 'package:secured_calling/features/meeting/widgets/audio_player.dart';
import 'package:secured_calling/features/meeting/widgets/recording_audio_row.dart';
import 'package:secured_calling/models/meeting_detail.dart';
import 'package:secured_calling/features/meeting/services/meeting_detail_service.dart';
import 'package:secured_calling/widgets/meeting_info_card.dart';
import 'package:secured_calling/widgets/participant_list_item.dart';
import 'package:secured_calling/utils/app_logger.dart';
import 'package:secured_calling/features/meeting/controllers/meeting_detail_controller.dart';

class MeetingDetailPage extends StatefulWidget {
  final String meetingId;

  const MeetingDetailPage({super.key, required this.meetingId});

  @override
  State<MeetingDetailPage> createState() => _MeetingDetailPageState();
}

class _MeetingDetailPageState extends State<MeetingDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController tabBarController;
  late MeetingDetailController controller;
  @override
  void initState() {
    super.initState();
    tabBarController = TabController(length: 2, vsync: this);
    controller =
        Get.isRegistered<MeetingDetailController>()
            ? Get.find<MeetingDetailController>()
            : Get.put(MeetingDetailController(meetingId: widget.meetingId));
  }

  Widget getMixRecordingListWidget() {
    return Obx(
      () =>
          controller.isMixRecordingLoading.value
              ? Center(child: CircularProgressIndicator.adaptive())
              : controller.mixRecordings.isEmpty
              ? Text('No mix recordings available.')
              : ListView.builder(
                physics: NeverScrollableScrollPhysics(),
                itemCount: controller.mixRecordings.length,
                shrinkWrap: true,
                itemBuilder: (context, index) {
                  final item = controller.mixRecordings[index];

                  return RecorderAudioTile(
                    title:
                        'Mix Rec. ${item.startTime?.toLocal().formatTime ?? ''} - ${item.stopTime?.toLocal().formatTime ?? ''}',
                    url: item.playableUrl,
                  );
                },
              ),
    );
  }

  Widget getIndividualRecordingWidgets() {
    return Obx(
      () =>
          controller.isIndividualRecordingLoading.value
              ? Center(child: CircularProgressIndicator.adaptive())
              : controller.individualRecordings.isEmpty
              ? Text('No individual recordings available.')
              : ListView.builder(
                physics: NeverScrollableScrollPhysics(),
                itemCount: controller.individualRecordings.length,
                shrinkWrap: true,
                itemBuilder: (context, index) {
                  final item = controller.individualRecordings[index];

                  return RecorderAudioTile(
                    title:
                        '${item.userName} ${item.startTime?.toLocal().formatTime ?? ''} - ${item.stopTime?.toLocal().formatTime ?? ''}',
                    url: item.playableUrl,
                  );
                },
              ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Obx(() {
        if (controller.isLoading.value &&
            controller.meetingDetail.value == null) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.hasError.value) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text(
                  'Failed to load meeting details',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  controller.errorMessage.value ?? 'Unknown error occurred',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: controller.refreshMeetingDetails,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
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
              SliverToBoxAdapter(
                child: MeetingInfoCard(meeting: meetingDetail),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
                  child: TabBar(
                    onTap: (value) {
                      controller.currentTabIndex.value = value;
                    },
                    tabs:
                        ['Participants', 'Recordings']
                            .map(
                              (tabTitle) => Tab(
                                text: tabTitle,
                                // : ' (${meetingDetail.recordings.length})'),
                              ),
                            )
                            .toList(),
                    controller: tabBarController,
                  ),
                ),
              ),
              Obx(
                () =>
                    controller.currentTabIndex == 0
                        ? _buildParticipantsList(meetingDetail)
                        : SliverToBoxAdapter(
                          child: Column(
                            children: [
                              getMixRecordingListWidget(),
                              getIndividualRecordingWidgets(),
                              // getRecordingListByUserWidget(),
                            ],
                          ),
                        ),
              ),
            ],
          ),
        );
      }),
    );
  }

  // Widget _buildRecordingsList(MeetingDetail meetingDetail) {
  Widget _buildParticipantsList(MeetingDetail meetingDetail) {
    if (meetingDetail.participants.isEmpty) {
      return const SliverFillRemaining(
        child: Center(
          child: Text(
            'No participants have joined yet.',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
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
} //     }, childCount: meetingDetail.recordings.length),

//   );
// }
Widget _buildParticipantsList(MeetingDetail meetingDetail) {
  if (meetingDetail.participants.isEmpty) {
    return const SliverFillRemaining(
      child: Center(
        child: Text(
          'No participants have joined yet.',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
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
