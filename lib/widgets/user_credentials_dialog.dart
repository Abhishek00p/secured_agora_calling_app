import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:secured_calling/core/services/app_password_reset_service.dart';
import 'package:secured_calling/core/services/app_user_role_service.dart';
import 'package:secured_calling/utils/app_tost_util.dart';
import 'package:secured_calling/core/theme/app_theme.dart';
import 'package:secured_calling/widgets/password_reset_dialog.dart';

class UserCredentialsDialog extends StatefulWidget {
  final String targetEmail;
  final String targetName;
  final bool isMember;

  const UserCredentialsDialog({
    super.key,
    required this.targetEmail,
    required this.targetName,
    required this.isMember,
  });

  @override
  State<UserCredentialsDialog> createState() => _UserCredentialsDialogState();
}

class _UserCredentialsDialogState extends State<UserCredentialsDialog> {
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
      final credentials = await AppPasswordResetService.getUserCredentials(widget.targetEmail);
      setState(() {
        _credentials = credentials;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showPasswordResetDialog() {
    showDialog(
      context: context,
      builder: (context) => PasswordResetDialog(
        targetEmail: widget.targetEmail,
        targetName: widget.targetName,
        isMember: widget.isMember,
      ),
    ).then((result) {
      if (result == true) {
        // Refresh credentials after password reset
        _loadCredentials();
      }
    });
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    AppToastUtil.showSuccessToast('$label copied to clipboard');
  }

  @override
  Widget build(BuildContext context) {
    final currentUserRole = AppUserRoleService.getCurrentUserRole();
    final canViewCredentials = currentUserRole == UserRole.admin || 
                             currentUserRole == UserRole.superAdmin || 
                             currentUserRole == UserRole.member;

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.account_circle,
            color: AppTheme.primaryColor,
            size: 24,
          ),
          const SizedBox(width: 8),
          Text('User Credentials'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
                  Text(
                    widget.targetName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    widget.targetEmail,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'Role: ${widget.isMember ? 'Member' : 'User'}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            if (!canViewCredentials) ...[
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
                    Expanded(
                      child: Text(
                        'You do not have permission to view credentials.',
                        style: TextStyle(color: Colors.red[700], fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (_isLoading) ...[
              const Center(
                child: CircularProgressIndicator(),
              ),
            ] else if (_credentials == null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_outlined, color: Colors.orange[600], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Unable to load user credentials.',
                        style: TextStyle(color: Colors.orange[700], fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Credentials Display
              Text(
                'Login Credentials:',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              
              // Email
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.email, color: Colors.grey[600], size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Email',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            _credentials!['email'],
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 18),
                      onPressed: () => _copyToClipboard(
                        _credentials!['email'],
                        'Email',
                      ),
                      tooltip: 'Copy email',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              
              // Password
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock, color: Colors.grey[600], size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Password',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            _showPassword 
                                ? _credentials!['password']
                                : '••••••••',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            _showPassword ? Icons.visibility : Icons.visibility_off,
                            size: 18,
                          ),
                          onPressed: () {
                            setState(() {
                              _showPassword = !_showPassword;
                            });
                          },
                          tooltip: _showPassword ? 'Hide password' : 'Show password',
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 18),
                          onPressed: () => _copyToClipboard(
                            _credentials!['password'],
                            'Password',
                          ),
                          tooltip: 'Copy password',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Info message
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[600], size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Share these credentials securely with the user.',
                        style: TextStyle(color: Colors.blue[700], fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        if (canViewCredentials && _credentials != null)
          ElevatedButton.icon(
            onPressed: _showPasswordResetDialog,
            icon: const Icon(Icons.lock_reset),
            label: const Text('Reset Password'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
      ],
    );
  }
}
