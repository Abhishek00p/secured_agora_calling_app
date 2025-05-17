import 'package:get/get.dart';
import 'package:secured_calling/utils/app_logger.dart';
import 'package:secured_calling/utils/app_tost_util.dart';
import 'package:secured_calling/core/routes/app_router.dart';
import 'package:secured_calling/core/services/app_local_storage.dart';
import 'package:secured_calling/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:secured_calling/features/auth/views/login_register_controller.dart';
import 'package:secured_calling/features/auth/views/login_screen.dart';
import 'package:secured_calling/features/auth/views/register_screen.dart';

class LoginRegisterScreen extends StatefulWidget {
  const LoginRegisterScreen({super.key});

  @override
  State<LoginRegisterScreen> createState() => _LoginRegisterScreenState();
}

class _LoginRegisterScreenState extends State<LoginRegisterScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GlobalKey<FormState> _loginFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _registerFormKey = GlobalKey<FormState>();

  int currentTab = 0;
  late List<Widget> _tabs;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabs = [
      LoginForm(
        formKey: _loginFormKey,
        onSubmit: () {
          _login();
        },
      ),
      RegisterForm(
        formKey: _registerFormKey,
        onSubmit: () => _register(),
      ),
    ];
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final loginRegisterController = Get.find<LoginRegisterController>();
    AppLogger.print("login button preseed in ui");
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

  Future<void> _register() async {
    final loginRegisterController = Get.find<LoginRegisterController>();
    if (_registerFormKey.currentState!.validate()) {
      try {
        final result = await loginRegisterController.register(
      
        );

        if (loginRegisterController.errorMessage.value != null) {
          AppToastUtil.showErrorToast(loginRegisterController.errorMessage.value!);
          return;
        }

        AppToastUtil.showSuccessToast(
          'Registration successful! Please check your email for verification.',
        );
        Get.back();
      } catch (e) {
        AppToastUtil.showErrorToast('Registration Failed...');
      }
    } else {
      AppToastUtil.showErrorToast('Form Invalid');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GetBuilder<LoginRegisterController>(
        builder: (loginRegisterController) {
          return Container(
            height: Get.height,
            width: Get.width,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Theme.of(context).colorScheme.surface,
                  Theme.of(context).colorScheme.surface,
                ],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: Get.height - 48, // Account for padding
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // App Logo
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Icons.call,
                            size: 40,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // App Name
                        Text('SecuredCalling', style: TextStyle(fontSize: 24)),
                        const SizedBox(height: 36),

                        // Tab Bar
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TabBar(
                            controller: _tabController,
                            padding: EdgeInsets.all(16),
                            indicator: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: AppTheme.primaryColor,
                            ),
                            indicatorSize: TabBarIndicatorSize.tab,
                            labelColor: Colors.white,
                            unselectedLabelColor:
                                Theme.of(context).textTheme.bodyLarge?.color,
                            labelStyle: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                            dividerColor: Colors.transparent,
                            tabs: const [
                              Tab(text: 'Login'),
                              Tab(text: 'Register'),
                            ],

                            onTap: (e){
                              setState(() {
                                currentTab = e;
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Error Message
                        if (loginRegisterController.errorMessage.value !=
                                null &&
                            loginRegisterController
                                .errorMessage
                                .string
                                .isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.errorColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppTheme.errorColor.withOpacity(0.5),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: AppTheme.errorColor,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    loginRegisterController.errorMessage.string,
                                    style: TextStyle(
                                      color: AppTheme.errorColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                        // Tab Views
                        _tabs[_tabController.index],

                        // Animated Loading Indicator
                        if (loginRegisterController.isLoading.value) ...[
                          const SizedBox(height: 24),
                          const Center(child: CircularProgressIndicator()),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
