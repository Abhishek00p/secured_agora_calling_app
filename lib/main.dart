import 'package:flutter/material.dart';
import 'package:secured_calling/app/app.dart';
import 'package:secured_calling/core/services/app_local_storage.dart';
import 'package:secured_calling/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await AppLocalStorage.init();
  runApp(const App());
}
