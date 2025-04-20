import 'dart:convert';

import 'package:secured_calling/core/models/app_user_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLocalStorage {
  AppLocalStorage._();
  factory AppLocalStorage() {
    return AppLocalStorage._();
  }
  static late SharedPreferences _preferences;

  // variables constants
  static const String userDetails = 'user-details';
  static const String isUserLoggedIn = 'is-user-logged-in';
  // functions
  static Future<void> init() async {
    _preferences = await SharedPreferences.getInstance();
  }

  static void storeUserDetails(AppUser user) {
    _preferences.setString(userDetails, user.toJson().toString());
  }

  static AppUser getUserDetails() {
    return AppUser.fromJson(
      jsonDecode(_preferences.getString(userDetails) ?? '{}'),
    );
  }

  static void setLoggedIn(bool value) {
    _preferences.setBool(isUserLoggedIn, value);
  }

  static bool getLoggedInStatus() {
    return _preferences.getBool(isUserLoggedIn) ?? false;
  }
}
