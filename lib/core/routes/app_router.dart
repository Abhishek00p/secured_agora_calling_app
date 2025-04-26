
import 'package:get/get.dart';
import 'package:secured_calling/app_logger.dart';
import 'package:secured_calling/features/auth/views/login_register_screen.dart';
import 'package:secured_calling/features/home/views/home_screen.dart';
import 'package:secured_calling/features/meeting/views/agora_meeting_room.dart';
import 'package:secured_calling/features/welcome/views/welcome_screen.dart';

// (Optional) Import your Bindings here if you create them
import 'package:secured_calling/features/auth/bindings/auth_binding.dart';
import 'package:secured_calling/features/meeting/bindings/meeting_binding.dart';

class AppRouter {
  static const String welcomeRoute = '/welcome';
  static const String loginRegisterRoute = '/auth';
  static const String homeRoute = '/home';
  static const String meetingRoomRoute = '/meeting';

  static List<GetPage> routes = [
    GetPage(
      name: welcomeRoute,
      page: () => const WelcomeScreen(),
    ),
    GetPage(
      name: loginRegisterRoute,
      page: () => const LoginRegisterScreen(),
      binding: AuthBinding(), // Inject Auth Controller
    ),
    GetPage(
      name: homeRoute,
      page: () => const HomeScreen(),
      // binding: HomeBinding(), // Inject Home Controller
    ),
    GetPage(
      name: meetingRoomRoute,
      page: () {
        final args = Get.arguments as Map<String, dynamic>;
        AppLogger.print(args.toString());
        return AgoraMeetingRoom(
          channelName: args['channelName'],
          isHost: args['isHost'] ?? false,
          meetingId: args['meetingId'] ?? '',
        );
      },
      binding: MeetingBinding( 
   ), // Inject Meeting Controller
    ),
  ];
}
