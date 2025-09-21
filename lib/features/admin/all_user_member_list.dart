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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text("Member Details")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Member Info", style: theme.textTheme.titleLarge),
                    const SizedBox(height: 12),
                    _infoRow("Name", member.name, theme),
                    _infoRow("Email", member.email, theme),
                    _infoRow("Code", member.memberCode, theme),
                    _infoRow("Plan Days", member.planDays.toString(), theme),
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
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  );
                }
                final users = snapshot.data ?? [];
                if (users.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      "No users found.",
                      style: theme.textTheme.bodyMedium,
                    ),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Users under this Member (${users.length})",
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: users.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (context, index) {
                        final user = users[index];
                        return ListTile(
                          tileColor: Colors.white54,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16),
                          leading: CircleAvatar(
                            backgroundColor: theme.colorScheme.primary
                                .withOpacity(0.1),
                            child: Text(
                              user.name[0].capitalizeAll,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                          title: Text(
                            user.name,
                            style: theme.textTheme.bodyLarge,
                          ),
                          subtitle: Text(
                            user.email,
                            style: theme.textTheme.bodyMedium,
                          ),
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

  Widget _infoRow(String title, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              "$title:",
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(value, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
