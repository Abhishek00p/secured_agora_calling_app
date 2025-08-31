import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:secured_calling/core/services/app_firebase_service.dart';
import 'package:secured_calling/core/services/app_local_storage.dart';
import 'package:secured_calling/core/models/app_user_model.dart';
import 'package:secured_calling/utils/app_tost_util.dart';
import 'package:secured_calling/widgets/app_text_form_widget.dart';
import 'package:secured_calling/core/theme/app_theme.dart';

class UserCreationForm extends StatefulWidget {
  const UserCreationForm({super.key});

  @override
  State<UserCreationForm> createState() => _UserCreationFormState();
}

class _UserCreationFormState extends State<UserCreationForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  late AppUser _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = AppLocalStorage.getUserDetails();
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
      // Create user in Firebase Auth
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );

      if (!mounted) return;

      // Send email verification
      await userCredential.user?.sendEmailVerification();

      // Create user profile in Firestore
      final userId = await AppFirebaseService.instance.generateUniqueUserId();
      final userData = {
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'userId': userId,
        'memberCode': _currentUser.memberCode,
        'firebaseUserId': userCredential.user!.uid,
        'createdAt': DateTime.now().toIso8601String(),
        'isMember': false, // Regular user, not a member
        'subscription': null,
        'temporaryPassword': _passwordController.text, // Store temporary password
        'passwordCreatedBy': _currentUser.email,
        'passwordCreatedAt': DateTime.now().toIso8601String(),
      };

      // Save user data
      await FirebaseFirestore.instance
          .collection('users')
          .doc('$userId')
          .set(userData);

      // Update member's total users count
      final memberQuery = await FirebaseFirestore.instance
          .collection('members')
          .where('memberCode', isEqualTo: _currentUser.memberCode)
          .get();

      if (memberQuery.docs.isNotEmpty) {
        await memberQuery.docs.first.reference.update({
          'totalUsers': FieldValue.increment(1),
        });
      }

      if (!mounted) return;

      AppToastUtil.showSuccessToast(
        'User created successfully. Please check email for verification.',
      );
      
      // Clear form
      _formKey.currentState!.reset();
      _nameController.clear();
      _emailController.clear();
      _passwordController.clear();
      
      // Return true to indicate successful creation
      Navigator.pop(context, true);
      
    } on FirebaseAuthException catch (e) {
      String message = 'An error occurred';
      if (e.code == 'weak-password') {
        message = 'The password provided is too weak.';
      } else if (e.code == 'email-already-in-use') {
        message = 'An account already exists for that email.';
      } else if (e.code == 'invalid-email') {
        message = 'Invalid email format.';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New User'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
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
                        Icon(Icons.info_outline, color: Colors.blue, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Creating User Under Member Code',
                          style: TextStyle(
                            color: Colors.blue[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Member Code: ${_currentUser.memberCode}',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This user will be automatically associated with your member code and will have access to your meetings.',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Name Field
              AppTextFormField(
                controller: _nameController,
                labelText: 'Full Name',
                type: AppTextFormFieldType.text,
                validator: (value) {
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
                labelText: 'Email',
                type: AppTextFormFieldType.email,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the user\'s email';
                  }
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
              // Password Field
              AppTextFormField(
                controller: _passwordController,
                labelText: 'Temporary Password',
                type: AppTextFormFieldType.password,
                helperText: 'User will be prompted to change this password on first login',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a temporary password';
                  }
                  if (value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 32),
              
              // Create Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createUser,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Create User',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              
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
                        'A verification email will be sent to the user. They must verify their email before they can log in.',
                        style: TextStyle(
                          color: Colors.orange[700],
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
