import 'package:secured_calling/features/auth/views/login_register_screen.dart';
import 'package:secured_calling/features/home/views/home_screen.dart';
import 'package:secured_calling/features/meeting/views/meeting_room.dart';
import 'package:secured_calling/features/welcome/views/welcome_screen.dart';
import 'package:flutter/material.dart';

class AppRouter {
  static const String welcomeRoute = '/welcome';
  static const String loginRegisterRoute = '/auth';
  static const String homeRoute = '/home';
  static const String meetingRoomRoute = '/meeting';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case welcomeRoute:
        return MaterialPageRoute(builder: (_) => const WelcomeScreen());
      case loginRegisterRoute:
        return MaterialPageRoute(builder: (_) => const LoginRegisterScreen());
      case homeRoute:
        return MaterialPageRoute(builder: (_) => const HomeScreen());
      case meetingRoomRoute:
        final Map<String, dynamic> args =
            settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder:
              (_) => MeetingRoom(
                channelName: args['channelName'],
                isHost: args['isHost'] ?? false,
              ),
        );
      default:
        return MaterialPageRoute(
          builder:
              (_) => Scaffold(
                body: Center(
                  child: Text('No route defined for ${settings.name}'),
                ),
              ),
        );
    }
  }
}
