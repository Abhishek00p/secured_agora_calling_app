import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:secured_calling/core/extensions/app_int_extension.dart';
import 'package:secured_calling/core/services/app_local_storage.dart';
import 'package:secured_calling/utils/app_logger.dart';
import 'package:secured_calling/utils/app_tost_util.dart';
import 'package:secured_calling/core/routes/app_router.dart';
import 'package:secured_calling/core/services/app_firebase_service.dart';
import 'package:secured_calling/widgets/app_text_form_widget.dart';
import 'package:secured_calling/core/models/app_user_model.dart';

class MeetingDialogController extends GetxController {
  final titleController = TextEditingController();
  final passwordController = TextEditingController();

  final durations = [...List.generate(14, (i) => (i + 1) * 30)]; // in minutes
  final selectedDuration = 30.obs;
  final maxParticipants = RxInt(5); // default value
  final isScheduled = false.obs;
  final isApprovalRequired = true.obs;
  final selectedDate = Rxn<DateTime>();
  final selectedTime = Rxn<TimeOfDay>();

  // New variables for user selection
  final selectedUsers = <AppUser>[].obs;
  final showUserSelection = false.obs;
  final inviteType = 'all'.obs; // 'all' or 'selected'
  final availableUsers = <AppUser>[].obs;

 

  void toggleUserSelection() {
    showUserSelection.value = !showUserSelection.value;
    if (!showUserSelection.value) {
      selectedUsers.clear();
    }
  }

  void selectUser(AppUser user) {
    if (selectedUsers.contains(user)) {
      selectedUsers.remove(user);
    } else {
      selectedUsers.add(user);
    }
  }

  void setInviteType(String type) {
    inviteType.value = type;
    if (type == 'all') {
      selectedUsers.clear();
    }
  }

  @override
  void onClose() {
    titleController.dispose();
    passwordController.dispose();
    super.onClose();
  }
}

class MeetingUtil {
  static final AppFirebaseService firebaseService = AppFirebaseService.instance;

