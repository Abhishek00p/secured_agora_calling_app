import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:secured_calling/app/app.dart';
import 'package:secured_calling/core/services/app_local_storage.dart';
import 'package:secured_calling/core/services/app_session_expired_handler.dart';
import 'package:secured_calling/core/services/http_service.dart';
import 'package:secured_calling/core/services/app_lifecycle_manager.dart';
import 'package:secured_calling/core/services/app_sound_service.dart';
import 'package:secured_calling/core/services/download_manager_service.dart';
import 'package:secured_calling/core/services/crashlytics_handler_stub.dart'
    if (dart.library.io) 'package:secured_calling/core/services/crashlytics_handler_io.dart'
    as crashlytics_handler;
import 'package:firebase_core/firebase_core.dart';
import 'package:secured_calling/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  try {
    // Firebase Crashlytics for Flutter errors (Android only); backend webhook handles the rest.
    await crashlytics_handler.initCrashlytics();
    crashlytics_handler.setCrashlyticsFlutterErrorHandler();
  } catch (e) {
    debugPrint("Firebase Crashlytics initialization error: $e");
  }

  await AppLocalStorage.init();
  AppHttpService.setSessionExpiredHandler(AppSessionExpiredHandler.handleSessionExpired);
  await DownloadManagerService.instance.initialize();
  // Check if the app was launched by tapping a download notification while
  // the process was terminated. The navigation itself runs post-first-frame.
  await DownloadManagerService.instance.prepareLaunchNavigation();
  Get.put(AppLifecycleManager());
  await AppSoundService().initialize();
  runApp(const App());
}
