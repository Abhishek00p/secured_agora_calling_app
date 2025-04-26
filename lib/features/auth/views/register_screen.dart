import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:secured_calling/app_text_form_widget.dart';
import 'package:secured_calling/features/auth/views/login_register_controller.dart';

class RegisterForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final VoidCallback onSubmit;

  const RegisterForm({
    super.key,
    required this.formKey,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context,) {
    return GetBuilder<LoginRegisterController>(
      builder: (loginRegisterController) {
        return Form(
          key: formKey,
          child: Column(
            children: [
              AppTextFormField(
                controller:loginRegisterController.registerNameController ,
                labelText: 'Full Name',
                prefixIcon: Icons.person_outline,
                validator: (value) => value == null || value.isEmpty ? 'Please enter your name' : null,
              ),
              const SizedBox(height: 16),
              AppTextFormField(
                controller: loginRegisterController.registerEmailController,
                labelText: 'Email',
                prefixIcon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Please enter your email';
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              AppTextFormField(
                controller: loginRegisterController.registerPasswordController,
                labelText: 'Password',
                prefixIcon: Icons.lock_outline,
                obscureText: loginRegisterController.obscureRegisterPassword.value,
                suffixIcon: IconButton(
                  icon: Icon(loginRegisterController.obscureRegisterPassword.value
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: loginRegisterController.toggleRegisterPasswordVisibility,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Please enter a password';
                  if (value.length < 6) return 'Password must be at least 6 characters';
                  return null;
                },
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: loginRegisterController.isLoading.value ? null : onSubmit,
                  child: const Text('Create Account'),
                ),
              ),
            ],
          ),
        );
      }
    );
  }
}
