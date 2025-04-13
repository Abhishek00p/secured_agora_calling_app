import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:secured_calling/app_tost_util.dart';
import 'package:secured_calling/core/routes/app_router.dart';
import 'package:secured_calling/core/services/app_firebase_service.dart';
import 'package:secured_calling/features/home/views/home_screen.dart';

final userControllerProvider = StateNotifierProvider<UserController, AsyncValue<Map<String, dynamic>?>>(
  (ref) => UserController(ref),
);

class UserController extends StateNotifier<AsyncValue<Map<String, dynamic>?>> {
  final Ref ref;
  final AppFirebaseService _firebaseService = AppFirebaseService.instance;

  UserController(this.ref) : super(const AsyncLoading()) {
    loadUserData();
  }

  Future<void> loadUserData() async {
    try {
      final user = _firebaseService.currentUser;
      if (user != null) {
        final userData = await _firebaseService.getUserData(user.uid);
        final data = userData.data() as Map<String, dynamic>?;
        state = AsyncData(data);

        // Set user type based on membership
        if (data != null && data['isMember'] == true) {
          ref.read(userTypeProvider.notifier).state = UserType.member;
        } else {
          ref.read(userTypeProvider.notifier).state = UserType.user;
        }
      } else {
        state = const AsyncData(null);
      }
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> signOut(BuildContext context) async {
    try {
      await _firebaseService.signOut();
      if (context.mounted) {
        Navigator.pushReplacementNamed(context, AppRouter.welcomeRoute);
      }
    } catch (e) {
      AppToastUtil.showErrorToast(context, 'Error signing out: $e');
    }
  }
  
  User? get user => _firebaseService.currentUser;
}
