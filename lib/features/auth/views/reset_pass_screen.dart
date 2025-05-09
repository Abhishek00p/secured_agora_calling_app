import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:secured_calling/core/services/app_firebase_service.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final oldPassController = TextEditingController();
  final newPassController = TextEditingController();
  final codeController = TextEditingController();

  bool _isCodeSent = false;
  bool _isVerified = false;
  bool _isLoading = false;

  void _sendCode() async {
    if (emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Enter email"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // You can generate and send the code via email here if needed.
    final resp = await AppFirebaseService.instance.sendResetPasswordEmail(
      emailController.text.trim(),
    );

    if (resp != null && resp) {
      setState(() {
        _isCodeSent = true;
      });
   
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Failed to send code"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _verifyCode() {
    if (codeController.text.trim() == "123456") {
      setState(() => _isVerified = true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Invalid code"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    final email = emailController.text.trim();
    final oldPass = oldPassController.text.trim();
    final newPass = newPassController.text.trim();

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;

      final credential = EmailAuthProvider.credential(
        email: email,
        password: oldPass,
      );
      await user!.reauthenticateWithCredential(credential);
      await user.updatePassword(newPass);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Password updated"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? "Error"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text("Reset Password")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: ListView(
                shrinkWrap: true,
                children: [
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: emailController,
                    decoration: const InputDecoration(labelText: "Email"),
                    validator: (value) => value!.isEmpty ? "Enter email" : null,
                  ),
                  const SizedBox(height: 16),

                  // Code input & actions
                  if (!_isVerified) ...[
                    if (_isCodeSent) ...[
                      TextFormField(
                        controller: codeController,
                        decoration: const InputDecoration(
                          labelText: "Enter Verification Code",
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _verifyCode,
                        child: const Text("Verify"),
                      ),
                    ] else ...[
                      ElevatedButton(
                        onPressed: _sendCode,
                        child: const Text("Send Code"),
                      ),
                    ],
                  ],

                  if (_isVerified) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: oldPassController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: "Old Password",
                      ),
                      validator:
                          (value) =>
                              value!.isEmpty ? "Enter old password" : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: newPassController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: "New Password",
                      ),
                      validator:
                          (value) =>
                              value!.length < 6 ? "Minimum 6 characters" : null,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _resetPassword,
                      child:
                          _isLoading
                              ? const CircularProgressIndicator()
                              : const Text("Update Password"),
                    ),
                  ],
                  const SizedBox(height: 60),
                  Text(
                    "Enter your email to receive a verification code. Once verified, you can change your password.",
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
