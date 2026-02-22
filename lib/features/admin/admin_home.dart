import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:secured_calling/core/extensions/app_color_extension.dart';
import 'package:secured_calling/core/extensions/app_int_extension.dart';
import 'package:secured_calling/core/extensions/app_string_extension.dart';
import 'package:secured_calling/core/extensions/date_time_extension.dart';
import 'package:secured_calling/core/models/app_user_model.dart';
import 'package:secured_calling/core/models/member_model.dart';
import 'package:secured_calling/core/utils/responsive_utils.dart';
import 'package:secured_calling/features/admin/member_form.dart';
import 'package:secured_calling/utils/reminder_dialog.dart';
import 'package:secured_calling/widgets/persistent_call_bar.dart';
import 'package:secured_calling/widgets/user_credentials_dialog.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  String _searchQuery = '';
  String _filter = 'All';
  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required ThemeData theme,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            "$label: ",
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w400,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final padding = responsivePadding(context);
    final maxWidth = contentMaxWidth(context) == double.infinity ? 700.0 : contentMaxWidth(context) * 1.3;

    return Scaffold(
      backgroundColor: Colors.white.withAlpha(250),
      appBar: AppBar(title: const Text("All Members")),
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: context.layoutType == AppLayoutType.mobile ? double.infinity : maxWidth),
            child: Column(
          children: [
            const PersistentCallBar(),
            Padding(
              padding: EdgeInsets.all(padding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 50,
                    width: Get.width,
                    child: TextField(
                      onChanged: (value) {
                        setState(() => _searchQuery = value.toLowerCase());
                      },
                      decoration: InputDecoration(
                        hintText: 'Search by name or email...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: theme.colorScheme.surface,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      FilterChip(
                        label: const Text("All"),
                        labelStyle: TextStyle(
                          color: _filter == 'All' ? Colors.white : Colors.black,
                          fontSize: 12,
                        ),
                        selected: _filter == 'All',
                        onSelected: (_) => setState(() => _filter = 'All'),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text("Close Expiry"),
                        labelStyle: TextStyle(
                          color:
                              _filter == 'Close' ? Colors.white : Colors.black,
                          fontSize: 12,
                        ),
                        selected: _filter == 'Close',
                        onSelected: (_) => setState(() => _filter = 'Close'),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text("Long Expiry"),
                        labelStyle: TextStyle(
                          color:
                              _filter == 'Long' ? Colors.white : Colors.black,
                          fontSize: 12,
                        ),
                        selected: _filter == 'Long',
                        onSelected: (_) => setState(() => _filter = 'Long'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                var members =
                    snapshot.data!.docs
                        .map(
                          (doc) => AppUser.fromJson(
                            doc.data() as Map<String, dynamic>,
                          ),
                        )
                        .toList()
                        .where((e) => e.isMember)
                        .toList();

                final now = DateTime.now();
                print(
                  "Number of members found before filtering: ${members.length}",
                );

                members =
                    members.where((m) {
                      final matchQuery =
                          m.name.toLowerCase().contains(_searchQuery) ||
                          m.email.toLowerCase().contains(_searchQuery);

                      if (_filter == 'Close') {
                        return matchQuery &&
                            (m.planExpiryDate?.toDateTime
                                        .difference(now)
                                        .inDays ??
                                    0) <=
                                60;
                      } else if (_filter == 'Long') {
                        return matchQuery &&
                            (m.planExpiryDate?.toDateTime
                                        .difference(now)
                                        .inDays ??
                                    0) >
                                60;
                      } else {
                        return matchQuery;
                      }
                    }).toList();
                if (members.isEmpty) {
                  return SizedBox(
                    height: Get.height - 300,
                    child: Center(child: Text("No members found.")),
                  );
                }
                print("Number of members found: ${members.length}");
                final useGrid = context.layoutType != AppLayoutType.mobile;
                if (useGrid) {
                  return Padding(
                    padding: EdgeInsets.only(left: padding, right: padding, bottom: 80),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.85,
                        crossAxisSpacing: padding,
                        mainAxisSpacing: padding / 2,
                      ),
                      itemCount: members.length,
                      itemBuilder: (context, index) => _buildMemberCard(context, theme, members[index], now),
                    ),
                  );
                }
                return ListView.builder(
                  padding: EdgeInsets.only(left: padding, right: padding, bottom: 80),
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: members.length,
                  itemBuilder: (context, index) {
                    final member = members[index];
                    final isExpiringSoon =
                        (member.planExpiryDate?.toDateTime
                                .difference(now)
                                .inDays ??
                            0) <=
                        60;
                    return _buildMemberCard(context, theme, member, now);
                  },
                );
              },
            ),
          ],
        ),
        ),
      ),
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

  Widget _buildMemberCard(BuildContext context, ThemeData theme, AppUser member, DateTime now) {
    final isExpiringSoon =
        (member.planExpiryDate?.toDateTime.difference(now).inDays ?? 0) <= 60;
    final padding = responsivePadding(context);

    return Card(
      margin: EdgeInsets.symmetric(horizontal: padding, vertical: padding / 2),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.black.withAppOpacity(0.2)),
        borderRadius: BorderRadius.circular(16),
      ),
      color: isExpiringSoon ? Colors.red.shade50 : theme.cardColor,
      elevation: 2,
      shadowColor: Colors.black.withAppOpacity(0.08),
      child: ExpansionTile(
        tilePadding: EdgeInsets.symmetric(horizontal: padding, vertical: 12),
        childrenPadding: EdgeInsets.symmetric(horizontal: padding, vertical: 12),
        collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          member.name.sentenceCase,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: isExpiringSoon ? Colors.red.shade700 : theme.colorScheme.onSurface,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(member.email, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.lock_clock, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    "Expires: ${member.planExpiryDate?.toDateTime.formatDate}",
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isExpiringSoon ? Colors.red.shade700 : Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow(icon: Icons.person, label: "Name", value: member.name, theme: theme),
                    _buildDetailRow(icon: Icons.numbers, label: "User Id", value: member.email, theme: theme),
                    _buildDetailRow(
                      icon: Icons.lock_clock,
                      label: "Expires",
                      value: member.planExpiryDate?.toDateTime.formatDate ?? '',
                      theme: theme,
                    ),
                    _buildDetailRow(icon: Icons.people, label: "Users", value: member.totalUsers.toString(), theme: theme),
                  ],
                ),
              ),
              Column(
                children: [
                  Switch(
                    value: member.isActive,
                    onChanged: (val) {
                      FirebaseFirestore.instance
                          .collection('users')
                          .doc(member.userId.toString())
                          .update({'isActive': val});
                    },
                    activeColor: theme.colorScheme.primary,
                  ),
                  Text(
                    member.isActive ? "Active" : "Inactive",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: member.isActive ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => MemberForm(member: member)),
                  );
                },
                icon: const Icon(Icons.edit, size: 18),
                label: const Text("Edit", style: TextStyle(fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  padding: EdgeInsets.symmetric(horizontal: padding, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  UserCredentialsBottomSheet.show(
                    context,
                    targetEmail: member.email,
                    targetName: member.name,
                    isMember: true,
                    userId: member.userId.toString(),
                  );
                },
                icon: const Icon(Icons.remove_red_eye, size: 18),
                label: const Text("view more", style: TextStyle(fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: padding / 2 * 1.2, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
