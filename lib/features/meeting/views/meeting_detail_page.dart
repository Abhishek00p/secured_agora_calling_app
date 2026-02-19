import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:secured_calling/core/extensions/app_int_extension.dart';
import 'package:secured_calling/core/extensions/date_time_extension.dart';
import 'package:secured_calling/core/models/individual_recording_model.dart';
import 'package:secured_calling/core/services/app_firebase_service.dart';
import 'package:secured_calling/core/services/app_local_storage.dart';
import 'package:secured_calling/core/theme/app_theme.dart';
import 'package:secured_calling/core/utils/responsive_utils.dart';
import 'package:secured_calling/features/meeting/widgets/clip_audio_downloader.dart';
import 'package:secured_calling/features/meeting/widgets/recorder_audio_tile.dart';
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
                padding: EdgeInsets.zero,
                physics: NeverScrollableScrollPhysics(),
                itemCount: controller.mixRecordings.length,
                shrinkWrap: true,
                itemBuilder: (context, index) {
                  final item = controller.mixRecordings[index];

                  return RecorderAudioTile(
                    model: SpeakingEventModel(
                      userId: '',
                      userName: '',
                      startTime: item.startTime,
                      endTime: 0,
                      recordingUrl: item.playableUrl,
                      trackStartTime: item.startTime,
                      trackStopTime: 0,
                    ),
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
                padding: EdgeInsets.zero,
                physics: NeverScrollableScrollPhysics(),
                itemCount: controller.individualRecordings.length,
                shrinkWrap: true,
                itemBuilder: (context, index) {
                  final item = controller.individualRecordings[index];

                  return Row(
                    children: [
                      Flexible(
                        child: RecorderAudioTile(
                          recordingStartTime: item.trackStartTime.toDateTimeWithSec,
                          model: item,
                          url: item.recordingUrl,
                          clipStartTime: item.startTime.toDateTimeWithSec.subtract(Duration(seconds: 2)),
                          clipEndTime: item.endTime.toDateTimeWithSec.add(Duration(seconds: 2)),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.download),
                        onPressed: () async {
                          try {
                            final downloader = ClipAudioDownloader();

                            final recordingStart = item.trackStartTime.toDateTime;

                            final clipStartTime = item.startTime.toDateTimeWithSec.subtract(const Duration(seconds: 2));

                            final clipEndTime = item.endTime.toDateTimeWithSec.add(const Duration(seconds: 2));

                            final clipStart = clipStartTime.difference(recordingStart);

                            final clipEnd = clipEndTime.difference(recordingStart);

                            final file = await downloader.downloadClip(m3u8Url: item.recordingUrl, clipStart: clipStart, clipEnd: clipEnd);

                            if (!mounted) return;

                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Audio saved successfully")));
                          } catch (e) {
                            if (!mounted) return;
                            debugPrint("Download error → $e");
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Download failed: $e")));
                          }
                        },
                      ),
                    ],
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
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: contentMaxWidth(context)),
                    child: MeetingInfoCard(meeting: meetingDetail),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    responsivePadding(context),
                    responsivePadding(context),
                    responsivePadding(context),
                    8.0,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: contentMaxWidth(context)),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppTheme.lightSurfaceColor,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: TabBar(
                          controller: tabBarController,
                          onTap: (value) {
                            controller.currentTabIndex.value = value;
                          },
                          dividerHeight: 0,
                          indicatorSize: TabBarIndicatorSize.tab,
                          indicator: BoxDecoration(
                            color: AppTheme.primaryColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          labelColor: Colors.white,
                          unselectedLabelColor: AppTheme.lightSecondaryTextColor,
                          labelStyle: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                          tabs: const [Tab(text: 'Participants'), Tab(text: 'Recordings')],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Obx(
                () =>
                    controller.currentTabIndex == 0
                        ? _buildParticipantsList(context, meetingDetail)
                        : SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: responsivePadding(context)),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(maxWidth: contentMaxWidth(context)),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(height: responsivePadding(context)),
                                    Text(
                                      '${controller.isCurrentUserHost ? 'Individual' : "Your"} Recordings',
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w400,
                                        fontSize: 14,
                                      ),
                                    ),
                                    SizedBox(height: responsivePadding(context)),
                                    getIndividualRecordingWidgets(),
                                    const SizedBox(height: 40),
                                  ],
                                ),
                              ),
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

  Widget _buildParticipantsList(BuildContext context, MeetingDetail meetingDetail) {
    if (meetingDetail.participants.isEmpty) {
      return const SliverFillRemaining(
        child: Center(
          child: Text('No participants have joined yet.', style: TextStyle(fontSize: 16, color: Colors.grey)),
        ),
      );
    }

    final padding = responsivePadding(context);
    final maxWidth = contentMaxWidth(context);

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final participant = meetingDetail.participants[index];
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: padding),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: ParticipantListItem(participant: participant, index: index),
            ),
          ),
        );
      }, childCount: meetingDetail.participants.length),
    );
  }
}
