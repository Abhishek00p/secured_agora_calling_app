import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:secured_calling/core/utils/responsive_utils.dart';

class MemberRemindersPage extends StatelessWidget {
  final String memberId;

  const MemberRemindersPage({super.key, required this.memberId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Your Reminders")),
      body: StreamBuilder(
        stream:
            FirebaseFirestore.instance
                .collection('reminders')
                .where('memberId', isEqualTo: memberId)
                .orderBy('timestamp', descending: true)
                .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const CircularProgressIndicator();

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text('No reminders yet.'));
          }

          final padding = responsivePadding(context);

          return ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: padding),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data();
              return Card(
                margin: EdgeInsets.symmetric(horizontal: padding / 2, vertical: padding / 2),
                child: ListTile(
                  title: Text(data['title']),
                  subtitle: Text(data['description']),
                  trailing: Text(
                    DateFormat.yMMMd().format((data['timestamp'] as Timestamp).toDate()),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
