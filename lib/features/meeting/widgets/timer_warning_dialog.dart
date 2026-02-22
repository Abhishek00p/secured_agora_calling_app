import 'package:flutter/material.dart';
import 'package:secured_calling/core/utils/responsive_utils.dart';

class TimerWarningDialog extends StatefulWidget {
  final VoidCallback onExtend;
  final VoidCallback onDismiss;

  const TimerWarningDialog({super.key, required this.onExtend, required this.onDismiss});

  @override
  State<TimerWarningDialog> createState() => TimerWarningDialogState();
}

class TimerWarningDialogState extends State<TimerWarningDialog> {
  int _remainingSeconds = 300; // Default 5 minutes

  void updateRemainingTime(int seconds) {
    if (mounted) {
      setState(() {
        _remainingSeconds = seconds;
      });
    }
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final padding = responsivePadding(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.warning, color: Colors.orange, size: 28),
          SizedBox(width: padding / 2),
          const Text('Meeting Time Warning', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: dialogMaxWidth(context)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your meeting is about to end!',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.red[700]),
            ),
            SizedBox(height: padding),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(padding),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red[200]!),
            ),
            child: Column(
              children: [
                Text(
                  'Time Remaining',
                  style: TextStyle(fontSize: 14, color: Colors.red[700], fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatTime(_remainingSeconds),
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.red[700],
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 8),
                Text('minutes:seconds', style: TextStyle(fontSize: 12, color: Colors.red[600])),
              ],
            ),
          ),
          SizedBox(height: padding),
          Text(
            'To continue your meeting, you can extend the time using the button below.',
            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
          ),
          SizedBox(height: padding / 2),
          Container(
            padding: EdgeInsets.all(padding),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'This dialog will stay open until you take action or the meeting ends.',
                    style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                  ),
                ),
              ],
            ),
          ),
        ],
        ),
      ),
      actions: [
        if (_remainingSeconds > 60)
          TextButton(onPressed: widget.onDismiss, child: const Text('Dismiss', style: TextStyle(color: Colors.grey))),
        ElevatedButton.icon(
          onPressed: widget.onExtend,
          icon: const Icon(Icons.schedule),
          label: const Text('Extend Meeting'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: padding, vertical: 12),
          ),
        ),
      ],
      actionsPadding: EdgeInsets.fromLTRB(padding, 0, padding, padding),
    );
  }
}
