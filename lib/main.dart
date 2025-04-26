import 'package:get/get_navigation/src/root/get_material_app.dart';
import 'package:secured_calling/app/app.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:secured_calling/core/services/app_local_storage.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await AppLocalStorage.init();
  runApp(const  SecuredCallingApp());
}
