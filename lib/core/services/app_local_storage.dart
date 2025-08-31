import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:secured_calling/utils/app_logger.dart';
import 'package:secured_calling/utils/app_tost_util.dart';
import 'package:secured_calling/core/models/app_user_model.dart';
import 'package:secured_calling/core/services/app_firebase_service.dart';
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
    AppLogger.print("storing user details in local storage : ${user.toJson()}");
    _preferences.setString(userDetails, jsonEncode(user.toJson()));
  }

  static AppUser getUserDetails() {
    try {
      final details = _preferences.getString(userDetails);
      return AppUser.fromJson(
        jsonDecode(details ?? '{}'),
      );
    } catch (e) {
      AppLogger.print("error while fetching user detail from local  : $e");
      return AppUser.toEmpty();
    }
  }

  static void setLoggedIn(bool value) {
    _preferences.setBool(isUserLoggedIn, value);
  }

  static bool getLoggedInStatus() {
    return _preferences.getBool(isUserLoggedIn) ?? false;
  }

  static Future<bool> signOut(BuildContext context) async {
    try {
      setLoggedIn(false);
      _preferences.clear();
      return await AppFirebaseService.instance.signOut();
    } catch (e) {
      AppToastUtil.showErrorToast('Error signing out: $e');
      return false;
    }
  }
}
