import 'package:flutter/material.dart';
import 'package:get/get_state_manager/get_state_manager.dart';
import 'package:secured_calling/features/auth/views/reset_pass_screen.dart';
import 'package:secured_calling/utils/app_logger.dart';
import 'package:secured_calling/widgets/app_text_form_widget.dart';
import 'package:secured_calling/features/auth/views/login_register_controller.dart';

class LoginForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final VoidCallback onSubmit;

  const LoginForm({super.key, required this.formKey, required this.onSubmit});

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
                  suffixIcon: IconButton(
                    icon: Icon(
                      loginRegisterController.obscureLoginPassword.value
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed:
                        loginRegisterController.toggleLoginPasswordVisibility,
                  ),
                  validator:
                      (value) =>
                          value == null || value.isEmpty
                              ? 'Please enter your password'
                              : null,
                ),
              
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(context,MaterialPageRoute(builder: (route)=> ResetPasswordScreen()));
                      // Get.toNamed(AppRouter.resetPasswordRoute);
                    },
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
                    onPressed: () {
                      onSubmit();
                    },
                    child: const Text('Log In'),
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
