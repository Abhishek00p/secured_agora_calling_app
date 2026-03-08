import 'package:flutter/foundation.dart';
import 'package:secured_calling/core/services/app_firebase_service.dart';

/// Stub used on web (no dart:io). No Crashlytics; report Flutter errors to Firestore only.
Future<void> initCrashlytics() async {}

/// Sets [FlutterError.onError] to report to Firestore (app_crash) on web.
void setCrashlyticsFlutterErrorHandler() {
  FlutterError.onError = (FlutterErrorDetails details) {
    AppFirebaseService.reportErrorToFirestore(
      exception: details.exceptionAsString(),
      stackTrace: details.stack?.toString() ?? '',
      platform: 'web',
    );
    FlutterError.presentError(details);
  };
}
