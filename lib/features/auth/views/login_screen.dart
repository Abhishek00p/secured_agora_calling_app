import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:secured_calling/app_text_form_widget.dart';
import 'package:secured_calling/features/auth/views/login_register_controller.dart';

class LoginForm extends ConsumerWidget {
  final GlobalKey<FormState> formKey;
  final VoidCallback onSubmit;

  const LoginForm({
    super.key,
    required this.formKey,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
  final state = ref.watch(loginRegisterControllerProvider);
  final notifier = ref.read(loginRegisterControllerProvider.notifier);

  final emailController = ref.watch(loginEmailControllerProvider);
  final passwordController = ref.watch(loginPasswordControllerProvider);
    return Form(
      key: formKey,
      child: Column(
        children: [
          AppTextFormField(
            controller: emailController,
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
            controller: passwordController,
            labelText: 'Password',
            prefixIcon: Icons.lock_outline,
            obscureText: state.obscureLoginPassword,
            suffixIcon: IconButton(
              icon: Icon(state.obscureLoginPassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined),
              onPressed: notifier.toggleLoginPasswordVisibility,
            ),
            validator: (value) => value == null || value.isEmpty ? 'Please enter your password' : null,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: state.isLoading ? null : onSubmit,
              child: const Text('Log In'),
            ),
          ),
        ],
      ),
    );
  }
}
