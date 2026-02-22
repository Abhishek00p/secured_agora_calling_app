
import 'package:flutter/material.dart';
import 'package:secured_calling/core/services/app_local_storage.dart';
import 'package:secured_calling/core/services/permission_service.dart';
import 'package:secured_calling/core/theme/app_theme.dart';
import 'package:secured_calling/core/utils/responsive_utils.dart';
import 'package:secured_calling/features/home/views/meeting_action_card.dart';
import 'package:secured_calling/features/home/views/meeting_util_service.dart';

class MembarTabViewWidget extends StatelessWidget {
  MembarTabViewWidget({super.key});
  final bool isMember = AppLocalStorage.getUserDetails().isMember;
  @override
  Widget build(BuildContext context) {
    if (!isMember) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.workspace_premium, size: 72, color: AppTheme.secondaryColor),
              const SizedBox(height: 24),
              Text('Premium Features', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Text(
                'Upgrade to a premium account to host your own meetings with extended features.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  // Upgrade membership logic would go here
                  // For demo, we'll just set the user as a member
                  // _simulateUpgrade();
                },
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12)),
                child: const Text('Upgrade Now'),
              ),
            ],
          ),
        ),
      );
    }

    final padding = responsivePadding(context);
    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // New meeting action card
          ActionCard(
            title: 'Create Meeting',
            icon: Icons.videocam,
            description: 'Set up a new instant or scheduled meeting',
            buttonText: 'Create Meeting',
            onPressed: () async {
              final permissionStatus = await PermissionService.requestPermission(context: context, type: AppPermissionType.microphone);
              // await PermissionService.requestPermission(
              //   context: context,
              //   type: AppPermissionType.camera,
              // );
              if (permissionStatus) {
                MeetingUtil.createNewMeeting(context: context);
              }
            },
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
