import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:secured_calling/core/routes/app_router.dart';
import 'package:secured_calling/core/services/download_manager_service.dart';
import 'package:secured_calling/core/theme/app_theme.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  @override
  void initState() {
    super.initState();
    // After the first frame is painted the GetX route stack is ready.
    // Navigate to any meeting page that was pending from a notification tap
    // that launched a previously-terminated app.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DownloadManagerService.instance.navigateToPendingIfAny();
    });
  }

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'SecuredCalling',
      theme: AppTheme.lightTheme,
      themeMode: ThemeMode.system,
      initialRoute: AppRouter.welcomeRoute,
      getPages: AppRouter.routes,
      debugShowCheckedModeBanner: false,
    );
  }
}
