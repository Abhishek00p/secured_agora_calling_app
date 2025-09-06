import 'package:flutter/material.dart';
import 'package:secured_calling/app/app.dart';
import 'package:secured_calling/core/services/app_local_storage.dart';
import 'package:secured_calling/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Configure Firebase emulators for local development
  if (const bool.fromEnvironment('dart.vm.product') == false) {
    // Only use emulators in debug mode
    try {
      // Configure Firestore emulator
      FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
      
      // Configure Auth emulator
      await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
      
      // Configure Functions emulator
      FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001);
      
      print('🔥 Firebase emulators configured for local development');
    } catch (e) {
      print('⚠️  Could not connect to Firebase emulators: $e');
      print('   Make sure Firebase emulators are running with: firebase emulators:start');
    }
  }
  
  await AppLocalStorage.init();
  runApp(const App());
}
