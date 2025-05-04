import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:secured_calling/core/models/member_model.dart';

void showReminderDialog(BuildContext context, Member member) {
  String reminderType = 'renewal';
  final titleController = TextEditingController();
  final descController = TextEditingController();

  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Send Reminder'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile(
              value: 'renewal',
              groupValue: reminderType,
              title: const Text('Renewal Reminder'),
              onChanged: (val) {
                reminderType = val!;
                (context as Element).markNeedsBuild();
              },
            ),
            RadioListTile(
              value: 'custom',
              groupValue: reminderType,
              title: const Text('Custom Reminder'),
              onChanged: (val) {
                reminderType = val!;
                (context as Element).markNeedsBuild();
              },
            ),
            if (reminderType == 'custom') ...[
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              TextField(
                controller: descController,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              FirebaseFirestore.instance.collection('reminders').add({
                'memberId': member.id,
                'title':
                    reminderType == 'renewal'
                        ? 'Subscription Renewal'
                        : titleController.text,
                'description':
                    reminderType == 'renewal'
                        ? 'Your subscription is due for renewal.'
                        : descController.text,
                'timestamp': Timestamp.now(),
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text("Reminder sent!")));
            },
            child: const Text('Send'),
          ),
        ],
      );
    },
  );
}
