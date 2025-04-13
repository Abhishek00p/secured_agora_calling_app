import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:secured_calling/app_text_form_widget.dart';
import 'package:secured_calling/features/auth/views/login_register_controller.dart';

class RegisterForm extends ConsumerWidget {
  final GlobalKey<FormState> formKey;
  final VoidCallback onSubmit;

  const RegisterForm({
    super.key,
    required this.formKey,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(loginRegisterControllerProvider);
    final notifier = ref.read(loginRegisterControllerProvider.notifier);

    return Form(
      key: formKey,
      child: Column(
        children: [
          AppTextFormField(
            controller: ref.read(registerNameControllerProvider),
            labelText: 'Full Name',
            prefixIcon: Icons.person_outline,
            validator: (value) => value == null || value.isEmpty ? 'Please enter your name' : null,
          ),
          const SizedBox(height: 16),
          AppTextFormField(
            controller: ref.read(registerEmailControllerProvider),
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
            controller: ref.read(registerPasswordControllerProvider),
            labelText: 'Password',
            prefixIcon: Icons.lock_outline,
            obscureText: state.obscureRegisterPassword,
            suffixIcon: IconButton(
              icon: Icon(state.obscureRegisterPassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined),
              onPressed: notifier.toggleRegisterPasswordVisibility,
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
              onPressed: state.isLoading ? null : onSubmit,
              child: const Text('Create Account'),
            ),
          ),
        ],
      ),
    );
  }
}
