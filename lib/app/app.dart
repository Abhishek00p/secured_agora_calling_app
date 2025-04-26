import 'package:get/route_manager.dart';
import 'package:secured_calling/core/routes/app_router.dart';
import 'package:secured_calling/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class SecuredCallingApp extends StatelessWidget {
  const SecuredCallingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'SecuredCalling',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      initialRoute: AppRouter.welcomeRoute,
      getPages: AppRouter.routes,
    );
  }
}
