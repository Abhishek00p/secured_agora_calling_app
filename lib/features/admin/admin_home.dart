import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:secured_calling/core/extensions/app_int_extension.dart';
import 'package:secured_calling/core/models/member_model.dart';
import 'package:secured_calling/features/admin/all_user_member_list.dart';
import 'package:secured_calling/features/admin/member_form.dart';
import 'package:secured_calling/utils/reminder_dialog.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Admin Section")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('members').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final members =
              snapshot.data!.docs
                  .map(
                    (doc) => Member.fromMap(
                      doc.id,
                      doc.data() as Map<String, dynamic>,
                    ),
                  )
                  .toList();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: members.length,
            itemBuilder: (context, index) {
              final member = members[index];
              return InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AllUserMemberList(member: member),
                    ),
                  );
                },
                child: Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Info Section
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Name: ${member.name}",
                                    style: Theme.of(context).textTheme.bodyLarge,
                                  ),
                                  4.h,
                                  Text(
                                    "Email: ${member.email}",
                                    style: Theme.of(context).textTheme.bodyLarge,
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.calendar_today,
                                        size: 16,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        "Purchase: ${DateFormat.yMMMd().format(member.purchaseDate)}",
                                        style:
                                            Theme.of(
                                              context,
                                            ).textTheme.bodyMedium,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.lock_clock,
                                        size: 16,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        "Expires: ${DateFormat.yMMMd().format(member.expiryDate)}",
                                        style:
                                            Theme.of(
                                              context,
                                            ).textTheme.bodyMedium,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.people,
                                        size: 16,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        "Users: ${member.totalUsers}",
                                        style:
                                            Theme.of(
                                              context,
                                            ).textTheme.bodyMedium,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                
                            // Action Section
                            Column(
                              children: [
                                Switch(
                                  value: member.isActive,
                                  onChanged: (val) {
                                    FirebaseFirestore.instance
                                        .collection('members')
                                        .doc(member.id)
                                        .update({'isActive': val});
                                  },
                                  activeColor:
                                      Theme.of(context).colorScheme.primary,
                                ),
                                Text(
                                  member.isActive ? "Active" : "Inactive",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color:
                                        member.isActive
                                            ? Colors.green
                                            : Colors.red,
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],
                            ),
                          ],
                        ),
                        12.h,
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () {
                                showReminderDialog(context, member);
                              },
                              icon: const Icon(Icons.notifications),
                              label: const Text("Reminder"),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => MemberForm(member: member),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.edit),
                              label: const Text("Edit"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MemberForm()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
