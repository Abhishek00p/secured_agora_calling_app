import 'package:flutter/material.dart';
import 'package:secured_calling/models/participant_detail.dart';
import 'package:secured_calling/utils/app_helpers.dart';

class ParticipantListItem extends StatelessWidget {
  final ParticipantDetail participant;
  final int index;

  const ParticipantListItem({super.key, required this.participant, required this.index});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 22.0,
              backgroundColor: getAvatarColor(index),
              child: Text(
                getInitial(participant.username),
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 16.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    participant.username,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4.0),
                  Text('User ID: ${participant.userId}', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 8.0),
                  Text('Joined: ${formatDateTime(participant.joinTime)}', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 4.0),
                  participant.leaveTime != null
                      ? Text(
                        'Left: ${formatDateTime(participant.leaveTime!)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      )
                      : Text(
                        'Still in meeting',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic, color: Colors.green),
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
