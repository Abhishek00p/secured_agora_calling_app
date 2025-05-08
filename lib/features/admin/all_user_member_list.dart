import 'package:flutter/material.dart';
import 'package:secured_calling/core/extensions/app_string_extension.dart';
import 'package:secured_calling/core/models/app_user_model.dart';
import 'package:secured_calling/core/models/member_model.dart';
import 'package:secured_calling/core/services/app_firebase_service.dart';

class AllUserMemberList extends StatefulWidget {
  final Member member;
  const AllUserMemberList({super.key, required this.member});

  @override
  State<AllUserMemberList> createState() => _AllUserMemberListState();
}

class _AllUserMemberListState extends State<AllUserMemberList> {
  @override
  Widget build(BuildContext context) {
    final member = widget.member;

    return Scaffold(
      appBar: AppBar(title: const Text("Member Details")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Member Info",
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    _infoRow("Name", member.name),
                    _infoRow("Email", member.email),
                    _infoRow("Code", member.memberCode),
                    _infoRow("Plan Days", member.planDays.toString()),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            FutureBuilder<List<AppUser>>(
              future: AppFirebaseService.instance.getAllUserOfMember(
                member.memberCode,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final users = snapshot.data ?? [];
                if (users.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text("No users found."),
                  );
                }
                return Column(
                  children: [
                    Text(
                      "Users under this Member (${users.length})",
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: users.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final user = users[index];
                        return ListTile(
                          leading: CircleAvatar(child: Text(user.name[0].capitalizeAll)),
                          title: Text(user.name),
                          subtitle: Text(user.email),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              "$title:",
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(flex: 3, child: Text(value)),
        ],
      ),
    );
  }
}
