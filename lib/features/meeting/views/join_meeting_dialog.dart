import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:secured_calling/core/models/meeting_model.dart';
import 'package:secured_calling/core/models/app_user_model.dart';
import 'package:secured_calling/core/routes/app_router.dart';
import 'package:secured_calling/core/services/app_firebase_service.dart';
import 'package:secured_calling/core/services/app_local_storage.dart';
import 'package:secured_calling/core/services/join_request_service.dart';
import 'package:secured_calling/core/theme/app_theme.dart';
import 'package:secured_calling/widgets/app_text_form_widget.dart';

class JoinMeetingController extends GetxController {
  final meetingIdController = TextEditingController();
  final passwordController = TextEditingController();
  final formKey = GlobalKey<FormState>();
  final firebaseService = AppFirebaseService.instance;
  final joinRequestService = JoinRequestService();

  final isLoading = false.obs;
  final errorMessage = RxnString();
  final meetingFound = false.obs;
  final meetingId = RxnString();
  final meetingData = Rxn<MeetingModel>();
  final isWaitingForApproval = false.obs;

  // New variables for upcoming meetings and user selection
  final upcomingMeetings = <MeetingModel>[].obs;
  final selectedUsers = <AppUser>[].obs;
  final showUserSelection = false.obs;
  final inviteType = 'all'.obs; // 'all' or 'selected'
  final availableUsers = <AppUser>[].obs;

  @override
  void onInit() {
    super.onInit();
    clearState();
    // loadUpcomingMeetings();
    // loadAvailableUsers();
  }

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

  void cancelJoinRequest() {
    joinRequestService.stopListening();
    isWaitingForApproval.value = false;

    if (meetingId.value != null) {
      firebaseService.cancelJoinRequest(
        meetingId.value!,
        AppLocalStorage.getUserDetails().userId,
      );
    }
    clearState();
    Get.back();
  }

  void clearState() {
    isLoading.value = false;
    errorMessage.value = null;
    meetingFound.value = false;
    meetingData.value = null;
    meetingId.value = null;
    isWaitingForApproval.value = false;
    meetingIdController.clear();
    passwordController.clear();
    selectedUsers.clear();
    showUserSelection.value = false;
    inviteType.value = 'all';
    joinRequestService.stopListening();
  }

  void searchMeeting() async {
    if (!formKey.currentState!.validate()) return;

    isLoading.value = true;
    errorMessage.value = null;
    meetingFound.value = false;
    meetingData.value = null;
    meetingId.value = null;

    final meetingIdText = meetingIdController.text.trim();
    final passwordText = passwordController.text;

    try {
      final docSnapshot = await firebaseService.searchMeetingByMeetId(
        meetingIdText,
        meetingIdText,
      );
      if (docSnapshot == null || !docSnapshot.exists) {
        errorMessage.value = 'No active meeting found with this ID';
        isLoading.value = false;
        return;
      }

      final data = MeetingModel.fromJson(
        docSnapshot.data() as Map<String, dynamic>,
      );
      if (data.password?.isNotEmpty == true && data.password != passwordText) {
        errorMessage.value = 'Incorrect password for this meeting';
        isLoading.value = false;
        return;
      }

      meetingFound.value = true;
      meetingData.value = data;
      meetingId.value = docSnapshot.id;
      isLoading.value = false;

      if (!data.requiresApproval) joinMeeting();
    } catch (e) {
      errorMessage.value = 'Error searching for meeting: $e';
      isLoading.value = false;
    }
  }

  void requestToJoin() async {
    if (meetingId.value == null || meetingData.value == null) return;

    isLoading.value = true;

    // Use centralized join request service
    final success = await joinRequestService.requestToJoinMeeting(
      context: Get.context!,
      meeting: meetingData.value!,
      onStateChanged: (isWaiting, errorMessage) {
        isWaitingForApproval.value = isWaiting;
        this.errorMessage.value = errorMessage;
        isLoading.value = false;
      },
    );

    if (!success) {
      isLoading.value = false;
    }
  }

  void joinMeeting() {
    if (meetingData.value == null) return;
    Get.back();
    Get.toNamed(
      AppRouter.meetingRoomRoute,
      arguments: {
        'channelName': meetingData.value!.channelName,
        'isHost': false,
        'meetingId': meetingId.value,
      },
    );
  }

