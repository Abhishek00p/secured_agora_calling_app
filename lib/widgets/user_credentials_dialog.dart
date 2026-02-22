import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:secured_calling/core/services/app_firebase_service.dart';
import 'package:secured_calling/core/services/app_password_reset_service.dart';
import 'package:secured_calling/core/services/app_user_role_service.dart';
import 'package:secured_calling/features/home/views/delete_confirmation_dialog.dart';
import 'package:secured_calling/utils/app_tost_util.dart';
import 'package:secured_calling/core/theme/app_theme.dart';
import 'package:secured_calling/core/utils/responsive_utils.dart';
import 'package:secured_calling/widgets/password_reset_dialog.dart';

class UserCredentialsBottomSheet extends StatefulWidget {
  final String targetEmail;
  final String targetName;
  final bool isMember;
  final String userId;

  const UserCredentialsBottomSheet({super.key, required this.targetEmail, required this.targetName, required this.isMember, required this.userId});

  @override
  State<UserCredentialsBottomSheet> createState() => _UserCredentialsBottomSheetState();

  /// Call this from outside to show bottomsheet
  static Future<void> show(
    BuildContext context, {
    required String targetEmail,
    required String targetName,
    required bool isMember,
    required String userId,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      transitionAnimationController: AnimationController(
        duration: const Duration(milliseconds: 400),
        reverseDuration: const Duration(milliseconds: 300),
        vsync: Navigator.of(context),
      ),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder:
          (_) => FractionallySizedBox(
            heightFactor: 0.85,
            child: UserCredentialsBottomSheet(targetEmail: targetEmail, targetName: targetName, isMember: isMember, userId: userId),
          ),
    );
  }
}

class _UserCredentialsBottomSheetState extends State<UserCredentialsBottomSheet> {
  Map<String, dynamic>? _credentials;
  bool _isLoading = true;
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
    _loadCredentials();
  }

  Future<void> _loadCredentials() async {
    try {
      final credentials = await AppPasswordResetService.getUserCredentials(widget.userId);
      setState(() {
        _credentials = credentials;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _showPasswordResetDialog() async {
    Get.back();
    await Future.delayed(Duration(milliseconds: 200));
    if (context.mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        transitionAnimationController: AnimationController(
          duration: const Duration(milliseconds: 400),
          reverseDuration: const Duration(milliseconds: 300),
          vsync: Navigator.of(context),
        ),
        builder: (context) => PasswordResetBottomSheet(targetEmail: widget.targetEmail, targetName: widget.targetName, isMember: widget.isMember),
      ).then((result) {
        if (result == true) {
          _loadCredentials();
        }
      });
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    AppToastUtil.showSuccessToast('$label copied to clipboard');
  }

  @override
  Widget build(BuildContext context) {
    final currentUserRole = AppUserRoleService.getCurrentUserRole();
    final canViewCredentials = currentUserRole == UserRole.admin || currentUserRole == UserRole.superAdmin || currentUserRole == UserRole.member;
    final padding = responsivePadding(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.only(top: padding, bottom: padding / 4),
            child: Container(height: 5, width: 50, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(3))),
          ),

          Padding(
            padding: EdgeInsets.all(padding),
            child: Row(
              children: [
                Icon(Icons.account_circle, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                const Text('User Credentials', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),

          const Divider(height: 0),

          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(padding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User Info
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
                        Text(widget.targetName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(widget.targetEmail, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                        Text('Role: ${widget.isMember ? 'Member' : 'User'}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (!canViewCredentials) ...[
                    _buildMessageBox(color: Colors.red, icon: Icons.error_outline, text: 'You do not have permission to view credentials.'),
                  ] else if (_isLoading) ...[
                    const Center(child: CircularProgressIndicator()),
                  ] else if (_credentials == null) ...[
                    _buildMessageBox(color: Colors.orange, icon: Icons.warning_amber_outlined, text: 'Unable to load user credentials.'),
                  ] else ...[
                    Text('Login Credentials:', style: TextStyle(color: Colors.grey[700], fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),

                    // Email
                    _buildCredentialTile(
                      label: 'UserId',
                      value: _credentials!['email'],
                      icon: Icons.perm_contact_cal_sharp,
                      onCopy: () => _copyToClipboard(_credentials!['email'], 'userId'),
                    ),
                    const SizedBox(height: 8),

                    // Password
                    _buildCredentialTile(
                      label: 'Password',
                      value: _showPassword ? _credentials!['password'] : '••••••••',
                      icon: Icons.lock,
                      isPassword: true,
                      onToggle: () => setState(() => _showPassword = !_showPassword),
                      onCopy: () => _copyToClipboard(_credentials!['password'], 'Password'),
                    ),
                    const SizedBox(height: 16),

                    _buildMessageBox(color: Colors.blue, icon: Icons.info_outline, text: 'Share these credentials securely with the user.'),
                  ],
                ],
              ),
            ),
          ),

          if (canViewCredentials && _credentials != null)
            Padding(
              padding: EdgeInsets.all(padding),
              child: ElevatedButton.icon(
                onPressed: _showPasswordResetDialog,
                icon: const Icon(Icons.lock_reset),
                label: const Text('Reset Password'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          Padding(
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
                          // Add your cancellation logic here
                        },
                        onDelete: () async {
                          AppFirebaseService.instance.usersCollection.doc(widget.userId).delete();
                          // AppFirebaseService.instance.membersCollection.doc(widget.userId).delete();
                          await Future.delayed(const Duration(milliseconds: 500));
                          if (context.mounted) {
                            Navigator.of(context).pop();
                            Navigator.of(context).pop();
                          }
                          // Add your deletion logic here
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
          ),
        ],
      ),
    );
  }

  Widget _buildCredentialTile({
    required String label,
    required String value,
    required IconData icon,
    bool isPassword = false,
    VoidCallback? onToggle,
    VoidCallback? onCopy,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey[300]!)),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.w500)),
                Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          if (isPassword && onToggle != null)
            IconButton(icon: Icon(_showPassword ? Icons.visibility : Icons.visibility_off, size: 18), onPressed: onToggle),
          if (onCopy != null) IconButton(icon: const Icon(Icons.copy, size: 18), onPressed: onCopy),
        ],
      ),
    );
  }

  Widget _buildMessageBox({required Color color, required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(color: color, fontSize: 14))),
        ],
      ),
    );
  }
}
