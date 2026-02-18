import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:secured_calling/core/extensions/app_int_extension.dart';
import 'package:secured_calling/core/extensions/date_time_extension.dart';
import 'package:secured_calling/core/models/individual_recording_model.dart';
import 'package:secured_calling/core/services/app_firebase_service.dart';
import 'package:secured_calling/core/services/app_local_storage.dart';
import 'package:secured_calling/core/theme/app_theme.dart';
import 'package:secured_calling/features/meeting/widgets/clip_audio_downloader.dart';
import 'package:secured_calling/features/meeting/widgets/recorder_audio_tile.dart';
import 'package:secured_calling/models/meeting_detail.dart';
import 'package:secured_calling/features/meeting/services/meeting_detail_service.dart';
import 'package:secured_calling/widgets/meeting_info_card.dart';
import 'package:secured_calling/widgets/no_data_found_widget.dart';
import 'package:secured_calling/widgets/participant_list_item.dart';
import 'package:secured_calling/widgets/persistent_call_bar.dart';
import 'package:secured_calling/utils/app_logger.dart';
import 'package:secured_calling/utils/app_tost_util.dart';
import 'package:secured_calling/features/meeting/bindings/live_meeting_controller.dart';
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

  void _onRecordingPlaybackStart() {
    if (Get.isRegistered<MeetingController>()) {
      final meetingController = Get.find<MeetingController>();
      if (meetingController.isJoined.value) {
        meetingController.setMutedForRecordingPlayback(true);
        AppToastUtil.showInfoToast('Mic muted in call while playing recording.');
      }
    }
  }

  bool _isInActiveCall() {
    return Get.isRegistered<MeetingController>() && Get.find<MeetingController>().isJoined.value;
  }

  void _onRecordingPlaybackEnd() {
    if (Get.isRegistered<MeetingController>()) {
      final meetingController = Get.find<MeetingController>();
      if (meetingController.isJoined.value) {
        meetingController.setMutedForRecordingPlayback(false);
      }
    }
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
                    onPlaybackStart: _onRecordingPlaybackStart,
                    onPlaybackEnd: _onRecordingPlaybackEnd,
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
                          onPlaybackStart: _onRecordingPlaybackStart,
                          onPlaybackEnd: _onRecordingPlaybackEnd,
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
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const PersistentCallBar(),
          Expanded(
            child: Obx(() {
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
                                // if (controller.isCurrentUserHost) ...[
                                //   Column(
                                //     children: [
                                //       SizedBox(height: 16),
                                //       Text(
                                //         'Mix Recordings',
                                //         style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w400, fontSize: 14),
                                //       ),
                                //       getMixRecordingListWidget(),
                                //     ],
                                //   ),
                                // ],
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(height: 16),
                                    Text(
                                      '${controller.isCurrentUserHost ? 'Individual' : "Your"} Recordings',
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w400, fontSize: 14),
                                    ),
                                    if (_isInActiveCall())
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8.0),
                                        child: Material(
                                          color: AppTheme.primaryColor.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(8),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            child: Row(
                                              children: [
                                                Icon(Icons.info_outline, size: 18, color: AppTheme.primaryColor),
                                                SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    'You\'re in an active call. Your mic will be muted in the call while playing a recording.',
                                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.primaryColor),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    SizedBox(height: 16),
                                    getIndividualRecordingWidgets(),
                                  ],
                                ),

                                SizedBox(height: 40),
                              ],
                            ),
                          ),
                        ),
              ),
            ],
          ),
        );
      }),
          ),
        ],
      ),
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
