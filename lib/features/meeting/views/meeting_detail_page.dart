import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:secured_calling/core/extensions/app_int_extension.dart';
import 'package:secured_calling/core/extensions/date_time_extension.dart';
import 'package:secured_calling/core/services/app_firebase_service.dart';
import 'package:secured_calling/core/services/app_local_storage.dart';
import 'package:secured_calling/core/theme/app_theme.dart';
import 'package:secured_calling/features/meeting/widgets/recording_audio_row.dart';
import 'package:secured_calling/models/meeting_detail.dart';
import 'package:secured_calling/features/meeting/services/meeting_detail_service.dart';
import 'package:secured_calling/widgets/meeting_info_card.dart';
import 'package:secured_calling/widgets/no_data_found_widget.dart';
import 'package:secured_calling/widgets/participant_list_item.dart';
import 'package:secured_calling/utils/app_logger.dart';
import 'package:secured_calling/features/meeting/controllers/meeting_detail_controller.dart';

class MeetingDetailPage extends StatefulWidget {
  final String meetingId;

  const MeetingDetailPage({super.key, required this.meetingId});

  @override
  State<MeetingDetailPage> createState() => _MeetingDetailPageState();
}

class _MeetingDetailPageState extends State<MeetingDetailPage> with SingleTickerProviderStateMixin {
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
              ? NoDataFoundWidget(message: 'No mix recordings available.')
              : ListView.builder(
                physics: NeverScrollableScrollPhysics(),
                itemCount: controller.mixRecordings.length,
                shrinkWrap: true,
                itemBuilder: (context, index) {
                  final item = controller.mixRecordings[index];

                  return RecorderAudioTile(
                    title: 'Mix Rec. ${item.startTime?.toLocal().formatTime ?? ''} - ${item.stopTime?.toLocal().formatTime ?? ''}',
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
              ? NoDataFoundWidget(message: 'No individual recordings available.')
              : ListView.builder(
                physics: NeverScrollableScrollPhysics(),
                itemCount: controller.individualRecordings.length,
                shrinkWrap: true,
                itemBuilder: (context, index) {
                  final item = controller.individualRecordings[index];
                  debugPrint(
                    "track start time  ${item.trackStartTime.toDateTimeWithSec}\n clip start and end time ${item.startTime.toDateTimeWithSec}  ${item.endTime.toDateTimeWithSec}",
                  );
                  return RecorderAudioTile(
                    recordingStartTime: item.trackStartTime.toDateTimeWithSec,
                    recordingEndTime: item.trackStopTime.toDateTimeWithSec,
                    title: '${item.userName} ${item.startTime.toDateTimeWithSec.toLocal().formatTime ?? ''} ',
                    url: item.recordingUrl,
                    clipStartTime: item.startTime.toDateTimeWithSec,
                    clipEndTime: item.endTime.toDateTimeWithSec,
                    speakingEventModel: item,
                  );
                },
              ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                  IconButton(icon: const Icon(Icons.refresh), tooltip: 'Refresh', onPressed: controller.refreshMeetingDetails),
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
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: AppTheme.lightSurfaceColor, borderRadius: BorderRadius.circular(14)),
                    child: TabBar(
                      controller: tabBarController,
                      onTap: (value) {
                        controller.currentTabIndex.value = value;
                      },
                      dividerHeight: 0,
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicator: BoxDecoration(color: AppTheme.primaryColor, borderRadius: BorderRadius.circular(10)),
                      labelColor: Colors.white,
                      unselectedLabelColor: AppTheme.lightSecondaryTextColor,
                      labelStyle: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                      tabs: const [Tab(text: 'Participants'), Tab(text: 'Recordings')],
                    ),
                  ),
                ),
              ),
              Obx(
                () =>
                    controller.currentTabIndex == 0
                        ? _buildParticipantsList(meetingDetail)
                        : SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                getMixRecordingListWidget(),
                                SizedBox(height: 16),
                                if (meetingDetail.hostId == AppLocalStorage.getUserDetails().userId)
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Individual Recordings',
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w400, fontSize: 14),
                                      ),
                                      getIndividualRecordingWidgets(),
                                    ],
                                  ),
                                // getRecordingListByUserWidget(),
                              ],
                            ),
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
        child: Center(child: Text('No participants have joined yet.', style: TextStyle(fontSize: 16, color: Colors.grey))),
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
      child: Center(child: Text('No participants have joined yet.', style: TextStyle(fontSize: 16, color: Colors.grey))),
    );
  }

  return SliverList(
    delegate: SliverChildBuilderDelegate((context, index) {
      final participant = meetingDetail.participants[index];
      return ParticipantListItem(participant: participant, index: index);
    }, childCount: meetingDetail.participants.length),
  );
}
