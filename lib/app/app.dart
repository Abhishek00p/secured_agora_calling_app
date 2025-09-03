import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:secured_calling/core/routes/app_router.dart';
import 'package:secured_calling/core/theme/app_theme.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'SecuredCalling',
      theme: AppTheme.lightTheme,
      // darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      initialRoute: AppRouter.welcomeRoute,
      getPages: AppRouter.routes,
      debugShowCheckedModeBanner: false,
    );
  }
}
