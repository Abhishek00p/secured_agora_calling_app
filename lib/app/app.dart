import 'package:secured_calling/core/routes/app_router.dart';
import 'package:secured_calling/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DreamFlowApp extends ConsumerWidget {
  const DreamFlowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'DreamFlow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      initialRoute: AppRouter.welcomeRoute,
      onGenerateRoute: AppRouter.generateRoute,
    );
  }
}
