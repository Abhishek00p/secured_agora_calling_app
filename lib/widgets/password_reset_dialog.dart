import 'package:flutter/material.dart';
import 'package:secured_calling/core/services/app_password_reset_service.dart';
import 'package:secured_calling/core/services/app_local_storage.dart';
import 'package:secured_calling/core/services/app_user_role_service.dart';
import 'package:secured_calling/core/theme/app_theme.dart';
import 'package:secured_calling/core/utils/responsive_utils.dart';
import 'package:secured_calling/utils/app_tost_util.dart';

class PasswordResetBottomSheet extends StatefulWidget {
  final String targetEmail;
  final String targetName;
  final bool isMember;

  const PasswordResetBottomSheet({super.key, required this.targetEmail, required this.targetName, required this.isMember});

  @override
  State<PasswordResetBottomSheet> createState() => _PasswordResetBottomSheetState();

  static Future<void> show(BuildContext context, {required String targetEmail, required String targetName, required bool isMember}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true, // 👈 important for keyboard resize
      backgroundColor: Colors.transparent,
      builder:
          (_) => DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.65,
            minChildSize: 0.4,
            maxChildSize: 0.9,
            builder: (context, scrollController) {
              return PasswordResetBottomSheet(targetEmail: targetEmail, targetName: targetName, isMember: isMember);
            },
          ),
    );
  }
}

class _PasswordResetBottomSheetState extends State<PasswordResetBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _showPassword = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = AppLocalStorage.getUserDetails();
      final success = await AppPasswordResetService.resetPassword(
        targetEmail: widget.targetEmail,
        newPassword: _passwordController.text,
        currentUserEmail: currentUser.email,
      );

      if ((success ?? false) && mounted) {
        Navigator.pop(context, true);
        AppToastUtil.showSuccessToast('Password reset successfully.');
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
    final currentUserRole = AppUserRoleService.getCurrentUserRole();
    final canResetPassword = currentUserRole == UserRole.admin || currentUserRole == UserRole.superAdmin || currentUserRole == UserRole.member;

    final padding = responsivePadding(context);

    return Container(
      padding: EdgeInsets.only(left: padding, right: padding, top: padding, bottom: MediaQuery.of(context).viewInsets.bottom + padding),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle indicator
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Row(
                children: [
                  Icon(Icons.lock_reset, color: AppTheme.primaryColor, size: 24),
                  const SizedBox(width: 8),
                  const Text('Reset Password', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 16),

              Text('Reset password for:', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Name: ', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                        const SizedBox(width: 4),
                        Text(widget.targetName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    Row(
                      children: [
                        Text('Userid: ', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                        const SizedBox(width: 4),
                        Text(widget.targetEmail, style: TextStyle(color: Colors.grey[800], fontSize: 14)),
                      ],
                    ),
                    Text('Role: ${widget.isMember ? 'Member' : 'User'}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (!canResetPassword)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red[600], size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Text('You do not have permission to reset passwords.', style: TextStyle(color: Colors.red[700], fontSize: 14))),
                    ],
                  ),
                )
              else ...[
                Text('Enter new temporary password:', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_showPassword,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    hintText: 'Enter temporary password',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_showPassword ? Icons.visibility : Icons.visibility_off),
                      onPressed: () {
                        setState(() {
                          _showPassword = !_showPassword;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Please enter a password';
                    if (value.length < 6) return 'Password must be at least 6 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange[600], size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('A password reset email will be sent to the user.', style: TextStyle(color: Colors.orange[700], fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                  const SizedBox(width: 8),
                  if (canResetPassword)
                    ElevatedButton(
                      onPressed: _isLoading ? null : _resetPassword,
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
                      child:
                          _isLoading
                              ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                              )
                              : const Text('Reset Password'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
