import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:secured_calling/app/app.dart';
import 'package:secured_calling/core/services/app_local_storage.dart';
import 'package:secured_calling/core/services/app_lifecycle_manager.dart';
import 'package:secured_calling/core/services/app_sound_service.dart';
import 'package:secured_calling/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();



  await AppLocalStorage.init();
  // Initialize AppLifecycleManager
  Get.put(AppLifecycleManager());
  // Initialize AppSoundService
  await AppSoundService().initialize();
  runApp(const App());
}
