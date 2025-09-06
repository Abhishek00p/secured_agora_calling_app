import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:secured_calling/utils/app_logger.dart';
import 'package:secured_calling/utils/app_tost_util.dart';
import 'package:secured_calling/utils/firebase_debug_util.dart';
import 'package:secured_calling/core/routes/app_router.dart';
import 'package:secured_calling/core/theme/app_theme.dart';
import 'package:secured_calling/features/auth/views/login_register_controller.dart';
import 'package:secured_calling/widgets/app_text_form_widget.dart';

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
              
              // Info Message
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
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
              
              const SizedBox(height: 16),
              
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

  Widget _buildDebugButton(String label, IconData icon, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.orange[100],
        foregroundColor: Colors.orange[800],
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

class LoginForm extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  final VoidCallback onSubmit;

  const LoginForm({
    super.key,
    required this.formKey,
    required this.onSubmit,
  });

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final LoginRegisterController loginRegisterController = Get.find<LoginRegisterController>();

  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.formKey,
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
          
          const SizedBox(height: 32),
          
          // Use Obx for reactive state management
          Obx(() => SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: loginRegisterController.isLoading.value ? null : widget.onSubmit,
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
                      'Login',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          )),
        ],
      ),
    );
  }
}
