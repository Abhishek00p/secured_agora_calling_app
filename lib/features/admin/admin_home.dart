import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:secured_calling/core/extensions/app_color_extension.dart';
import 'package:secured_calling/core/extensions/app_string_extension.dart';
import 'package:secured_calling/core/extensions/date_time_extension.dart';
import 'package:secured_calling/core/models/app_user_model.dart';
import 'package:secured_calling/core/utils/responsive_utils.dart';
import 'package:secured_calling/features/admin/member_form.dart';
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
  Widget _buildDetailRow({required IconData icon, required String label, required String value, required ThemeData theme}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text("$label: ", style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500, color: Colors.grey[700])),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w400), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  bool Function(AppUser) _applyFilters(DateTime now) {
    return (AppUser m) {
      // Search filter
      final matchQuery = m.name.toLowerCase().contains(_searchQuery) || m.email.toLowerCase().contains(_searchQuery);

      if (!matchQuery) return false;

      // Expiry filter
      final daysLeft = m.planExpiryDate?.toDateTime.difference(now).inDays ?? 0;

      if (_filter == 'Close') {
        return daysLeft <= 60;
      }

      if (_filter == 'Long') {
        return daysLeft > 60;
      }

      // All
      return true;
    };
  }

  Widget _buildFilterChip(String value) {
    final bool selected = _filter == value;

    return FilterChip(
      label: Text(
        value == 'Close'
            ? 'Close Expiry'
            : value == 'Long'
            ? 'Long Expiry'
            : 'All',
      ),
      selected: selected,
      onSelected: (_) {
        setState(() {
          _filter = value;
        });
      },
      selectedColor: Theme.of(context).colorScheme.primary,
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(color: selected ? Colors.white : Colors.black, fontSize: 12, fontWeight: FontWeight.w500),
      side: BorderSide(color: selected ? Theme.of(context).colorScheme.primary : Colors.grey.shade400),
      backgroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    );
  }

  Widget _buildMembersGrid(BuildContext context) {
    final useGrid = context.layoutType != AppLayoutType.mobile;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final now = DateTime.now();
        final members =
            snapshot.data!.docs
                .map((doc) => AppUser.fromJson(doc.data() as Map<String, dynamic>))
                .where((e) => e.isMember)
                .where(_applyFilters(now))
                .toList();

        if (members.isEmpty) {
          return SizedBox(height: 300, child: Center(child: Text("No members found")));
        }

        if (!useGrid) {
          return ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: members.length,
            itemBuilder: (context, i) => _buildMemberCard(context, Theme.of(context), members[i], now),
          );
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: members.length,
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 320,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.95,
          ),
          itemBuilder: (context, i) => _buildMemberCardCollapsed(context, Theme.of(context), members[i], now),
        );
      },
    );
  }

  Widget _buildMemberCardCollapsed(BuildContext context, ThemeData theme, AppUser member, DateTime now) {
    final isExpiringSoon = (member.planExpiryDate?.toDateTime.difference(now).inDays ?? 0) <= 60;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isExpiringSoon ? Colors.red.shade50 : theme.cardColor,
      child: Padding(
        padding: EdgeInsets.all(responsivePadding(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              member.name.sentenceCase,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: isExpiringSoon ? Colors.red : null),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(member.email, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.lock_clock, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text("Expires: ${member.planExpiryDate?.toDateTime.formatDate}", style: theme.textTheme.bodySmall),
              ],
            ),
            const Spacer(),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: () => _openMemberDetails(context, member), child: const Text("View details")),
            ),
          ],
        ),
      ),
    );
  }

  void _openMemberDetails(BuildContext context, AppUser member) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder:
          (_) => UserCredentialsBottomSheet(targetEmail: member.email, targetName: member.name, isMember: true, userId: member.userId.toString()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final padding = responsivePadding(context);

    return Scaffold(
      backgroundColor: Colors.white.withAlpha(250),
      appBar: AppBar(title: const Text("All Members")),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const PersistentCallBar(),

            // 🔹 SEARCH + FILTER (CENTERED)
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Padding(
                  padding: EdgeInsets.all(padding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 50,
                        child: TextField(
                          onChanged: (value) {
                            setState(() => _searchQuery = value.toLowerCase());
                          },
                          decoration: InputDecoration(
                            hintText: 'Search by name or email...',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(spacing: 8, children: [_buildFilterChip("All"), _buildFilterChip("Close"), _buildFilterChip("Long")]),
                    ],
                  ),
                ),
              ),
            ),

            // 🔥 GRID — FULL WIDTH
            Padding(padding: EdgeInsets.symmetric(horizontal: padding), child: _buildMembersGrid(context)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const MemberForm()));
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildMemberCard(BuildContext context, ThemeData theme, AppUser member, DateTime now, {bool isDesktop = false}) {
    final isExpiringSoon = (member.planExpiryDate?.toDateTime.difference(now).inDays ?? 0) <= 60;
    final padding = responsivePadding(context);

    return Card(
      margin: EdgeInsets.symmetric(horizontal: padding, vertical: padding / 2),
      shape: RoundedRectangleBorder(side: BorderSide(color: Colors.black.withAppOpacity(0.2)), borderRadius: BorderRadius.circular(16)),
      color: isExpiringSoon ? Colors.red.shade50 : theme.cardColor,
      elevation: 2,
      shadowColor: Colors.black.withAppOpacity(0.08),
      child: ExpansionTile(
        maintainState: !isDesktop,
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
                    style: theme.textTheme.bodySmall?.copyWith(color: isExpiringSoon ? Colors.red.shade700 : Colors.grey[700]),
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
                      FirebaseFirestore.instance.collection('users').doc(member.userId.toString()).update({'isActive': val});
                    },
                    activeColor: theme.colorScheme.primary,
                  ),
                  Text(
                    member.isActive ? "Active" : "Inactive",
                    style: TextStyle(fontWeight: FontWeight.w600, color: member.isActive ? Colors.green : Colors.red),
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
                  Navigator.push(context, MaterialPageRoute(builder: (_) => MemberForm(member: member)));
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
