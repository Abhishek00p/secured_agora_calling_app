import 'package:flutter/material.dart';
import 'package:secured_calling/core/extensions/app_int_extension.dart';
import 'package:secured_calling/core/extensions/date_time_extension.dart';
import 'package:secured_calling/core/models/member_model.dart';
import 'package:secured_calling/core/services/app_auth_service.dart';
import 'package:secured_calling/utils/app_tost_util.dart';
import 'package:secured_calling/widgets/app_text_container.dart';
import 'package:secured_calling/widgets/app_text_form_widget.dart';
import 'package:secured_calling/widgets/app_dropdown_field.dart';

class MemberForm extends StatefulWidget {
  final Member? member;
  const MemberForm({super.key, this.member});

  @override
  State<MemberForm> createState() => _MemberFormState();
}

class _MemberFormState extends State<MemberForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController name, email, password, maxParticipantsAllowed;
  DateTime purchaseDate = DateTime.now();
  bool isActive = true;
  bool _isLoading = false;

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
    password = TextEditingController();
    purchaseDate = widget.member?.purchaseDate ?? DateTime.now();
    isActive = widget.member?.isActive ?? true;
    maxParticipantsAllowed = TextEditingController(text: widget.member?.maxParticipantsAllowed.toString() ?? '');

    // Set initial subscription plan if editing existing member
    if (widget.member != null) {
      final days = widget.member!.planDays;
      selectedPlan =
          subscriptionPlans.entries
              .firstWhere((entry) => entry.value == days, orElse: () => subscriptionPlans.entries.first)
              .key;
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
      if (widget.member == null) {
        // New member registration flow
        final memberCode = generateMemberCode;
        final planDays = subscriptionPlans[selectedPlan]!;

        // Create member using the new auth service
        final success = await AppAuthService.instance.createMember(
          name: name.text.trim(),
          email: email.text.trim(),
          password: password.text,
          memberCode: memberCode,
          purchaseDate: purchaseDate,
          planDays: planDays,
          maxParticipantsAllowed:
              int.parse(maxParticipantsAllowed.text) <= 0 ? 45 : int.parse(maxParticipantsAllowed.text),
        );

        if ((success ?? false) && mounted) {
          AppToastUtil.showSuccessToast('Member created successfully.');
          Navigator.pop(context);
        }
      } else {
        // Update existing member - this would need a separate update function
        AppToastUtil.showErrorToast('Member updates not yet implemented');
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.all(8.0),
          child: ElevatedButton(
            onPressed: _isLoading ? null : _saveMember,
            child:
                _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(widget.member == null ? "Save & Register Member" : "Update Member Details"),
          ),
        ),
        appBar: AppBar(title: Text(widget.member == null ? "Add Member" : "Edit Member")),
        body: Form(
          key: _formKey,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView(
              children: [
                24.h,
                AppTextFormField(controller: name, labelText: "Name", type: AppTextFormFieldType.name),
                const SizedBox(height: 12),
                AppTextFormField(controller: email, labelText: "userId", type: AppTextFormFieldType.text),
                const SizedBox(height: 12),
                if (widget.member == null) ...[
                  AppTextFormField(
                    controller: password,
                    labelText: "Password",
                    type: AppTextFormFieldType.password,
                    helperText: "Enter a Temporary password for member login",
                  ),
                  const SizedBox(height: 12),
                ],
                AppTextContainer(
                  text: purchaseDate.formatDate,
                  label: "Purchase Date",
                  prefixIcon: Icons.calendar_month,
                  onPressed:
                      () => showDatePicker(
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
                  onChanged: (String? newValue) {
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
                    Switch(value: isActive, onChanged: (v) => setState(() => isActive = v)),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
