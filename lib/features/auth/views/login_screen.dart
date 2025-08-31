import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:secured_calling/utils/app_logger.dart';
import 'package:secured_calling/utils/app_tost_util.dart';
import 'package:secured_calling/core/routes/app_router.dart';
import 'package:secured_calling/core/theme/app_theme.dart';
import 'package:secured_calling/features/auth/views/login_register_controller.dart';
import 'package:secured_calling/widgets/app_text_form_widget.dart';
import 'package:secured_calling/core/services/app_firebase_service.dart';
import 'dart:io' show Platform;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _loginFormKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Login'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppTheme.primaryColor,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              // App Logo
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.call, size: 40, color: Colors.white),
                ),
              ),
              const SizedBox(height: 32),
              
              // Welcome Text
              Text(
                'Welcome Back',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sign in to continue to SecuredCalling',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 40),
              
              // Login Form
              LoginForm(
                formKey: _loginFormKey,
                onSubmit: _login,
              ),
              
              const SizedBox(height: 24),
              
              // Info Text
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'New users must be registered by a member or admin. Please contact your organization for access.',
                        style: TextStyle(
                          color: Colors.blue[700],
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

  Future<void> _login() async {
    final loginRegisterController = Get.find<LoginRegisterController>();
    AppLogger.print("login button pressed in ui");
    if (!_loginFormKey.currentState!.validate()) {
      AppToastUtil.showErrorToast('Form Invalid');
      return;
    }
    loginRegisterController.update();
    final result = await loginRegisterController.login(context: context);

    if (result == null) {
      Navigator.pushReplacementNamed(context, AppRouter.homeRoute);
    } else {
      AppToastUtil.showErrorToast(result);
    }
  }
}

class LoginForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final VoidCallback onSubmit;

  const LoginForm({super.key, required this.formKey, required this.onSubmit});

  void _showResetPasswordBottomSheet(BuildContext context) {
    final emailController = TextEditingController();
    bool isLoading = false;
    final isIOS = Platform.isIOS;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isIOS ? Colors.white : Theme.of(context).bottomSheetTheme.backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(isIOS ? 12 : 20),
        ),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: isIOS ? 16 : 24,
            right: isIOS ? 16 : 24,
            top: isIOS ? 8 : 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isIOS) ...[
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 8, bottom: 16),
                    width: 36,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                ),
              ],
              Text(
                'Reset Password',
                style: TextStyle(
                  fontSize: isIOS ? 17 : 20,
                  fontWeight: isIOS ? FontWeight.w600 : FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Enter your email address and we\'ll send you a link to reset your password.',
                style: TextStyle(
                  color: isIOS ? Colors.grey[600] : Colors.grey,
                  fontSize: isIOS ? 15 : 14,
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(
                    Icons.email_outlined,
                    color: isIOS ? Colors.grey[600] : null,
                  ),
                  border: const OutlineInputBorder() ,
                  filled: true,
                  fillColor:  Colors.grey[100] ,
                ),
                keyboardType: TextInputType.emailAddress,
                style: TextStyle(
                  fontSize: isIOS ? 17 : 16,
                ),
                enabled: true,
                
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : () async {
                    if (emailController.text.trim().isEmpty) {
                      AppToastUtil.showErrorToast('Please enter your email');
                      return;
                    }
                    
                    setState(() => isLoading = true);
                    try {
                      await AppFirebaseService.instance.auth.sendPasswordResetEmail(
                        email: emailController.text.trim(),
                      );
                      if (context.mounted) {
                        Navigator.pop(context);
                        AppToastUtil.showSuccessToast(
                          'Password reset link sent to your email');
                      }
                    } catch (e) {
                      if (context.mounted) {
                        AppToastUtil.showErrorToast(
                          'Failed to send reset link');
                      }
                    } finally {
                      if (context.mounted) {
                        setState(() => isLoading = false);
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      vertical: isIOS ? 12 : 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(isIOS ? 8 : 12),
                    ),
                  ),
                  child: isLoading
                      ? SizedBox(
                          height: isIOS ? 18 : 20,
                          width: isIOS ? 18 : 20,
                          child: CircularProgressIndicator(
                            strokeWidth: isIOS ? 2.5 : 2,
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          'Send Reset Link',
                          style: TextStyle(
                            fontSize: isIOS ? 17 : 16,
                            fontWeight: isIOS ? FontWeight.w600 : FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<LoginRegisterController>(
      builder: (loginRegisterController) {
        return Form(
          key: formKey,
          child: Column(
            children: [
              AppTextFormField(
                controller: loginRegisterController.loginEmailController,
                labelText: 'Email',
                type: AppTextFormFieldType.email,
              ),
              const SizedBox(height: 16),
              AppTextFormField(
                controller: loginRegisterController.loginPasswordController,
                labelText: 'Password',
                type: AppTextFormFieldType.password,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _showResetPasswordBottomSheet(context),
                  child: const Text(
                    'Forgot Password?',
                    style: TextStyle(color: Colors.blue),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: loginRegisterController.isLoading.value ? null : onSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: loginRegisterController.isLoading.value
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Log In',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
