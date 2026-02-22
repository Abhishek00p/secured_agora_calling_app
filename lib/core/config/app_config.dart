import 'package:firebase_remote_config/firebase_remote_config.dart';

import '../../utils/app_logger.dart';

class AppConfig {
  static String _baseUrl = 'api.yourapp.com'; // Fallback value

  static String get baseUrl => _baseUrl;

  static Future<void> initializeRemoteConfig() async {
    final remoteConfig = FirebaseRemoteConfig.instance;

    try {
      await remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: Duration(seconds: 5), // 👈 IMPORTANT
        ),
      );
      // Fetch and activate values from the Firebase service
      await remoteConfig.fetchAndActivate();

      // Get the base URL value
      _baseUrl = remoteConfig.getString('api_base_url').trim();
      AppLogger.print('Base URL set to: $_baseUrl');
    } catch (e) {
      // Handle exceptions, e.g., no internet connection
      AppLogger.print("Error fetching remote config: $e");
    }
  }
}
