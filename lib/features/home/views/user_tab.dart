import 'package:flutter/material.dart';
import 'package:secured_calling/features/home/views/meeting_action_card.dart';
import 'package:secured_calling/features/meeting/views/join_meeting_dialog.dart';

class UserTab extends StatelessWidget {
  const UserTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Join existing meeting card
          ActionCard(
            title: 'Join a Meeting',
            icon: Icons.group_add,
            description: 'Enter a meeting ID to join an existing call',
            buttonText: 'Join',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const JoinMeetingDialog(),
              );
            },
          ),

          const SizedBox(height: 24),

          // Text(
          //   'Recent Meetings',
          //   style: Theme.of(
          //     context,
          //   ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          // ),
          // const SizedBox(height: 16),

          // Placeholder for call history
          // Expanded(
          //   child: Center(
          //     child: Column(
          //       mainAxisAlignment: MainAxisAlignment.center,
          //       children: [
          //         const Icon(Icons.history, size: 64, color: Colors.grey),
          //         const SizedBox(height: 16),
          //         Text(
          //           'No recent meetings',
          //           style: Theme.of(context).textTheme.titleMedium,
          //         ),
          //         const SizedBox(height: 8),
          //         Text(
          //           'Meetings you join will appear here',
          //           textAlign: TextAlign.center,
          //           style: Theme.of(context).textTheme.bodyMedium,
          //         ),
          //       ],
          //     ),
          //   ),
          // ),

          
        ],
      ),
    );
  }
}
