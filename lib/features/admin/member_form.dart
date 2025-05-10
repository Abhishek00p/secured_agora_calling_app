import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:secured_calling/core/extensions/app_int_extension.dart';
import 'package:secured_calling/core/models/member_model.dart';
import 'package:secured_calling/core/services/app_firebase_service.dart';
import 'package:secured_calling/utils/app_tost_util.dart';
import 'package:secured_calling/widgets/app_text_form_widget.dart';

class MemberForm extends StatefulWidget {
  final Member? member;
  const MemberForm({super.key, this.member});

  @override
  State<MemberForm> createState() => _MemberFormState();
}

class _MemberFormState extends State<MemberForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController name, email, days, password;
  DateTime purchaseDate = DateTime.now();
  bool isActive = true;
  bool _isLoading = false;

  String get generateMemberCode {
    final random = DateTime.now().millisecondsSinceEpoch.toString();
    return "MEM-${random.substring(random.length - 6)}";
  }

  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.member?.name ?? '');
    email = TextEditingController(text: widget.member?.email ?? '');
    days = TextEditingController(
      text: widget.member?.planDays.toString() ?? '',
    );
    password = TextEditingController();
    purchaseDate = widget.member?.purchaseDate ?? DateTime.now();
    isActive = widget.member?.isActive ?? true;
  }

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    days.dispose();
    password.dispose();
    super.dispose();
  }

  void _saveMember() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      if (widget.member == null) {
        // New member registration flow
        final memberCode = generateMemberCode;
        
        // Register user in Firebase Auth
        final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email.text.trim(),
          password: password.text,
        );

        // Send email verification
        await userCredential.user?.sendEmailVerification();

        // Create user profile in Firestore
        final userId = await AppFirebaseService.instance.generateUniqueUserId();
        final userData = {
          'name': name.text.trim(),
          'email': email.text.trim(),
          'userId': userId,
          'memberCode': memberCode,
          'firebaseUserId': userCredential.user!.uid,
          'createdAt': DateTime.now().toIso8601String(),
          'isMember': true,
          'subscription': null,
        };

        // Save user data
        await FirebaseFirestore.instance
            .collection('users')
            .doc('$userId')
            .set(userData);

        // Save member data
        final memberData = Member(
          id: '',
          name: name.text.trim(),
          email: email.text.trim(),
          purchaseDate: purchaseDate,
          planDays: int.parse(days.text),
          isActive: isActive,
          totalUsers: 0,
        );

        final ref = FirebaseFirestore.instance.collection('members');
        final mapData = memberData.toMap();
        mapData['memberCode'] = memberCode;
        await ref.add(mapData);

        if (mounted) {
          AppToastUtil.showSuccessToast(
            context,
            'Member registered successfully. Please check email for verification.',
          );
          Navigator.pop(context);
        }
      } else {
        // Update existing member
        final memberData = Member(
          id: widget.member!.id,
          name: name.text.trim(),
          email: email.text.trim(),
          purchaseDate: purchaseDate,
          planDays: int.parse(days.text),
          isActive: isActive,
          totalUsers: widget.member!.totalUsers,
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
          await userQuery.docs.first.reference.update({
            'name': name.text.trim(),
            'email': email.text.trim(),
          });
        }

        if (mounted) {
          AppToastUtil.showSuccessToast(
            context,
            'Member details updated successfully.',
          );
          Navigator.pop(context);
        }
      }
    } on FirebaseAuthException catch (e) {
      String message = 'An error occurred';
      if (e.code == 'weak-password') {
        message = 'The password provided is too weak.';
      } else if (e.code == 'email-already-in-use') {
        message = 'An account already exists for that email.';
      }
      if (mounted) {
        AppToastUtil.showErrorToast(context, message);
      }
    } catch (e) {
      if (mounted) {
        AppToastUtil.showErrorToast(context, 'An error occurred: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.member == null ? "Add Member" : "Edit Member"),
      ),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              24.h,
              AppTextFormField(
                controller: name,
                labelText: "Name",
                prefixIcon: Icons.person,
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 12),
              AppTextFormField(
                controller: email,
                labelText: "Email",
                prefixIcon: Icons.email,
                keyboardType: TextInputType.emailAddress,
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 12),
              if (widget.member == null) ...[
                AppTextFormField(
                  controller: password,
                  labelText: "Password",
                  prefixIcon: Icons.lock,
                  obscureText: true,
                  helperText: "Enter password for member login",
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return "Required";
                    }
                    if (v.length < 6) {
                      return "Password must be at least 6 characters";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
              ],
              AppTextFormField(
                controller: days,
                labelText: "Subscription Days",
                prefixIcon: Icons.calendar_today,
                keyboardType: TextInputType.number,
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 12),
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
                          style: TextStyle(
                            color: Colors.blue,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _saveMember,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : Text(widget.member == null 
                        ? "Save & Register Member" 
                        : "Update Member Details"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
