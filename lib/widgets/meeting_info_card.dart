import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:secured_calling/models/meeting_detail.dart';
import 'package:secured_calling/utils/app_helpers.dart';
import 'package:secured_calling/core/services/app_local_storage.dart';
import 'package:secured_calling/features/meeting/services/meeting_detail_service.dart';
import 'package:secured_calling/features/meeting/widgets/extend_meeting_dialog.dart';
import 'package:secured_calling/utils/app_tost_util.dart';

class MeetingInfoCard extends StatefulWidget {
  final MeetingDetail meeting;
  final VoidCallback? onMeetingExtended;

  const MeetingInfoCard({
    super.key, 
    required this.meeting,
    this.onMeetingExtended,
  });

  @override
  State<MeetingInfoCard> createState() => _MeetingInfoCardState();
}

class _MeetingInfoCardState extends State<MeetingInfoCard> {
  bool _isPasswordVisible = false;
  bool _canExtend = false;
  final MeetingDetailService _meetingService = MeetingDetailService();

  @override
  void initState() {
    super.initState();
    _checkExtendPermission();
  }

  Future<void> _checkExtendPermission() async {
    try {
      final canExtend = await _meetingService.canExtendMeeting(widget.meeting.meetingId);
      if (mounted) {
        setState(() {
          _canExtend = canExtend;
        });
      }
    } catch (e) {
      // Silently handle error, user just won't see extend button
    }
  }

  Future<void> _showExtendMeetingDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => ExtendMeetingDialog(
        meetingId: widget.meeting.meetingId,
        meetingTitle: widget.meeting.meetingTitle,
        onExtend: (minutes, reason) async {
          await _meetingService.extendMeeting(widget.meeting.meetingId, minutes, reason: reason);
        },
      ),
    );

    if (result == true && widget.onMeetingExtended != null) {
      widget.onMeetingExtended!();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    widget.meeting.meetingTitle,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                buildStatusChip(widget.meeting.status),
              ],
            ),
            const SizedBox(height: 16.0),
            
            // Extend meeting button for hosts
            if (_canExtend && _isMeetingActive)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 16),
                child: ElevatedButton.icon(
                  onPressed: _showExtendMeetingDialog,
                  icon: const Icon(Icons.schedule),
                  label: const Text('Extend Meeting'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            
            const Divider(),
            const SizedBox(height: 16.0),
            _buildInfoRow(context, Icons.perm_identity, 'Meeting ID', widget.meeting.meetingId, copyable: true),
            _buildPasswordRow(context),
            _buildInfoRow(context, Icons.person_outline, 'Host', '${widget.meeting.hostName} (ID: ${widget.meeting.hostId})'),
            _buildInfoRow(context, Icons.group_outlined, 'Max Participants', widget.meeting.maxParticipants.toString()),
            _buildInfoRow(context, Icons.timer_outlined, 'Duration', formatDuration(widget.meeting.duration)),
            _buildInfoRow(context, Icons.calendar_today_outlined, 'Scheduled Time', '${formatDateTime(widget.meeting.scheduledStartTime)} - ${formatDateTime(widget.meeting.scheduledEndTime)}'),
            if (widget.meeting.actualStartTime != null)
              _buildInfoRow(context, Icons.access_time, 'Actual Time', '${formatDateTime(widget.meeting.actualStartTime!)} - ${widget.meeting.actualEndTime != null ? formatDateTime(widget.meeting.actualEndTime!) : "Now"}'),
            const SizedBox(height: 8.0),
            _buildInfoRow(context, Icons.people_alt_outlined, 'Total Participants', widget.meeting.totalUniqueParticipants.toString()),
            
            // Extension history section
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            _buildExtensionHistorySection(context),
          ],
        ),
      ),
    );
  }

  bool get _isMeetingActive {
    return widget.meeting.status == 'ongoing' || widget.meeting.status == 'upcoming';
  }

  Widget _buildExtensionHistorySection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.history, size: 20.0, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 16),
            Text(
              'Extension History',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        StreamBuilder(
          stream: _meetingService.getMeetingExtensionsStream(widget.meeting.meetingId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: Padding(
                padding: EdgeInsets.all(8.0),
                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              ));
            }
            
            if (snapshot.hasError || !snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Padding(
                padding: const EdgeInsets.only(left: 36),
                child: Text(
                  'No extensions yet',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              );
            }

            final extensions = snapshot.data!.docs;
            return Column(
              children: extensions.take(3).map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final minutes = data['additionalMinutes'] as int? ?? 0;
                final reason = data['reason'] as String?;
                final extendedAt = data['extendedAt']?.toDate();
                
                return Padding(
                  padding: const EdgeInsets.only(left: 36, top: 4),
                  child: Row(
                    children: [
                      Icon(Icons.add, size: 16, color: Colors.green[600]),
                      const SizedBox(width: 8),
                      Text(
                        '+${minutes}m',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.green[700],
                        ),
                      ),
                      if (reason != null && reason.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '($reason)',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      if (extendedAt != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          formatDateTime(extendedAt),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
          },
        ),
      ],
    );
  }

  Widget _buildPasswordRow(BuildContext context) {
    if (widget.meeting.meetingPass == null) {
      return _buildInfoRow(context, Icons.lock_outline, 'Password', 'No Password');
    }
    return _buildInfoRow(
      context,
      Icons.lock_outline,
      'Password',
      _isPasswordVisible ? widget.meeting.meetingPass! : '********',
      copyable: true,
      trailing: IconButton(
        icon: Icon(
          _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
          size: 20,
        ),
        onPressed: () {
          setState(() {
            _isPasswordVisible = !_isPasswordVisible;
          });
        },
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, IconData icon, String label, String value, {bool copyable = false, Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20.0, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(value, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          if (copyable)
            IconButton(
              icon: const Icon(Icons.copy, size: 18.0),
              tooltip: 'Copy',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: widget.meeting.meetingPass ?? widget.meeting.meetingId));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$label copied to clipboard')),
                );
              },
            ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }
}
