import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:secured_calling/app_tost_util.dart';
import 'package:secured_calling/core/extensions/app_int_extension.dart';
import 'package:secured_calling/core/routes/app_router.dart';
import 'package:secured_calling/core/services/app_firebase_service.dart';

class MeetingDialogController extends GetxController {
  final titleController = TextEditingController();
  final passwordController = TextEditingController();

  final durations = List.generate(14, (i) => (i + 1) * 30); // in minutes
  final selectedDuration = 30.obs;
  final isScheduled = false.obs;
  final selectedDate = Rxn<DateTime>();
  final selectedTime = Rxn<TimeOfDay>();
  @override
  void onClose() {
    titleController.dispose();
    passwordController.dispose();
    super.onClose();
  }
}

class MeetingUtil {
  static final AppFirebaseService firebaseService = AppFirebaseService.instance;

  static Future<void> createNewMeeting({
    required BuildContext context,
    required bool instant,
  }) async {
    final now = DateTime.now();
    final meetingName = 'Meeting ${now.hour}:${now.minute}';

    final result = await showMeetCreateDialog();

    if (result == null) return;

    try {
      final docRef = await firebaseService.createMeeting(
        hostId: firebaseService.currentUser!.uid,
        meetingName: result['title'],
        scheduledStartTime: now,
        requiresApproval: true,
        channelName: 'testing',
        password:
            result['password']?.isEmpty ?? true ? null : result['password'],
        duration: result['duration'] ?? 60,
      );

      final doc = await docRef.get();
      final meetingData = doc.data() as Map<String, dynamic>;

      if (instant) {
        Navigator.pushNamed(
          context,
          AppRouter.meetingRoomRoute,
          arguments: {
            'channelName': meetingData['channelName'] ?? 'default_channel',
            'isHost': true,
            'meetingId': doc.id,
          },
        );
      } else {
        AppToastUtil.showErrorToast(
          context,
          'Meeting "$meetingName" scheduled successfully',
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error creating meeting: $e')));
    }
  }

  static Future<void> startScheduledMeeting({
    required BuildContext context,
    required String meetingId,
    required String channelName,
  }) async {
    try {
      await firebaseService.startMeeting(meetingId);
      Navigator.pushNamed(
        context,
        AppRouter.meetingRoomRoute,
        arguments: {'channelName': channelName, 'isHost': true},
      );
    } catch (e) {
      AppToastUtil.showErrorToast(context, 'Error starting meeting: $e');
    }
  }

  static Future<Map<String, dynamic>?> showMeetCreateDialog() async {
    final controller = Get.put(MeetingDialogController());

    final result = await showDialog<Map<String, dynamic>>(
      context: Get.context!,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: Theme.of(context).dialogTheme.backgroundColor,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: SingleChildScrollView(
              child: Obx(
                () => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Create Meeting',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: controller.titleController,
                      decoration: const InputDecoration(
                        labelText: 'Meeting Title',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: controller.passwordController,
                      decoration: const InputDecoration(
                        labelText: 'Meeting Password (optional)',
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      value: controller.selectedDuration.value,
                      items:
                          controller.durations
                              .map(
                                (mins) => DropdownMenuItem(
                                  value: mins,
                                  child: Text(
                                    '${mins ~/ 60}h ${mins % 60 != 0 ? '${mins % 60}m' : ''}',
                                  ),
                                ),
                              )
                              .toList(),
                      onChanged: (val) {
                        if (val != null)
                          controller.selectedDuration.value = val;
                      },
                      decoration: const InputDecoration(labelText: 'Duration'),
                    ),
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      title: const Text('Schedule Meeting'),
                      value: controller.isScheduled.value,
                      onChanged:
                          (val) => controller.isScheduled.value = val ?? false,
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                    if (controller.isScheduled.value) ...[
                      const SizedBox(height: 10),
                      ListTile(
                        title: const Text('Select Date'),
                        subtitle: Text(
                          controller.selectedDate.value != null
                              ? controller.selectedDate.value!
                                  .toLocal()
                                  .toString()
                                  .split(' ')[0]
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
                      const SizedBox(height: 8),
                      ListTile(
                        title: const Text('Select Time'),
                        subtitle: Text(
                          controller.selectedTime.value != null
                              ? controller.selectedTime.value!.format(context)
                              : 'No time selected',
                        ),
                        trailing: const Icon(Icons.access_time),
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.now(),
                          );
                          if (picked != null) {
                            controller.selectedTime.value = picked;
                          }
                        },
                      ),
                    ],
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.pop(context); // Cancel
                            },
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              final title =
                                  controller.titleController.text.trim();
                              final password =
                                  controller.passwordController.text.trim();

                              if (title.isEmpty) {
                                Get.snackbar(
                                  'Error',
                                  'Meeting title is required',
                                );
                                return;
                              }

                              if (controller.isScheduled.value) {
                                if (controller.selectedDate.value == null ||
                                    controller.selectedTime.value == null) {
                                  Get.snackbar(
                                    'Error',
                                    'Please select date and time for scheduling',
                                  );
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
                              });
                            },
                            child: const Text('Create'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    Get.delete<MeetingDialogController>();
    return result;
  }
}