  static Future<void> createNewMeeting({required BuildContext context}) async {
    final now = DateTime.now();
    String meetingName = 'Meeting ${now.hour}:${now.minute}';

    final result = await showMeetCreateBottomSheet();

    if (result == null) return;

    try {
      meetingName = result['title'];

      final docRef = await firebaseService.createMeeting(
        hostId: AppLocalStorage.getUserDetails().userId,
        hostUserId: AppLocalStorage.getUserDetails().userId,
        hostName: AppLocalStorage.getUserDetails().name,
        meetingName: meetingName,
        scheduledStartTime: result['scheduledStart'] ?? now,

        requiresApproval: result['isApprovalRequired'] ?? false,
        maxParticipants: result['maxParticipants'] ?? 45,
        password: result['password']?.isEmpty ?? true ? null : result['password'],
        duration: result['duration'] ?? 60,
      );

      final doc = await docRef.get();
      final meetingData = doc.data() as Map<String, dynamic>;
      final instant = result['isInstant'] ?? false;
      AppLogger.print('Meeting created: ${doc.id}, Instant: $instant, \n Data: $meetingData');

      // Handle user invites if specified
      final inviteType = result['inviteType'] as String?;
      final selectedUserIds = result['selectedUsers'] as List<int>?;
      if (inviteType != null && selectedUserIds != null) {
        await _handleUserInvites(doc.id, inviteType, selectedUserIds);
      }

      if (instant) {
        Navigator.pushNamed(
          context,
          AppRouter.meetingRoomRoute,
          arguments: {'channelName': meetingData['channelName'] ?? 'default_channel', 'isHost': true, 'meetingId': doc.id},
        );
      } else {
        AppToastUtil.showInfoToast('Meeting "$meetingName" scheduled successfully');
      }
    } catch (e) {
      AppLogger.print('Error creating meeting: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error creating meeting: $e')));
    }
  }

  static Future<void> startScheduledMeeting({required BuildContext context, required String meetingId, required String channelName}) async {
    try {
      await firebaseService.startMeeting(meetingId);
      Navigator.pushNamed(context, AppRouter.meetingRoomRoute, arguments: {'channelName': channelName, 'isHost': true, 'meetingId': meetingId});
    } catch (e) {
      AppToastUtil.showErrorToast('Error starting meeting: $e');
    }
  }

  static Future<Map<String, dynamic>?> showMeetCreateBottomSheet() async {
    final controller = Get.put(MeetingDialogController());
    final member = await firebaseService.getMemberData(AppLocalStorage.getUserDetails().memberCode);
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: Get.context!,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      backgroundColor: Theme.of(Get.context!).dialogBackgroundColor,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 24),
          child: SingleChildScrollView(
            child: Obx(
              () => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Create Meeting', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 20),
                  AppTextFormField(controller: controller.titleController, labelText: 'Meeting Title', type: AppTextFormFieldType.text),
                  const SizedBox(height: 16),
                  AppTextFormField(
                    controller: controller.passwordController,
                    labelText: 'Meeting Password (optional)',
                    type: AppTextFormFieldType.password,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          menuMaxHeight: 300,

                          value: controller.selectedDuration.value,
                          items:
                              controller.durations
                                  .map(
                                    (mins) => DropdownMenuItem(
                                      alignment: AlignmentDirectional.center,
                                      value: mins,
                                      child: Text('${mins ~/ 60}h ${mins % 60 != 0 ? '${mins % 60}m' : ''}'),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              controller.selectedDuration.value = val;
                            }
                          },

                          decoration: const InputDecoration(labelText: 'Duration', enabledBorder: OutlineInputBorder()),
                        ),
                      ),
                      16.w,
                      if (!member.isEmpty) ...[
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            menuMaxHeight: 300,
                            value: controller.maxParticipants.value,
                            items:
                                List.generate((member.maximumParticipantsAllowed / 5).ceil(), (i) => (i + 1) * 5).map((val) {
                                  return DropdownMenuItem(alignment: AlignmentDirectional.center, value: val, child: Text('$val'));
                                }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                controller.maxParticipants.value = val;
                              }
                            },
                            decoration: const InputDecoration(labelText: 'Max Participants', enabledBorder: OutlineInputBorder()),
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: CheckboxListTile(
                          title: const Text('Schedule Meeting'),
                          value: controller.isScheduled.value,
                          onChanged: (val) => controller.isScheduled.value = val ?? false,
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      12.w,
                      Expanded(
                        child: CheckboxListTile(
                          title: const Text('Require Approval'),
                          value: controller.isApprovalRequired.value,
                          onChanged: (val) => controller.isApprovalRequired.value = val ?? false,
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),

                  // // User Selection Section (for members only)
                  // if (member.isNotEmpty) ...[
                  //   const SizedBox(height: 16),
                  //   Row(
                  //     children: [
                  //       Text(
                  //         'Meeting Invites',
                  //         style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  //           fontWeight: FontWeight.bold,
                  //         ),
                  //       ),
                  //       const Spacer(),
                  //       IconButton(
                  //         icon: Icon(
                  //           controller.showUserSelection.value
                  //             ? Icons.expand_less
                  //             : Icons.expand_more,
                  //         ),
                  //         onPressed: controller.toggleUserSelection,
                  //       ),
                  //     ],
                  //   ),
                  //   if (controller.showUserSelection.value) ...[
                  //     const SizedBox(height: 12),
                  //     Row(
                  //       children: [
                  //         Expanded(
                  //           child: RadioListTile<String>(
                  //             title: const Text('All Users', style: TextStyle(fontSize: 12)),
                  //             value: 'all',
                  //             groupValue: controller.inviteType.value,
                  //             onChanged: (value) => controller.setInviteType(value!),
                  //           ),
                  //         ),
                  //         Expanded(
                  //           child: RadioListTile<String>(
                  //             title: const Text('Selected Users', style: TextStyle(fontSize: 12)),
                  //             value: 'selected',
                  //             groupValue: controller.inviteType.value,
                  //             onChanged: (value) => controller.setInviteType(value!),
                  //           ),
                  //         ),
                  //       ],
                  //     ),
                  //     if (controller.inviteType.value == 'selected') ...[
                  //       const SizedBox(height: 8),
                  //       Container(
                  //         height: 120,
                  //         decoration: BoxDecoration(
                  //           border: Border.all(color: Colors.grey.shade300),
                  //           borderRadius: BorderRadius.circular(8),
                  //         ),
                  //         child: ListView.builder(
                  //           itemCount: controller.availableUsers.length,
                  //           itemBuilder: (context, index) {
                  //             final user = controller.availableUsers[index];
                  //             final isSelected = controller.selectedUsers.contains(user);
                  //             return CheckboxListTile(
                  //               title: Text(user.name, style: const TextStyle(fontSize: 12)),
                  //               subtitle: Text(user.email, style: const TextStyle(fontSize: 10)),
                  //               value: isSelected,
                  //               onChanged: (value) => controller.selectUser(user),
                  //             );
                  //           },
                  //         ),
                  //       ),
                  //     ],
                  //   ],
                  // ],
                  if (controller.isScheduled.value) ...[
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.grey, // Border color
                          width: 1.0, // Border width
                        ),
                        borderRadius: BorderRadius.circular(12), // Optional: Rounded corners
                      ),
                      child: ListTile(
                        title: const Text('Select Date'),

                        subtitle: Text(
                          controller.selectedDate.value != null
                              ? controller.selectedDate.value!.toLocal().toString().split(' ')[0]
                              : 'No date selected',
                        ),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () async {
                          final now = DateTime.now();
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: now,
                            firstDate: now,
                            lastDate: now.add(const Duration(days: 365)),
                          );
                          if (picked != null) {
                            controller.selectedDate.value = picked;
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.grey, // Border color
                          width: 1.0, // Border width
                        ),
                        borderRadius: BorderRadius.circular(12), // Optional: Rounded corners
                      ),
                      child: ListTile(
                        title: const Text('Select Time'),
                        subtitle: Text(controller.selectedTime.value != null ? controller.selectedTime.value!.format(context) : 'No time selected'),
                        trailing: const Icon(Icons.access_time),
                        onTap: () async {
                          final picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                          if (picked != null) {
                            controller.selectedTime.value = picked;
                          }
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            final title = controller.titleController.text.trim();
                            final password = controller.passwordController.text.trim();

                            if (title.isEmpty) {
                              AppToastUtil.showErrorToast('Meeting title is required', isTop: true);
                              return;
                            }

                            if (controller.isScheduled.value) {
                              if (controller.selectedDate.value == null || controller.selectedTime.value == null) {
                                AppToastUtil.showErrorToast('Please select date and time for scheduling', isTop: true);
                                return;
                              }
                            }

                            final scheduledStart =
                                controller.isScheduled.value
                                    ? DateTime(
                                      controller.selectedDate.value!.year,
                                      controller.selectedDate.value!.month,
                                      controller.selectedDate.value!.day,
                                      controller.selectedTime.value!.hour,
                                      controller.selectedTime.value!.minute,
                                    )
                                    : DateTime.now();

                            Navigator.pop(context, {
                              'title': title,
                              'password': password.isEmpty ? null : password,
                              'duration': controller.selectedDuration.value,
                              'scheduledStart': scheduledStart,
                              'isInstant': !controller.isScheduled.value,
                              'isApprovalRequired': controller.isApprovalRequired.value,
                              'maxParticipants': controller.maxParticipants.value,
                              'inviteType': controller.inviteType.value,
                              'selectedUsers': controller.selectedUsers.map((user) => user.userId).toList(),
                            });
                          },
                          child: const Text('Create'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        );
      },
    );

    Get.delete<MeetingDialogController>();
    return result;
  }

  static Future<void> _handleUserInvites(String meetingId, String inviteType, List<int> selectedUserIds) async {
    try {
      final currentUser = AppLocalStorage.getUserDetails();
      if (currentUser.isMember && currentUser.memberCode.isNotEmpty) {
        if (inviteType == 'all') {
          // Get all users for this member
          final allUsers = await firebaseService.getAllUserOfMember(currentUser.memberCode);
          final allUserIds = allUsers.map((user) => user.userId).toList();

          // Add all users to the meeting's invited users list
          await firebaseService.addInvitedUsers(meetingId, allUserIds);
        } else if (inviteType == 'selected' && selectedUserIds.isNotEmpty) {
          // Add only selected users to the meeting's invited users list
          await firebaseService.addInvitedUsers(meetingId, selectedUserIds);
        }
      }
    } catch (e) {
      AppLogger.print('Error handling user invites: $e');
    }
  }
}
