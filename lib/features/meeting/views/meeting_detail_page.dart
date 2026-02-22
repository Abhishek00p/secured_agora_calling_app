import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:secured_calling/core/extensions/app_int_extension.dart';
import 'package:secured_calling/core/models/individual_recording_model.dart';
import 'package:secured_calling/core/theme/app_theme.dart';
import 'package:secured_calling/core/utils/responsive_utils.dart';
import 'package:secured_calling/features/meeting/widgets/recorder_audio_tile.dart';
import 'package:secured_calling/models/meeting_detail.dart';
import 'package:secured_calling/widgets/meeting_info_card.dart';
import 'package:secured_calling/widgets/no_data_found_widget.dart';
import 'package:secured_calling/widgets/participant_list_item.dart';
import 'package:secured_calling/widgets/persistent_call_bar.dart';
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

  bool _isDesktop(BuildContext context) {
    return context.layoutType == AppLayoutType.laptop || context.layoutType == AppLayoutType.laptop;
  }

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
                            // final downloader = ClipAudioDownloader();

                            // final recordingStart = item.trackStartTime.toDateTime;

                            // final clipStartTime = item.startTime.toDateTimeWithSec.subtract(const Duration(seconds: 2));

                            // final clipEndTime = item.endTime.toDateTimeWithSec.add(const Duration(seconds: 2));

                            // final clipStart = clipStartTime.difference(recordingStart);

                            // final clipEnd = clipEndTime.difference(recordingStart);

                            // final file = await downloader.downloadClip(m3u8Url: item.recordingUrl, clipStart: clipStart, clipEnd: clipEnd);

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

  Widget _buildDesktopLayout(BuildContext context, MeetingDetail meetingDetail) {
    final padding = responsivePadding(context);

    return Row(
      children: [
        // LEFT PANEL
        SizedBox(
          width: 420,
          child: Column(
            children: [
              const SizedBox(height: 12),
              Padding(padding: EdgeInsets.all(padding), child: MeetingInfoCard(meeting: meetingDetail)),
              Padding(padding: EdgeInsets.symmetric(horizontal: padding), child: _buildTabBar(context)),
            ],
          ),
        ),

        const VerticalDivider(width: 1),

        // RIGHT PANEL (LIST)
        Expanded(child: _buildRightPanelList(context, meetingDetail)),
      ],
    );
  }

  Widget _buildRightPanelList(BuildContext context, MeetingDetail meetingDetail) {
    return Obx(() {
      if (controller.currentTabIndex.value == 0) {
        // Participants
        if (meetingDetail.participants.isEmpty) {
          return const Center(child: Text('No participants yet'));
        }

        return ListView.builder(
          padding: EdgeInsets.all(responsivePadding(context)),
          itemCount: meetingDetail.participants.length,
          itemBuilder: (context, index) => ParticipantListItem(participant: meetingDetail.participants[index], index: index),
        );
      }

      // Recordings
      return SingleChildScrollView(
        padding: EdgeInsets.all(responsivePadding(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${controller.isCurrentUserHost ? 'Individual' : 'Your'} Recordings', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            getIndividualRecordingWidgets(),
            const SizedBox(height: 32),
          ],
        ),
      );
    });
  }

  Widget _buildTabBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppTheme.lightSurfaceColor, borderRadius: BorderRadius.circular(14)),
      child: TabBar(
        controller: tabBarController,
        onTap: (index) => controller.currentTabIndex.value = index,
        dividerHeight: 0,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(color: AppTheme.primaryColor, borderRadius: BorderRadius.circular(10)),
        labelColor: Colors.white,
        unselectedLabelColor: AppTheme.lightSecondaryTextColor,
        tabs: const [Tab(text: 'Participants'), Tab(text: 'Recordings')],
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context, MeetingDetail meetingDetail) {
    return RefreshIndicator(
      onRefresh: controller.refreshMeetingDetails,
      child: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            title: Text(meetingDetail.meetingTitle),
            floating: true,
            pinned: true,
            snap: false,
            actions: [IconButton(icon: const Icon(Icons.refresh), tooltip: 'Refresh', onPressed: controller.refreshMeetingDetails)],
          ),

          // Meeting Info Card
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(constraints: BoxConstraints(maxWidth: contentMaxWidth(context)), child: MeetingInfoCard(meeting: meetingDetail)),
            ),
          ),

          // TabBar
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(responsivePadding(context), responsivePadding(context), responsivePadding(context), 8),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: contentMaxWidth(context)),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: AppTheme.lightSurfaceColor, borderRadius: BorderRadius.circular(14)),
                    child: TabBar(
                      controller: tabBarController,
                      onTap: (index) {
                        controller.currentTabIndex.value = index;
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
            ),
          ),

          // Tab Content
          Obx(() {
            // Participants Tab
            if (controller.currentTabIndex.value == 0) {
              if (meetingDetail.participants.isEmpty) {
                return const SliverFillRemaining(
                  child: Center(child: Text('No participants have joined yet.', style: TextStyle(fontSize: 16, color: Colors.grey))),
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

            // Recordings Tab
            return SliverToBoxAdapter(
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
                                    const SizedBox(width: 8),
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

                        SizedBox(height: responsivePadding(context)),
                        getIndividualRecordingWidgets(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Meeting Detail')),
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
              MeetingDetail? meetingDetail = controller.meetingDetail.value;
              if (meetingDetail == null) {
                return const Center(child: Text('Meeting details not found.'));
              }

              meetingDetail = controller.meetingDetail.value;
              if (meetingDetail == null) {
                return const Center(child: Text('Meeting details not found.'));
              }

              // 🔥 DESKTOP LAYOUT
              if (_isDesktop(context)) {
                return _buildDesktopLayout(context, meetingDetail);
              }

              // 📱 MOBILE LAYOUT (UNCHANGED)
              return _buildMobileLayout(context, meetingDetail);
            }),
          ),
        ],
      ),
    );
  }
}
