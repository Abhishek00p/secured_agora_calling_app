import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:secured_calling/core/extensions/app_int_extension.dart';
import 'package:secured_calling/core/extensions/date_time_extension.dart';
import 'package:secured_calling/core/models/member_model.dart';
import 'package:secured_calling/core/services/app_firebase_service.dart';
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
  late TextEditingController name,
      email,
      password,
      maxParticipantsAllowed;
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
    maxParticipantsAllowed = TextEditingController(
      text: widget.member?.maxParticipantsAllowed.toString() ?? '',
    );
    
    // Set initial subscription plan if editing existing member
    if (widget.member != null) {
      final days = widget.member!.planDays;
      selectedPlan = subscriptionPlans.entries
          .firstWhere(
            (entry) => entry.value == days,
            orElse: () => subscriptionPlans.entries.first,
          )
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

        // Register user in Firebase Auth
        final userCredential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
              email: email.text.trim(),
              password: password.text,
            );

        if (!mounted) return;

        // Send email verification
        await userCredential.user?.sendEmailVerification();

        // Create user profile in Firestore
        final userId = await AppFirebaseService.instance.generateUniqueUserId();
        final expiryDate = purchaseDate.add(Duration(days: planDays));
        final userData = {
          'name': name.text.trim(),
          'email': email.text.trim(),
          'userId': userId,
          'memberCode': memberCode,
          'firebaseUserId': userCredential.user!.uid,
          'createdAt': DateTime.now().toIso8601String(),
          'isMember': true,
          'subscription': {
            'plan': expiryDate.differenceInDays < -30 ? 'Premium' : 'Gold',
            'expiryDate': expiryDate.toIso8601String(),
          },
          'planExpiryDate': expiryDate.toIso8601String(),
          'temporaryPassword': password.text, // Store temporary password
          'passwordCreatedBy': 'Admin',
          'passwordCreatedAt': DateTime.now().toIso8601String(),
        };

        // Save user data
        await FirebaseFirestore.instance
            .collection('users')
            .doc('$userId')
            .set(userData);

        if (!mounted) return;

        // Save member data
        final memberData = Member(
          id: '',
          name: name.text.trim(),
          email: email.text.trim(),
          purchaseDate: purchaseDate,
          planDays: planDays,
          isActive: isActive,
          totalUsers: 0,
          maxParticipantsAllowed: int.parse(maxParticipantsAllowed.text) <= 0 ? 45 : int.parse(maxParticipantsAllowed.text),
        );

        final ref = FirebaseFirestore.instance.collection('members');
        final mapData = memberData.toMap();
        mapData['memberCode'] = memberCode;
        await ref.add(mapData);

        if (!mounted) return;

        AppToastUtil.showSuccessToast(
          'Member registered successfully. Please check email for verification.',
        );
        Navigator.pop(context);
      } else {
        // Update existing member
        final planDays = subscriptionPlans[selectedPlan]!;
        final memberData = Member(
          id: widget.member!.id,
          name: name.text.trim(),
          email: email.text.trim(),
          purchaseDate: purchaseDate,
          planDays: planDays,
          isActive: isActive,
          totalUsers: widget.member!.totalUsers,
          maxParticipantsAllowed: int.parse(maxParticipantsAllowed.text) <= 0 ? 45 : int.parse(maxParticipantsAllowed.text),  
        );

        final ref = FirebaseFirestore.instance.collection('members');
        final mapData = memberData.toMap();
        mapData['memberCode'] = widget.member!.memberCode;
        await ref.doc(memberData.id).set(mapData);

        // Update user data in users collection
        final userQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('memberCode', isEqualTo: widget.member!.memberCode)
            .get();

        if (userQuery.docs.isNotEmpty) {
          final expiryDate = purchaseDate.add(Duration(days: planDays));
          await userQuery.docs.first.reference.update({
            'name': name.text.trim(),
            'email': email.text.trim(),
            'subscription': {
              'plan': expiryDate.differenceInDays < -30 ? 'Premium' : 'Gold',
              'expiryDate': expiryDate.toIso8601String(),
            },
            'planExpiryDate': expiryDate.toIso8601String(),
          });
        }

        AppToastUtil.showSuccessToast(
          'Member details updated successfully.',
        );
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      String message = 'An error occurred';
      if (e.code == 'weak-password') {
        message = 'The password provided is too weak.';
      } else if (e.code == 'email-already-in-use') {
        message = 'An account already exists for that email.';
      }
      AppToastUtil.showErrorToast(message);
    } catch (e) {
      AppToastUtil.showErrorToast('An error occurred: $e');
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
      return DropdownModel<String>(
        label: entry.key,
        value: entry.key,
        description: '${entry.value} days',
      );
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
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    widget.member == null
                        ? "Save & Register Member"
                        : "Update Member Details",
                  ),
          ),
        ),
        appBar: AppBar(
          title: Text(widget.member == null ? "Add Member" : "Edit Member"),
        ),
        body: Form(
          key: _formKey,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView(
              children: [
                24.h,
                AppTextFormField(
                  controller: name,
                  labelText: "Name",
                  type: AppTextFormFieldType.name,
                ),
                const SizedBox(height: 12),
                AppTextFormField(
                  controller: email,
                  labelText: "Email",
                  type: AppTextFormFieldType.email,
                ),
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
                  onPressed: () => showDatePicker(
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
                    Switch(
                      value: isActive,
                      onChanged: (v) => setState(() => isActive = v),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (widget.member == null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'A verification email will be sent to the provided email address. The member must verify their email to complete the registration process.',
                            style: TextStyle(color: Colors.blue, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
