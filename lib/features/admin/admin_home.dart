import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:secured_calling/core/extensions/app_color_extension.dart';
import 'package:secured_calling/core/extensions/app_int_extension.dart';
import 'package:secured_calling/core/extensions/app_string_extension.dart';
import 'package:secured_calling/core/models/member_model.dart';
import 'package:secured_calling/features/admin/member_form.dart';
import 'package:secured_calling/utils/reminder_dialog.dart';
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
    return Scaffold(
      backgroundColor: Colors.white.withAlpha(250),
      appBar: AppBar(title: const Text("All Members")),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
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
                  FirebaseFirestore.instance.collection('members').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                var members =
                    snapshot.data!.docs
                        .map(
                          (doc) => Member.fromMap(
                            doc.id,
                            doc.data() as Map<String, dynamic>,
                          ),
                        )
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
                            m.expiryDate.difference(now).inDays <= 60;
                      } else if (_filter == 'Long') {
                        return matchQuery &&
                            m.expiryDate.difference(now).inDays > 60;
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
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: members.length,
                  itemBuilder: (context, index) {
                    final member = members[index];
                    final isExpiringSoon =
                        member.expiryDate.difference(now).inDays <= 60;
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        side: BorderSide(
                          color: Colors.black.withAppOpacity(0.2),
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      color:
                          isExpiringSoon ? Colors.red.shade50 : theme.cardColor,
                      elevation: 2,
                      shadowColor: Colors.black.withAppOpacity(0.08),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        childrenPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        collapsedShape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),

                        // Title Section
                        title: Text(
                          member.name.sentenceCase,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color:
                                isExpiringSoon
                                    ? Colors.red.shade700
                                    : theme.colorScheme.onSurface,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                member.email,
                                style: theme.textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.lock_clock,
                                    size: 14,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    "Expires: ${DateFormat.yMMMd().format(member.expiryDate)}",
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color:
                                          isExpiringSoon
                                              ? Colors.red.shade700
                                              : Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Expanded Details
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Left Column
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildDetailRow(
                                      icon: Icons.person,
                                      label: "Name",
                                      value: member.name,
                                      theme: theme,
                                    ),
                                    _buildDetailRow(
                                      icon: Icons.email,
                                      label: "Email",
                                      value: member.email,
                                      theme: theme,
                                    ),
                                    _buildDetailRow(
                                      icon: Icons.calendar_today,
                                      label: "Purchase",
                                      value: DateFormat.yMMMd().format(
                                        member.purchaseDate,
                                      ),
                                      theme: theme,
                                    ),
                                    _buildDetailRow(
                                      icon: Icons.lock_clock,
                                      label: "Expires",
                                      value: DateFormat.yMMMd().format(
                                        member.expiryDate,
                                      ),
                                      theme: theme,
                                    ),
                                    _buildDetailRow(
                                      icon: Icons.people,
                                      label: "Users",
                                      value: member.totalUsers.toString(),
                                      theme: theme,
                                    ),
                                  ],
                                ),
                              ),

                              // Right Column (Status)
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
                                    activeColor: theme.colorScheme.primary,
                                  ),
                                  Text(
                                    member.isActive ? "Active" : "Inactive",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color:
                                          member.isActive
                                              ? Colors.green
                                              : Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),
                          const Divider(),
                          const SizedBox(height: 8),

                          // Action Buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              OutlinedButton.icon(
                                onPressed:
                                    () => showReminderDialog(context, member),
                                icon: const Icon(Icons.notifications, size: 18),
                                label: const Text(
                                  "Reminder",
                                  style: TextStyle(fontSize: 13),
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (_) => MemberForm(member: member),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.edit, size: 18),
                                label: const Text(
                                  "Edit",
                                  style: TextStyle(fontSize: 13),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.colorScheme.primary,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.visibility,
                                  color: Colors.blue[600],
                                  size: 22,
                                ),
                                onPressed: () {
                                  UserCredentialsBottomSheet.show(
                                    context,
                                    targetEmail: member.email,
                                    targetName: member.name,
                                    isMember: true,
                                  );
                                },
                                tooltip: 'View Credentials',
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                    // return Card(
                    //   margin: const EdgeInsets.symmetric(
                    //     horizontal: 16,
                    //     vertical: 8,
                    //   ),
                    //   shape: RoundedRectangleBorder(
                    //     borderRadius: BorderRadius.circular(16),
                    //   ),
                    //   color:
                    //       isExpiringSoon ? Colors.red.shade50 : theme.cardColor,
                    //   elevation: 1,
                    //   child: ExpansionTile(
                    //     tilePadding: const EdgeInsets.symmetric(
                    //       horizontal: 16,
                    //       vertical: 10,
                    //     ),
                    //     childrenPadding: const EdgeInsets.symmetric(
                    //       horizontal: 16,
                    //       vertical: 8,
                    //     ),
                    //     title: Text(
                    //       member.name.sentenceCase,
                    //       style: theme.textTheme.titleMedium?.copyWith(
                    //         fontWeight: FontWeight.bold,
                    //         color: isExpiringSoon ? Colors.red : null,
                    //       ),
                    //     ),
                    //     subtitle: Column(
                    //       crossAxisAlignment: CrossAxisAlignment.start,
                    //       children: [
                    //         Text(
                    //           member.email,
                    //           style: theme.textTheme.bodyMedium,
                    //         ),
                    //         const SizedBox(height: 4),
                    //         Text(
                    //           "Expires: ${DateFormat.yMMMd().format(member.expiryDate)}",
                    //           style: theme.textTheme.bodySmall?.copyWith(
                    //             color: isExpiringSoon ? Colors.red : null,
                    //           ),
                    //         ),
                    //       ],
                    //     ),
                    //     children: [
                    //       Row(
                    //         crossAxisAlignment: CrossAxisAlignment.start,
                    //         children: [
                    //           Expanded(
                    //             child: Column(
                    //               crossAxisAlignment: CrossAxisAlignment.start,
                    //               children: [
                    //                 Text(
                    //                   "Name: ${member.name}",
                    //                   style: theme.textTheme.bodyLarge,
                    //                 ),
                    //                 4.h,
                    //                 Text(
                    //                   "Email: ${member.email}",
                    //                   style: theme.textTheme.bodyLarge,
                    //                 ),
                    //                 const SizedBox(height: 8),
                    //                 Row(
                    //                   children: [
                    //                     const Icon(
                    //                       Icons.calendar_today,
                    //                       size: 16,
                    //                       color: Colors.grey,
                    //                     ),
                    //                     const SizedBox(width: 6),
                    //                     Text(
                    //                       "Purchase: ${DateFormat.yMMMd().format(member.purchaseDate)}",
                    //                       style: theme.textTheme.bodyMedium,
                    //                     ),
                    //                   ],
                    //                 ),
                    //                 const SizedBox(height: 6),
                    //                 Row(
                    //                   children: [
                    //                     const Icon(
                    //                       Icons.lock_clock,
                    //                       size: 16,
                    //                       color: Colors.grey,
                    //                     ),
                    //                     const SizedBox(width: 6),
                    //                     Text(
                    //                       "Expires: ${DateFormat.yMMMd().format(member.expiryDate)}",
                    //                       style: theme.textTheme.bodyMedium,
                    //                     ),
                    //                   ],
                    //                 ),
                    //                 const SizedBox(height: 6),
                    //                 Row(
                    //                   children: [
                    //                     const Icon(
                    //                       Icons.people,
                    //                       size: 16,
                    //                       color: Colors.grey,
                    //                     ),
                    //                     const SizedBox(width: 6),
                    //                     Text(
                    //                       "Users: ${member.totalUsers}",
                    //                       style: theme.textTheme.bodyMedium,
                    //                     ),
                    //                   ],
                    //                 ),
                    //               ],
                    //             ),
                    //           ),
                    //           Column(
                    //             children: [
                    //               Switch(
                    //                 value: member.isActive,
                    //                 onChanged: (val) {
                    //                   FirebaseFirestore.instance
                    //                       .collection('members')
                    //                       .doc(member.id)
                    //                       .update({'isActive': val});
                    //                 },
                    //                 activeColor: theme.colorScheme.primary,
                    //               ),
                    //               Text(
                    //                 member.isActive ? "Active" : "Inactive",
                    //                 style: TextStyle(
                    //                   fontWeight: FontWeight.w500,
                    //                   color:
                    //                       member.isActive
                    //                           ? Colors.green
                    //                           : Colors.red,
                    //                 ),
                    //               ),
                    //               const SizedBox(height: 8),
                    //             ],
                    //           ),
                    //         ],
                    //       ),
                    //       12.h,
                    //       Row(
                    //         mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    //         children: [
                    //           SizedBox(
                    //             width: MediaQuery.sizeOf(context).width * 0.3,
                    //             child: OutlinedButton.icon(
                    //               onPressed:
                    //                   () => showReminderDialog(context, member),
                    //               icon: const Icon(Icons.notifications),
                    //               label: const Text(
                    //                 "Reminder",
                    //                 style: TextStyle(fontSize: 12),
                    //               ),
                    //             ),
                    //           ),
                    //           ElevatedButton.icon(
                    //             onPressed: () {
                    //               Navigator.push(
                    //                 context,
                    //                 MaterialPageRoute(
                    //                   builder:
                    //                       (_) => MemberForm(member: member),
                    //                 ),
                    //               );
                    //             },
                    //             icon: const Icon(Icons.edit),
                    //             label: const Text(
                    //               "Edit",
                    //               style: TextStyle(fontSize: 12),
                    //             ),
                    //             style: ElevatedButton.styleFrom(
                    //               backgroundColor: theme.colorScheme.primary,
                    //             ),
                    //           ),
                    //           IconButton(
                    //             icon: Icon(
                    //               Icons.visibility,
                    //               color: Colors.blue[600],
                    //               size: 20,
                    //             ),
                    //             onPressed: () {
                    //               UserCredentialsBottomSheet.show(
                    //                 context,
                    //                 targetEmail: member.email,
                    //                 targetName: member.name,
                    //                 isMember: true,
                    //               );
                    //             },
                    //             tooltip: 'View Credentials',
                    //           ),
                    //         ],
                    //       ),
                    //     ],
                    //   ),
                    // );
                  },
                );
              },
            ),
          ],
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
}