  @override
  void onClose() {
    joinRequestService.stopListening();
    clearState();
    super.onClose();
  }
}

class JoinMeetingDialog extends StatelessWidget {
  JoinMeetingDialog({super.key});

  final controller = Get.put(JoinMeetingController());
  @override
  Widget build(BuildContext context) {
    controller.clearState();
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16),
          child: Form(
            key: controller.formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDialogTitle(),
                  const SizedBox(height: 24),

                  // Upcoming Meetings Section (for members only)
                  // Obx(() {
                  //   final currentUser = AppLocalStorage.getUserDetails();
                  //   if (currentUser.isMember && controller.upcomingMeetings.isNotEmpty) {
                  //     return Column(
                  //       crossAxisAlignment: CrossAxisAlignment.start,
                  //       children: [
                  //         Text(
                  //           'Upcoming Meetings',
                  //           style: Get.textTheme.titleMedium?.copyWith(
                  //             fontWeight: FontWeight.bold,
                  //           ),
                  //         ),
                  //         const SizedBox(height: 12),
                  //         Container(
                  //           height: 120,
                  //           child: ListView.builder(
                  //             scrollDirection: Axis.horizontal,
                  //             itemCount: controller.upcomingMeetings.length,
                  //             itemBuilder: (context, index) {
                  //               final meeting = controller.upcomingMeetings[index];
                  //               return Container(
                  //                 width: 200,
                  //                 margin: const EdgeInsets.only(right: 12),
                  //                 child: Card(
                  //                   child: InkWell(
                  //                     onTap: () {
                  //                       controller.meetingIdController.text = meeting.meetId;
                  //                       controller.searchMeeting();
                  //                     },
                  //                     child: Padding(
                  //                       padding: const EdgeInsets.all(12),
                  //                       child: Column(
                  //                         crossAxisAlignment: CrossAxisAlignment.start,
                  //                         children: [
                  //                           Text(
                  //                             meeting.meetingName,
                  //                             style: const TextStyle(
                  //                               fontWeight: FontWeight.bold,
                  //                               fontSize: 12,
                  //                             ),
                  //                             maxLines: 1,
                  //                             overflow: TextOverflow.ellipsis,
                  //                           ),
                  //                           const SizedBox(height: 4),
                  //                           Text(
                  //                             'Host: ${meeting.hostName}',
                  //                             style: const TextStyle(fontSize: 10),
                  //                             maxLines: 1,
                  //                             overflow: TextOverflow.ellipsis,
                  //                           ),
                  //                           const SizedBox(height: 4),
                  //                           Text(
                  //                             meeting.scheduledStartTime.formatDateTime,
                  //                             style: const TextStyle(fontSize: 10),
                  //                           ),
                  //                         ],
                  //                       ),
                  //                     ),
                  //                   ),
                  //                 ),
                  //               );
                  //             },
                  //           ),
                  //         ),
                  //         const SizedBox(height: 16),
                  //       ],
                  //     );
                  //   }
                  //   return const SizedBox.shrink();
                  // }),

                  // User Selection Section (for members only)
                  // Obx(() {
                  //   final currentUser = AppLocalStorage.getUserDetails();
                  //   if (currentUser.isMember) {
                  //     return Column(
                  //       crossAxisAlignment: CrossAxisAlignment.start,
                  //       children: [
                  //         Row(
                  //           children: [
                  //             Text(
                  //               'Meeting Invites',
                  //               style: Get.textTheme.titleMedium?.copyWith(
                  //                 fontWeight: FontWeight.bold,
                  //               ),
                  //             ),
                  //             const Spacer(),
                  //             IconButton(
                  //               icon: Icon(
                  //                 controller.showUserSelection.value
                  //                   ? Icons.expand_less
                  //                   : Icons.expand_more,
                  //               ),
                  //               onPressed: controller.toggleUserSelection,
                  //             ),
                  //           ],
                  //         ),
                  //         if (controller.showUserSelection.value) ...[
                  //           const SizedBox(height: 12),
                  //           Row(
                  //             children: [
                  //               Expanded(
                  //                 child: RadioListTile<String>(
                  //                   title: const Text('All Users', style: TextStyle(fontSize: 12)),
                  //                   value: 'all',
                  //                   groupValue: controller.inviteType.value,
                  //                   onChanged: (value) => controller.setInviteType(value!),
                  //                 ),
                  //               ),
                  //               Expanded(
                  //                 child: RadioListTile<String>(
                  //                   title: const Text('Selected Users', style: TextStyle(fontSize: 12)),
                  //                   value: 'selected',
                  //                   groupValue: controller.inviteType.value,
                  //                   onChanged: (value) => controller.setInviteType(value!),
                  //                 ),
                  //               ),
                  //             ],
                  //           ),
                  //           if (controller.inviteType.value == 'selected') ...[
                  //             const SizedBox(height: 8),
                  //             Container(
                  //               height: 100,
                  //               decoration: BoxDecoration(
                  //                 border: Border.all(color: Colors.grey.shade300),
                  //                 borderRadius: BorderRadius.circular(8),
                  //               ),
                  //               child: ListView.builder(
                  //                 itemCount: controller.availableUsers.length,
                  //                 itemBuilder: (context, index) {
                  //                   final user = controller.availableUsers[index];
                  //                   final isSelected = controller.selectedUsers.contains(user);
                  //                   return CheckboxListTile(
                  //                     title: Text(user.name, style: const TextStyle(fontSize: 12)),
                  //                     subtitle: Text(user.email, style: const TextStyle(fontSize: 10)),
                  //                     value: isSelected,
                  //                     onChanged: (value) => controller.selectUser(user),
                  //                   );
                  //                 },
                  //               ),
                  //             ),
                  //           ],
                  //         ],
                  //         const SizedBox(height: 16),
                  //       ],
                  //     );
                  //   }
                  //   return const SizedBox.shrink();
                  // }),
                  AppTextFormField(
                    controller: controller.meetingIdController,
                    labelText: 'Meeting ID',
                    type: AppTextFormFieldType.text,
                  ),
                  const SizedBox(height: 16),
                  AppTextFormField(
                    controller: controller.passwordController,
                    labelText: 'Password (Optional)',
                    type: AppTextFormFieldType.password,
                    isPasswordRequired: false,
                  ),
                  const SizedBox(height: 16),
                  Obx(
                    () =>
                        controller.errorMessage.value == null
                            ? const SizedBox.shrink()
                            : _buildError(controller.errorMessage.value!),
                  ),
                  const SizedBox(height: 8),
                  Obx(
                    () =>
                        controller.meetingFound.value &&
                                controller.meetingData.value != null
                            ? _buildMeetingInfo(controller.meetingData.value!)
                            : const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 16),
                  Obx(() => _buildActionButtons()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDialogTitle() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.login_rounded, color: AppTheme.primaryColor),
        ),
        const SizedBox(width: 16),
        Text(
          'Join Meeting',
          style: Get.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildError(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.errorColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.errorColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppTheme.errorColor, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppTheme.errorColor, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeetingInfo(MeetingModel data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.successColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.successColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Meeting Name - ${data.meetingName}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: AppTheme.successColor,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.person,
                color: AppTheme.darkSecondaryTextColor,
                size: 16,
              ),
              const SizedBox(width: 12),
              Text(
                '${data.hostName}\'s Meeting',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
          if (data.requiresApproval)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'This meeting requires host approval to join',
                style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final isLoading = controller.isLoading.value;
    final meetingFound = controller.meetingFound.value;
    final meetingData = controller.meetingData.value;
    final isWaitingForApproval = controller.isWaitingForApproval.value;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        TextButton(
          onPressed:
              isLoading || isWaitingForApproval
                  ? () {
                    // If loading or waiting, cancel the listener to prevent further actions
                    controller.cancelJoinRequest();
                  }
                  : () => Get.back(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed:
              isLoading || isWaitingForApproval
                  ? null
                  : meetingFound && meetingData != null
                  ? (meetingData.requiresApproval
                      ? controller.requestToJoin
                      : controller.joinMeeting)
                  : controller.searchMeeting,
          style: ElevatedButton.styleFrom(
            backgroundColor:
                isWaitingForApproval ? Colors.orange : AppTheme.successColor,
          ),
          child:
              isLoading
                  ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                  : isWaitingForApproval
                  ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Waiting for Approval',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  )
                  : Text(
                    meetingFound && meetingData != null
                        ? (meetingData.requiresApproval
                            ? 'Request to Join'
                            : 'Join Now')
                        : 'Search',
                    style: TextStyle(
                      fontSize: meetingFound && meetingData != null ? 12 : 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
        ),
      ],
    );
  }
}
