import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:secured_calling/core/models/individual_recording_model.dart';
import 'package:secured_calling/core/services/download_controller.dart';
import 'package:secured_calling/core/services/download_manager_service.dart';
import 'package:secured_calling/core/theme/app_theme.dart';
import 'package:secured_calling/core/utils/responsive_utils.dart';
import 'package:secured_calling/features/meeting/widgets/clip_audio_downloader.dart';
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
  final String meetingName;
  const MeetingDetailPage({super.key, required this.meetingId, required this.meetingName});

  @override
  State<MeetingDetailPage> createState() => _MeetingDetailPageState();
}

class _MeetingDetailPageState extends State<MeetingDetailPage> with SingleTickerProviderStateMixin {
  late TabController tabBarController;
  late MeetingDetailController controller;

  // Tracks which recordings are actively being downloaded, keyed by a unique id.
  final Map<String, bool> _downloadingMap = {};

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

  // ──────────────────────────────────────────────────────────────────────────
  // Download helpers
  // ──────────────────────────────────────────────────────────────────────────

  bool _isDownloading(String key) => _downloadingMap[key] == true;

  void _setDownloading(String key, bool value) {
    if (mounted) setState(() => _downloadingMap[key] = value);
  }

  /// Downloads a full `.m4a` from [audioUrl] (whole mix or server-trimmed individual URL).
  Future<void> _handleDownloadFull({required String audioUrl, required String downloadKey, String? fileName}) async {
    if (_isDownloading(downloadKey)) return;
    _setDownloading(downloadKey, true);

    final displayName = (fileName ?? 'recording').replaceAll('_', ' ');
    final dlService = DownloadManagerService.instance;
    final dlController = DownloadController();

    await dlService.onDownloadStarted(
      downloadKey: downloadKey,
      fileName: displayName,
      meetingId: widget.meetingId,
      meetingName: widget.meetingName,
      controller: dlController,
    );

    try {
      await dlController.checkPoint();
      final downloader = ClipAudioDownloader();
      final savedMsg = await downloader.downloadFull(
        audioUrl: audioUrl,
        fileName: fileName,
        onProgress: (received, total) {
          dlService.onProgress(downloadKey: downloadKey, downloaded: received, total: total);
        },
      );

      await dlService.onDownloadComplete(downloadKey: downloadKey, savedMessage: savedMsg);
      if (mounted) AppToastUtil.showSuccessToast('Saved to: $savedMsg');
    } on DownloadCancelledException {
      debugPrint('Download $downloadKey was cancelled');
    } catch (e) {
      debugPrint('Download error → $e');
      await dlService.onDownloadError(downloadKey: downloadKey, fileName: displayName, error: e.toString());
      if (mounted) AppToastUtil.showErrorToast('Download failed: $e');
    } finally {
      _setDownloading(downloadKey, false);
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Playback callbacks
  // ──────────────────────────────────────────────────────────────────────────

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

  // ──────────────────────────────────────────────────────────────────────────
  // Recording list widgets
  // ──────────────────────────────────────────────────────────────────────────

  Widget getMixRecordingListWidget() {
    return Obx(
      () =>
          controller.isMixRecordingLoading.value
              ? const Center(child: CircularProgressIndicator.adaptive())
              : controller.mixRecordings.isEmpty
              ? const NoDataFoundWidget(message: 'No mix recordings available.')
              : ListView.builder(
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: controller.mixRecordings.length,
                shrinkWrap: true,
                itemBuilder: (context, index) {
                  final item = controller.mixRecordings[index];
                  final downloadKey = 'mix_$index';
                  final downloading = _isDownloading(downloadKey);

                  return Row(
                    children: [
                      Flexible(
                        child: RecorderAudioTile(
                          model: SpeakingEventModel(
                            userId: '',
                            userName: '',
                            startTime: item.startTime,
                            endTime: item.endTime,
                            recordingUrl: item.playableUrl,
                            trackStartTime: item.startTime,
                            trackStopTime: item.endTime,
                          ),
                          url: item.playableUrl,
                          onPlaybackStart: _onRecordingPlaybackStart,
                          onPlaybackEnd: _onRecordingPlaybackEnd,
                        ),
                      ),
                      IconButton(
                        tooltip: downloading ? 'Downloading…' : 'Download audio',
                        icon:
                            downloading
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.download_rounded),
                        onPressed:
                            downloading
                                ? null
                                : () => _handleDownloadFull(
                                  audioUrl: item.playableUrl,
                                  downloadKey: downloadKey,
                                  fileName: 'mix_recording_${index + 1}',
                                ),
                      ),
                    ],
                  );
                },
              ),
    );
  }

  Widget getIndividualRecordingWidgets() {
    return Obx(
      () =>
          controller.isIndividualRecordingLoading.value
              ? const Center(child: CircularProgressIndicator.adaptive())
              : controller.individualRecordings.isEmpty
              ? const NoDataFoundWidget(message: 'No individual recordings available.')
              : ListView.builder(
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: controller.individualRecordings.length,
                shrinkWrap: true,
                itemBuilder: (context, index) {
                  final item = controller.individualRecordings[index];
                  final downloadKey = 'individual_$index';
                  final downloading = _isDownloading(downloadKey);

                  return Row(
                    children: [
                      Flexible(
                        child: RecorderAudioTile(
                          model: item,
                          url: item.recordingUrl,
                          onPlaybackStart: _onRecordingPlaybackStart,
                          onPlaybackEnd: _onRecordingPlaybackEnd,
                        ),
                      ),
                      IconButton(
                        tooltip: downloading ? 'Downloading…' : 'Download audio',
                        icon:
                            downloading
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.download_rounded),
                        onPressed:
                            downloading
                                ? null
                                : () {
                                  final safeName =
                                      item.userName.isNotEmpty ? '${item.userName}_recording_${item.startTime}' : 'recording_${index + 1}';

                                  _handleDownloadFull(audioUrl: item.recordingUrl, downloadKey: downloadKey, fileName: safeName);
                                },
                      ),
                    ],
                  );
                },
              ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Layout builders
  // ──────────────────────────────────────────────────────────────────────────

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
            if (controller.loggedInUserData.isMember && controller.canCurrentUserSeeMixRecording) ...[
              Text('Mix Recordings', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              getMixRecordingListWidget(),
              const SizedBox(height: 20),
            ],
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

                        if (controller.loggedInUserData.isMember && controller.canCurrentUserSeeMixRecording) ...[
                          Text('Mix Recordings', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w400, fontSize: 14)),
                          SizedBox(height: responsivePadding(context)),
                          getMixRecordingListWidget(),
                          SizedBox(height: responsivePadding(context)),
                        ],

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
      appBar: AppBar(title: Text(widget.meetingName)),
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

              // Desktop layout
              if (_isDesktop(context)) {
                return _buildDesktopLayout(context, meetingDetail);
              }

              // Mobile layout
              return _buildMobileLayout(context, meetingDetail);
            }),
          ),
        ],
      ),
    );
  }
}
