import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:secured_calling/core/routes/app_router.dart';
import 'package:secured_calling/core/services/app_local_storage.dart';
import 'package:secured_calling/utils/app_logger.dart';

/// Authentication middleware for GetX routing
/// Handles automatic redirection based on authentication status
class AuthMiddleware extends GetMiddleware {
  @override
  int? get priority => 1;

  @override
  RouteSettings? redirect(String? route) {
    AppLogger.print('AuthMiddleware: Checking route - $route');

    // Routes that don't require authentication
    final publicRoutes = [AppRouter.welcomeRoute, AppRouter.loginRoute];

    // If it's a public route, allow access
    if (publicRoutes.contains(route)) {
      AppLogger.print('AuthMiddleware: Public route, allowing access');
      return null;
    }

    // Check authentication status
    final isLoggedIn = AppLocalStorage.getLoggedInStatus();
    final token = AppLocalStorage.getToken();
    final userDetails = AppLocalStorage.getUserDetails();

    AppLogger.print(
      'AuthMiddleware: Auth check - isLoggedIn: $isLoggedIn, hasToken: ${token != null}, hasUser: ${!userDetails.isEmpty}',
    );

    // If user is not authenticated, redirect to login
    if (!isLoggedIn || token == null || userDetails.isEmpty) {
      AppLogger.print(
        'AuthMiddleware: User not authenticated, redirecting to login',
      );
      return const RouteSettings(name: AppRouter.loginRoute);
    }

    // User appears to be authenticated, allow access
    AppLogger.print('AuthMiddleware: User authenticated, allowing access');
    return null;
  }
}

/// Welcome screen middleware
/// Handles initial authentication check and redirects accordingly
class WelcomeMiddleware extends GetMiddleware {
  @override
  int? get priority => 2;

  @override
  RouteSettings? redirect(String? route) {
    // Only apply this middleware to the welcome route
    if (route != AppRouter.welcomeRoute) {
      return null;
    }

    AppLogger.print('WelcomeMiddleware: Checking authentication status...');

    // Check if user is already logged in
    final isLoggedIn = AppLocalStorage.getLoggedInStatus();
    final token = AppLocalStorage.getToken();
    final userDetails = AppLocalStorage.getUserDetails();

    AppLogger.print(
      'WelcomeMiddleware: Auth check - isLoggedIn: $isLoggedIn, hasToken: ${token != null}, hasUser: ${!userDetails.isEmpty}',
    );

    // If user is authenticated, redirect to home
    if (isLoggedIn && token != null && !userDetails.isEmpty) {
      AppLogger.print(
        'WelcomeMiddleware: User is authenticated, redirecting to home',
      );
      return const RouteSettings(name: AppRouter.homeRoute);
    }

    // User is not authenticated, show welcome screen
    AppLogger.print(
      'WelcomeMiddleware: User not authenticated, showing welcome screen',
    );
    return null;
  }
}

/// Login screen middleware
/// Redirects authenticated users away from login screen
class LoginMiddleware extends GetMiddleware {
  @override
  int? get priority => 2;

  @override
  RouteSettings? redirect(String? route) {
    // Only apply this middleware to the login route
    if (route != AppRouter.loginRoute) {
      return null;
    }

    AppLogger.print(
      'LoginMiddleware: Checking if user is already authenticated...',
    );

    // Check if user is already logged in
    final isLoggedIn = AppLocalStorage.getLoggedInStatus();
    final token = AppLocalStorage.getToken();
    final userDetails = AppLocalStorage.getUserDetails();

    AppLogger.print(
      'LoginMiddleware: Auth check - isLoggedIn: $isLoggedIn, hasToken: ${token != null}, hasUser: ${!userDetails.isEmpty}',
    );

    // If user is authenticated, redirect to home
    if (isLoggedIn && token != null && !userDetails.isEmpty) {
      AppLogger.print(
        'LoginMiddleware: User is already authenticated, redirecting to home',
      );
      return const RouteSettings(name: AppRouter.homeRoute);
    }

    // User is not authenticated, show login screen
    AppLogger.print(
      'LoginMiddleware: User not authenticated, showing login screen',
    );
    return null;
  }
}
