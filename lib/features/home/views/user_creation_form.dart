import 'package:flutter/material.dart';
import 'package:secured_calling/core/models/app_user_model.dart';
import 'package:secured_calling/core/services/app_auth_service.dart';
import 'package:secured_calling/core/services/app_firebase_service.dart';
import 'package:secured_calling/core/services/app_local_storage.dart';
import 'package:secured_calling/core/theme/app_theme.dart';
import 'package:secured_calling/core/utils/responsive_utils.dart';
import 'package:secured_calling/features/home/views/delete_confirmation_dialog.dart';
import 'package:secured_calling/utils/app_tost_util.dart';
import 'package:secured_calling/widgets/app_text_form_widget.dart';

enum UserFormMode { create, view, edit }

class UserCreationForm extends StatefulWidget {
  final AppUser? user;
  final bool viewOnly;

  const UserCreationForm({super.key, this.user, this.viewOnly = false});

  bool get isCreateMode => user == null;
  bool get isViewMode => user != null && viewOnly;
  bool get isEditMode => user != null && !viewOnly;

  @override
  State<UserCreationForm> createState() => _UserCreationFormState();
}

class _UserCreationFormState extends State<UserCreationForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  late String _currentUserMemberCode;

  @override
  void initState() {
    super.initState();
    _currentUserMemberCode = AppLocalStorage.getUserDetails().memberCode;
    if (widget.user != null) {
      _nameController.text = widget.user!.name;
      _emailController.text = widget.user!.email;
      if (widget.isViewMode) {
        _passwordController.text = '••••••••';
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _createUser() async {
    if (!_formKey.currentState!.validate()) return;

    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await AppAuthService.instance.createUser(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        memberCode: _currentUserMemberCode,
      );

      if ((success ?? false) && mounted) {
        // Clear form
        _formKey.currentState!.reset();
        _nameController.clear();
        _emailController.clear();
        _passwordController.clear();

        // Return true to indicate successful creation
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        AppToastUtil.showErrorToast('Failed to create user: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateUser() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.user == null) return;

    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final newPassword = _passwordController.text.trim();
      final success = await AppAuthService.instance.updateUser(
        userId: widget.user!.userId,
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        newPassword: newPassword.isEmpty ? null : newPassword,
        memberCode: _currentUserMemberCode,
      );

      if ((success ?? false) && mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        AppToastUtil.showErrorToast('Failed to update user: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String get _appBarTitle {
    if (widget.isViewMode) return 'View User';
    if (widget.isEditMode) return 'Edit User';
    return 'Create New User';
  }

  @override
  Widget build(BuildContext context) {
    final padding = responsivePadding(context);
    final isReadOnly = widget.isViewMode;

    return Scaffold(
      appBar: AppBar(title: Text(_appBarTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: contentMaxWidth(context) == double.infinity ? double.infinity : 560),
          child: Form(
            key: _formKey,
            child: Padding(
              padding: EdgeInsets.all(padding),
              child: ListView(
                children: [
                  const SizedBox(height: 24),

                  // Info Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                            const SizedBox(width: 8),
                            Text(
                              widget.isCreateMode ? 'Creating User Under Member Code' : 'Member Code',
                              style: TextStyle(color: Colors.blue[700], fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Member Code: $_currentUserMemberCode', style: TextStyle(color: Colors.blue[700], fontWeight: FontWeight.w500)),
                        if (widget.isCreateMode) ...[
                          const SizedBox(height: 8),
                          Text(
                            'This user will be automatically associated with your member code and will have access to your meetings.',
                            style: TextStyle(color: Colors.blue[700], fontSize: 14),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Name Field
                  AppTextFormField(
                    controller: _nameController,
                    labelText: 'Full Name',
                    type: AppTextFormFieldType.text,
                    readOnly: isReadOnly,
                    validator:
                        isReadOnly
                            ? null
                            : (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter the user\'s name';
                              }
                              return null;
                            },
                  ),

                  const SizedBox(height: 16),

                  // Email Field
                  AppTextFormField(
                    controller: _emailController,
                    labelText: 'User Id',
                    type: AppTextFormFieldType.text,
                    readOnly: isReadOnly,
                    validator:
                        isReadOnly
                            ? null
                            : (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter the user\'s Id';
                              }
                              return null;
                            },
                  ),

                  const SizedBox(height: 16),

                  // Password Field
                  AppTextFormField(
                    controller: _passwordController,
                    labelText: widget.isEditMode ? 'New Password (optional)' : 'Temporary Password',
                    type: AppTextFormFieldType.password,
                    helperText:
                        widget.isViewMode
                            ? null
                            : (widget.isEditMode ? 'Leave blank to keep current password' : 'User will use this password to log in'),
                    readOnly: isReadOnly,
                    validator:
                        isReadOnly
                            ? null
                            : (value) {
                              if (widget.isEditMode && (value == null || value.isEmpty)) return null;
                              if (value == null || value.isEmpty) {
                                return 'Please enter a temporary password';
                              }
                              if (value.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                              return null;
                            },
                  ),

                  if (widget.isViewMode) ...[
                    Column(
                      children: [
                        SizedBox(height: 200),
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
                                        if (widget.user == null) return;
                                        AppFirebaseService.instance.usersCollection.doc(widget.user?.userId.toString()).delete();
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
                  ],

                  if (!isReadOnly) ...[
                    const SizedBox(height: 32),

                    // Create / Update Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : (widget.isEditMode ? _updateUser : _createUser),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child:
                            _isLoading
                                ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                                )
                                : Text(
                                  widget.isEditMode ? 'Update User' : 'Create User',
                                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                                ),
                      ),
                    ),
                  ],

                  if (widget.isCreateMode) ...[
                    const SizedBox(height: 16),

                    // Additional Info
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_outlined, color: Colors.orange[700], size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'User will be created immediately and can log in with the provided credentials.',
                              style: TextStyle(color: Colors.orange[700], fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
