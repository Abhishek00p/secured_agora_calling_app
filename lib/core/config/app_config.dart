import 'package:firebase_remote_config/firebase_remote_config.dart';

class AppConfig {
  static String _baseUrl = 'api.yourapp.com'; // Fallback value

  static String get baseUrl => _baseUrl;

  static Future<void> initializeRemoteConfig() async {
    final remoteConfig = FirebaseRemoteConfig.instance;

    try {
      // Fetch and activate values from the Firebase service
      await remoteConfig.fetchAndActivate();

      // Get the base URL value
      _baseUrl = remoteConfig.getString('api_base_url').trim() + '/';
      print('Base URL set to: $_baseUrl');
    } catch (e) {
      // Handle exceptions, e.g., no internet connection
      print("Error fetching remote config: $e");
    }
  }
}
