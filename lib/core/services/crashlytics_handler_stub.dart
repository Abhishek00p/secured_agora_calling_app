/// Stub implementation of Crashlytics handler for non-IO platforms (e.g. web).
/// The real implementation in [crashlytics_handler_io.dart] runs only on Android.

Future<void> initCrashlytics() async {}

void setCrashlyticsFlutterErrorHandler() {}
