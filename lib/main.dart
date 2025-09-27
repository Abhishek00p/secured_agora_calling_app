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
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Configure Firebase emulators for local development
  // if (const bool.fromEnvironment('dart.vm.product') == false) {
  //   // Only use emulators in debug mode
  //   try {
  //     // Configure Firestore emulator
  //     FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);

  //     // Configure Auth emulator
  //     await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);

  //     // Configure Functions emulator
  //     FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001);

  //     print('🔥 Firebase emulators configured for local development');
  //   } catch (e) {
  //     print('⚠️  Could not connect to Firebase emulators: $e');
  //     print('   Make sure Firebase emulators are running with: firebase emulators:start');
  //   }
  // }

  await AppLocalStorage.init();

  // Initialize AppLifecycleManager
  Get.put(AppLifecycleManager());
  // Initialize AppSoundService
  await AppSoundService().initialize();

  runApp(const App());
}
