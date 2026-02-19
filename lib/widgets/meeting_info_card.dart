import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:secured_calling/models/meeting_detail.dart';
import 'package:secured_calling/utils/app_helpers.dart';
import 'package:secured_calling/utils/app_tost_util.dart';

class MeetingInfoCard extends StatefulWidget {
  final MeetingDetail meeting;

  const MeetingInfoCard({super.key, required this.meeting});

  @override
  State<MeetingInfoCard> createState() => _MeetingInfoCardState();
}

class _MeetingInfoCardState extends State<MeetingInfoCard> {
  bool _isPasswordVisible = false;

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
            // Row(
            //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
            //   children: [
            //     Expanded(
            //       child: Text(
            //         widget.meeting.meetingTitle,
            //         style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            //         overflow: TextOverflow.ellipsis,
            //       ),
            //     ),
            //     buildStatusChip(widget.meeting.status),
            //   ],
            // ),
            // const SizedBox(height: 16.0),

            // const Divider(),
            // const SizedBox(height: 16.0),
            _buildInfoRow(context, Icons.perm_identity, 'Meeting ID', widget.meeting.meetingId, copyable: true),
            _buildPasswordRow(context),
            _buildInfoRow(context, Icons.person_outline, 'Host', '${widget.meeting.hostName} '),
            // _buildInfoRow(context, Icons.group_outlined, 'Max Participants', widget.meeting.maxParticipants.toString()),
            _buildInfoRow(context, Icons.timer_outlined, 'Duration', formatDuration(widget.meeting.duration)),

            // _buildInfoRow(context, Icons.calendar_today_outlined, 'Scheduled Time', '${formatDateTime(widget.meeting.scheduledStartTime)} - ${formatDateTime(widget.meeting.scheduledEndTime)}'),
            // if (widget.meeting.actualStartTime != null)
            //   _buildInfoRow(context, Icons.access_time, 'Actual Time', '${formatDateTime(widget.meeting.actualStartTime!)} - ${widget.meeting.actualEndTime != null ? formatDateTime(widget.meeting.actualEndTime!) : "Now"}'),
            // const SizedBox(height: 8.0),
            // _buildInfoRow(context, Icons.people_alt_outlined, 'Total Participants', widget.meeting.totalUniqueParticipants.toString()),
          ],
        ),
      ),
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
        icon: Icon(_isPasswordVisible ? Icons.visibility_off : Icons.visibility, size: 20),
        onPressed: () {
          setState(() {
            _isPasswordVisible = !_isPasswordVisible;
          });
        },
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value, {
    bool copyable = false,
    Widget? trailing,
  }) {
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
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label copied to clipboard')));
              },
            ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }
}
