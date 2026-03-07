import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:secured_calling/app/app.dart';
import 'package:secured_calling/core/services/app_local_storage.dart';
import 'package:secured_calling/core/services/app_lifecycle_manager.dart';
import 'package:secured_calling/core/services/app_sound_service.dart';
import 'package:secured_calling/core/services/download_manager_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:secured_calling/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    debugPrint("Firebase initialization error: $e");
  }
  await AppLocalStorage.init();
  await DownloadManagerService.instance.initialize();
  // Check if the app was launched by tapping a download notification while
  // the process was terminated. The navigation itself runs post-first-frame.
  await DownloadManagerService.instance.prepareLaunchNavigation();
  Get.put(AppLifecycleManager());
  await AppSoundService().initialize();
  runApp(const App());
}
