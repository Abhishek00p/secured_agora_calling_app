import 'dart:io';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Initializes Firebase Crashlytics and sets the Flutter error handler.
/// Only runs on Android; no-op on other platforms.
Future<void> initCrashlytics() async {
  if (!Platform.isAndroid) return;
  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
}

/// Sets [FlutterError.onError] to report Flutter framework errors to Crashlytics
/// with stack trace. Only runs on Android.
void setCrashlyticsFlutterErrorHandler() {
  if (!Platform.isAndroid) return;
  FlutterError.onError = (FlutterErrorDetails details) {
    FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    FlutterError.presentError(details);
  };
}
