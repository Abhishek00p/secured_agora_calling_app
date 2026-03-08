import 'dart:io';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:secured_calling/core/services/app_firebase_service.dart';

/// Initializes Firebase Crashlytics (Android only). Other platforms use Firestore.
Future<void> initCrashlytics() async {
  if (!Platform.isAndroid) return;
  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
}

/// Sets [FlutterError.onError]: Android → Crashlytics; all other platforms → Firestore (app_crash).
void setCrashlyticsFlutterErrorHandler() {
  FlutterError.onError = (FlutterErrorDetails details) {
    if (Platform.isAndroid) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    } else {
      AppFirebaseService.reportErrorToFirestore(
        exception: details.exceptionAsString(),
        stackTrace: details.stack?.toString() ?? '',
        platform: Platform.operatingSystem,
      );
    }
    FlutterError.presentError(details);
  };
}
