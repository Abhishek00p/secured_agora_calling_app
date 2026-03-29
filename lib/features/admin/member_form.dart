
import 'package:flutter/material.dart';
import 'package:secured_calling/core/extensions/app_int_extension.dart';
import 'package:secured_calling/core/extensions/app_string_extension.dart';
import 'package:secured_calling/core/extensions/date_time_extension.dart';
import 'package:secured_calling/core/models/app_user_model.dart';
import 'package:secured_calling/core/services/app_auth_service.dart';
import 'package:secured_calling/core/services/app_firebase_service.dart';
import 'package:secured_calling/core/utils/responsive_utils.dart';
import 'package:secured_calling/features/home/views/delete_confirmation_dialog.dart';
import 'package:secured_calling/utils/app_tost_util.dart';
import 'package:secured_calling/widgets/app_text_container.dart';
import 'package:secured_calling/widgets/app_text_form_widget.dart';
import 'package:secured_calling/widgets/app_dropdown_field.dart';

class MemberForm extends StatefulWidget {
  final AppUser? member;
  final bool canEdit;
  const MemberForm({super.key, this.member, this.canEdit = true});

  @override
  State<MemberForm> createState() => _MemberFormState();
}

class _MemberFormState extends State<MemberForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController name, email, password, maxParticipantsAllowed;
  DateTime purchaseDate = DateTime.now();
  bool isActive = true;
  bool _isLoading = false;
  bool canSeeMixRecording = false;
  // Add subscription plans
  final Map<String, int> subscriptionPlans = {
    '1 Month': 30,
    '2 Months': 60,
    '3 Months': 90,
    '6 Months': 180,
    '1 Year': 365,
    '2 Years': 730,
    '3 Years': 1095,
    '5 Years': 1825,
    '10 Years': 3650,
    'Permanent': 36500, // 100 years as permanent
  };

  String selectedPlan = '1 Month'; // Default selection

  String get generateMemberCode {
    final random = DateTime.now().millisecondsSinceEpoch.toString();
    return "MEM-${random.substring(random.length - 6)}";
  }

  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.member?.name ?? '');
    email = TextEditingController(text: widget.member?.email ?? '');
    password = TextEditingController(text: widget.member?.password ?? '');
    purchaseDate = widget.member?.purchaseDate.toDateTime ?? DateTime.now();
    isActive = widget.member?.isActive ?? true;
    canSeeMixRecording = widget.member?.canSeeMixRecording ?? false;
    maxParticipantsAllowed = TextEditingController(text: widget.member?.maximumParticipantsAllowed.toString() ?? '');

    // Set initial subscription plan if editing existing member
    if (widget.member != null) {
      final days = widget.member!.planDays;
      selectedPlan = subscriptionPlans.entries.firstWhere((entry) => entry.value == days, orElse: () => subscriptionPlans.entries.first).key;
    }
  }

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    maxParticipantsAllowed.dispose();
    super.dispose();
  }

  void _saveMember() async {
    if (!_formKey.currentState!.validate()) return;

    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // New member registration flow
      final memberCode = widget.member?.memberCode ?? generateMemberCode;
      final planDays = subscriptionPlans[selectedPlan]!;

      // Create member using the new auth service
      final success = await AppAuthService.instance.createOrEditMember(
        userId: widget.member?.userId,
        isEdit: widget.member != null,
        name: name.text.trim(),
        email: email.text.trim(),
        password: password.text,
        memberCode: memberCode,
        purchaseDate: purchaseDate,
        planDays: planDays,
        isActive: isActive,
        canSeeMixRecording: canSeeMixRecording,
        maxParticipantsAllowed: int.parse(maxParticipantsAllowed.text) <= 0 ? 45 : int.parse(maxParticipantsAllowed.text),
      );

      if ((success ?? false) && mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      String message = 'An error occurred';
      if (e.toString().contains('weak-password')) {
        message = 'The password provided is too weak.';
      } else if (e.toString().contains('already-exists')) {
        message = 'An account already exists for that userId.';
      } else {
        message = e.toString();
      }
      AppToastUtil.showErrorToast(message);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<DropdownModel<String>> get subscriptionPlanItems {
    return subscriptionPlans.entries.map((entry) {
      return DropdownModel<String>(label: entry.key, value: entry.key, description: '${entry.value} days');
    }).toList();
  }

  bool isDesktop(BuildContext context) => context.layoutType == AppLayoutType.laptop || context.layoutType == AppLayoutType.laptop;

  @override
  Widget build(BuildContext context) {
    final padding = responsivePadding(context);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        bottomNavigationBar:
            !widget.canEdit
                ? Padding(
                  padding: EdgeInsets.only(bottom: padding, left: padding, right: padding),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder:
                            (context) => DeleteConfirmationDialog(
                              description: 'This action cannot be undone.',
                              onCancel: () {
                                Navigator.of(context).pop();
                              },
                              onDelete: () async {
                                AppFirebaseService.instance.usersCollection.doc(widget.member?.userId.toString()).delete();
                                await Future.delayed(const Duration(milliseconds: 500));
                                if (context.mounted) {
                                  Navigator.of(context).pop();
                                  Navigator.of(context).pop();
                                }
                              },
                            ),
                      );
                    },
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Delete User'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                )
                : Padding(
                  padding: EdgeInsets.all(padding),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveMember,
                    child:
                        _isLoading
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : Text(widget.member == null ? "Save & Register Member" : "Update Member Details"),
                  ),
                ),
        appBar: AppBar(
          scrolledUnderElevation: 0,
          title: Text(
            widget.member == null
                ? "Add Member"
                : widget.canEdit
                ? "Edit Member"
                : "Member Details",
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: contentMaxWidth(context) == double.infinity ? double.infinity : 560),
            child: Form(
              key: _formKey,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: padding),
                child: ListView(
                  children: [
                    24.h,
                    AppTextFormField(controller: name, labelText: "Name", type: AppTextFormFieldType.name, readOnly: !widget.canEdit),
                    const SizedBox(height: 12),
                    AppTextFormField(controller: email, labelText: "userId", type: AppTextFormFieldType.text, readOnly: !widget.canEdit),
                    const SizedBox(height: 12),
                    AppTextFormField(controller: password, labelText: "Password", type: AppTextFormFieldType.password, readOnly: !widget.canEdit),
                    const SizedBox(height: 12),
                    AppTextContainer(
                      text: purchaseDate.formatDate,
                      label: "Purchase Date",
                      prefixIcon: Icons.calendar_month,
                      onPressed:
                          !widget.canEdit
                              ? () {}
                              : () => showDatePicker(
                                context: context,
                                initialDate: purchaseDate,
                                firstDate: DateTime.now().subtract(const Duration(days: 60)),
                                lastDate: DateTime(2100),
                              ).then((value) {
                                if (value != null) {
                                  setState(() => purchaseDate = value);
                                }
                              }),
                    ),
                    const SizedBox(height: 12),
                    AppDropdownField<String>(
                      label: "Subscription Plan",
                      value: selectedPlan,
                      items: subscriptionPlanItems,
                      prefixIcon: Icons.subscriptions,
                      enabled: widget.canEdit,
                      onChanged:
                          !widget.canEdit
                              ? null
                              : (String? newValue) {
                                if (newValue != null) {
                                  setState(() {
                                    selectedPlan = newValue;
                                  });
                                }
                              },
                    ),
                    const SizedBox(height: 12),
                    AppTextFormField(
                      controller: maxParticipantsAllowed,
                      labelText: "Max Participants Allowed",
                      type: AppTextFormFieldType.number,
                      readOnly: !widget.canEdit,
                      validator: (value) {
                        if (value == null || int.parse(value) <= 0) {
                          return 'Max participants allowed must be greater than 0';
                        }
                        if (int.parse(value) % 5 != 0) {
                          return 'Max participants must be a multiple of 5';
                        }
                        return null;
                      },
                      helperText: "Max number of participants allowed in a Meeting in Multple of 5, eg: 5, 10, 15...",
                      prefixIcon: Icons.group,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Active"),
                        Switch(value: isActive, onChanged: widget.canEdit ? (v) => setState(() => isActive = v) : null),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Can see mix recording"),
                        Switch(value: canSeeMixRecording, onChanged: widget.canEdit ? (v) => setState(() => canSeeMixRecording = v) : null),
                      ],
                    ),
                    SizedBox(height: padding * 1.5),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
