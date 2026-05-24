import 'package:flutter/material.dart';
import 'package:secured_calling/core/extensions/app_int_extension.dart';
import 'package:secured_calling/core/extensions/date_time_extension.dart';
import 'package:secured_calling/core/models/individual_recording_item.dart';
import 'package:secured_calling/core/theme/app_theme.dart';
import 'package:secured_calling/features/meeting/widgets/recorder_audio_tile.dart';

class IndividualRecordingRow extends StatelessWidget {
  final IndividualRecordingItem item;
  final Widget? trailing;
  final VoidCallback? onPlaybackStart;
  final VoidCallback? onPlaybackEnd;

  const IndividualRecordingRow({
    required this.item,
    this.trailing,
    this.onPlaybackStart,
    this.onPlaybackEnd,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (item.hasPlayableUrl) {
      return Row(
        children: [
          Flexible(
            child: RecorderAudioTile(
              model: item.toSpeakingEventModel(),
              url: item.recordingUrl,
              onPlaybackStart: onPlaybackStart,
              onPlaybackEnd: onPlaybackEnd,
            ),
          ),
          if (trailing != null) trailing!,
        ],
      );
    }

    final theme = Theme.of(context);
    final timeLabel = item.startTime.toDateTimeWithSec.toLocal().formatTimeWithSeconds;
    final statusText = item.audioLoadFailed ? 'Audio unavailable' : 'Loading audio…';

    return Row(
      children: [
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: AppTheme.primaryColor.withValues(alpha: 0.12),
              border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                if (!item.audioLoadFailed)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(Icons.error_outline, size: 18, color: theme.colorScheme.error),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${item.userName} $timeLabel',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        statusText,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: item.audioLoadFailed ? theme.colorScheme.error : Colors.black54,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
