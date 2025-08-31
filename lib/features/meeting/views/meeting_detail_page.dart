import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
                Text(
                  'Failed to load meeting details',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  controller.errorMessage.value ?? 'Unknown error occurred',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: controller.refreshMeetingDetails,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
                  IconButton(
                    icon: const Icon(Icons.share),
                    tooltip: 'Share Meeting',
                    onPressed: () {
                      // Implement sharing logic
                    },
                  ),
                ],
              ),
              SliverToBoxAdapter(
                child: MeetingInfoCard(
                  meeting: meetingDetail,
                  onMeetingExtended: controller.onMeetingExtended,
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Participants (${meetingDetail.participants.length})',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      // Quick refresh button for participants
                      IconButton(
                        icon: const Icon(Icons.refresh, size: 20),
                        tooltip: 'Refresh Participants',
                        onPressed: controller.refreshParticipants,
                      ),
                    ],
                  ),
                ),
              ),
              _buildParticipantsList(meetingDetail),
              
              // Real-time meeting updates section
              SliverToBoxAdapter(
                child: _buildRealTimeUpdatesSection(),
              ),
              
              // Extension history section
              SliverToBoxAdapter(
                child: _buildExtensionHistorySection(),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildRealTimeUpdatesSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.update, color: Theme.of(Get.context!).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Real-time Updates',
                style: Theme.of(Get.context!).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              // Refresh button for real-time updates
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                tooltip: 'Refresh Updates',
                onPressed: controller.refreshRealTimeUpdates,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Obx(() {
            if (controller.isRealTimeLoading.value) {
              return const Row(
                children: [
                  SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 12),
                  Text('Listening for updates...'),
                ],
              );
            }
            
            if (controller.realTimeError.value != null) {
              return Row(
                children: [
                  Icon(Icons.error, color: Colors.red, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Error: ${controller.realTimeError.value}',
                      style: TextStyle(color: Colors.red[700]),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 16),
                    onPressed: controller.refreshRealTimeUpdates,
                  ),
                ],
              );
            }

            final lastUpdated = controller.lastUpdated.value;
            if (lastUpdated != null) {
              return Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Meeting updated: ${_formatLastUpdated(lastUpdated)}',
                      style: TextStyle(color: Colors.green[700]),
                    ),
                  ),
                ],
              );
            }

            return const Text('Meeting is up to date');
          }),
        ],
      ),
    );
  }

  Widget _buildExtensionHistorySection() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history, color: Colors.blue[700]),
              const SizedBox(width: 8),
              Text(
                'Extension History',
                style: Theme.of(Get.context!).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
              ),
              const Spacer(),
              // Refresh button for extension history
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                tooltip: 'Refresh History',
                onPressed: controller.refreshExtensionHistory,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Obx(() {
            if (controller.isExtensionHistoryLoading.value) {
              return const Center(child: Padding(
                padding: EdgeInsets.all(8.0),
                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              ));
            }
            
            if (controller.extensionHistory.value.isEmpty) {
              return Padding(
                padding: const EdgeInsets.only(left: 36),
                child: Text(
                  'No extensions yet',
                  style: Theme.of(Get.context!).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              );
            }

            final extensions = controller.extensionHistory.value;
            return Column(
              children: extensions.take(5).map((extension) {
                return Padding(
                  padding: const EdgeInsets.only(left: 36, top: 4),
                  child: Row(
                    children: [
                      Icon(Icons.add, size: 16, color: Colors.green[600]),
                      const SizedBox(width: 8),
                      Text(
                        '+${extension['additionalMinutes']}m',
                        style: Theme.of(Get.context!).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.green[700],
                        ),
                      ),
                      if (extension['reason'] != null && extension['reason'].isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '(${extension['reason']})',
                            style: Theme.of(Get.context!).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      if (extension['extendedAt'] != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          _formatLastUpdated(extension['extendedAt']),
                          style: Theme.of(Get.context!).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[500],
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            );
          }),
        ],
      ),
    );
  }

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
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final participant = meetingDetail.participants[index];
          return ParticipantListItem(participant: participant, index: index);
        },
        childCount: meetingDetail.participants.length,
      ),
    );
  }

  String _formatLastUpdated(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else {
      return '${difference.inDays} days ago';
    }
  }
}
