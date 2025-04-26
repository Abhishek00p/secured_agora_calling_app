import 'package:get/get_state_manager/src/simple/get_state.dart';
import 'package:secured_calling/app_logger.dart';
import 'package:secured_calling/app_tost_util.dart';
import 'package:secured_calling/core/routes/app_router.dart';
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _login(LoginRegisterController loginRegisterController) async {
    AppLogger.print("login button preseed in ui");
    if (!_loginFormKey.currentState!.validate()) return;
    loginRegisterController.update();
    final result = await loginRegisterController.login(context: context);

    if (result == null) {
      Navigator.pushReplacementNamed(context, AppRouter.homeRoute);
    } else {
      AppToastUtil.showErrorToast(context, result);
    }
  }

  Future<void> _register(
    LoginRegisterController loginRegisterController,
  ) async {
    if (!_registerFormKey.currentState!.validate()) return;
    loginRegisterController.register();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GetBuilder<LoginRegisterController>(
        builder: (loginRegisterController) {
          return Container(
            width: double.infinity,
            height: double.infinity,
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
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
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
                            Icons.video_call_rounded,
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
                            color: Theme.of(context).cardTheme.color,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TabBar(
                            controller: _tabController,
                            indicatorPadding: EdgeInsets.all(8),
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
                            tabs: const [
                              Tab(text: 'Login'),
                              Tab(text: 'Register'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Error Message
                        // if (loginRegisterController.errorMessage.string.isNotEmpty) ...[
                        //   Container(
                        //     padding: const EdgeInsets.all(12),
                        //     decoration: BoxDecoration(
                        //       color: AppTheme.errorColor.withOpacity(0.1),
                        //       borderRadius: BorderRadius.circular(8),
                        //       border: Border.all(
                        //         color: AppTheme.errorColor.withOpacity(0.5),
                        //       ),
                        //     ),
                        //     child: Row(
                        //       children: [
                        //         const Icon(
                        //           Icons.error_outline,
                        //           color: AppTheme.errorColor,
                        //         ),
                        //         const SizedBox(width: 12),
                        //         Expanded(
                        //           child: Text(
                        //             loginRegisterController.errorMessage.string,
                        //             style: TextStyle(color: AppTheme.errorColor),
                        //           ),
                        //         ),
                        //       ],
                        //     ),
                        //   ),
                        //   const SizedBox(height: 24),
                        // ],

                        // Tab Views
                        Expanded(
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              LoginForm(
                                formKey: _loginFormKey,
                                onSubmit: () {
                                  _login(loginRegisterController);
                                },
                              ),
                              RegisterForm(
                                formKey: _registerFormKey,
                                onSubmit: () => _register,
                              ),
                            ],
                          ),
                        ),

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
