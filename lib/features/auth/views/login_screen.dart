import 'package:flutter/material.dart';
import 'package:get/get_state_manager/get_state_manager.dart';
import 'package:secured_calling/widgets/app_text_form_widget.dart';
import 'package:secured_calling/features/auth/views/login_register_controller.dart';
import 'package:secured_calling/core/services/app_firebase_service.dart';
import 'package:secured_calling/utils/app_tost_util.dart';
import 'dart:io' show Platform;

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
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isIOS ? Colors.orange[50] : Colors.orange[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      isIOS ? Icons.info_outline : Icons.info,
                      color: Colors.orange[800],
                      size: isIOS ? 20 : 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'It may take a few minutes to receive the reset password link. Please check your email inbox and spam folder.',
                        style: TextStyle(
                          color: Colors.orange[800],
                          fontSize: isIOS ? 13 : 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (emailController.text.isEmpty) {
                            AppToastUtil.showErrorToast(
                                context, 'Please enter your email');
                            return;
                          }
                          setState(() => isLoading = true);
                          try {
                            final result = await AppFirebaseService.instance
                                .sendResetPasswordEmail(emailController.text.trim());
                            if (result != null && result) {
                              if (context.mounted) {
                                Navigator.pop(context);
                                AppToastUtil.showSuccessToast(
                                    context, 'Reset link sent to your email');
                              }
                            } else {
                              if (context.mounted) {
                                AppToastUtil.showErrorToast(
                                    context, 'Failed to send reset link');
                              }
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
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                AppTextFormField(
                  controller: loginRegisterController.loginEmailController,
                  labelText: 'Email',
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      loginRegisterController.errorMessage.value =
                          'Please enter your email';
                      loginRegisterController.update();
                      return 'Please enter your email';
                    }
                    if (!RegExp(
                      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                    ).hasMatch(value)) {
                      loginRegisterController.errorMessage.value =
                          'Please enter a valid email';
                      loginRegisterController.update();
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AppTextFormField(
                  controller: loginRegisterController.loginPasswordController,
                  labelText: 'Password',
                  prefixIcon: Icons.lock_outline,
                  obscureText:
                      loginRegisterController.obscureLoginPassword.value,
                      onSuffixIconPressed: loginRegisterController.toggleLoginPasswordVisibility,
                  suffixIcon:  
                      loginRegisterController.obscureLoginPassword.value
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    
                
                  
                  validator:
                      (value) =>
                          value == null || value.isEmpty
                              ? 'Please enter your password'
                              : null,
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
                    child: loginRegisterController.isLoading.value
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Log In'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
