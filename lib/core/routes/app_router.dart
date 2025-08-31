import 'package:get/get.dart';
import 'package:secured_calling/core/models/meeting_model.dart';
import 'package:secured_calling/features/auth/views/login_screen.dart';
import 'package:secured_calling/features/home/views/home_screen.dart';
import 'package:secured_calling/features/welcome/views/welcome_screen.dart';
import 'package:secured_calling/features/admin/admin_home.dart';
import 'package:secured_calling/features/home/views/users_screen.dart';
import 'package:secured_calling/features/home/views/user_creation_form.dart';
import 'package:secured_calling/features/admin/member_form.dart';
import 'package:secured_calling/features/meeting/views/agora_meeting_room.dart';
import 'package:secured_calling/features/meeting/views/meeting_detail_page.dart';
import 'package:secured_calling/features/home/views/view_all_meeting_list.dart';
import 'package:secured_calling/features/meeting/bindings/meeting_binding.dart';
import 'package:secured_calling/features/meeting/bindings/meeting_detail_binding.dart';
import 'package:secured_calling/utils/app_logger.dart';

// (Optional) Import your Bindings here if you create them
import 'package:secured_calling/features/auth/bindings/auth_binding.dart';

class AppRouter {
  // Route constants
  static const String welcomeRoute = '/welcome';
  static const String loginRoute = '/login';
  static const String homeRoute = '/home';
  static const String adminRoute = '/admin';
  static const String usersRoute = '/users';
  static const String userCreationRoute = '/user-creation';
  static const String memberFormRoute = '/member-form';
  
  // Meeting routes
  static const String meetingRoomRoute = '/meeting';
  static const String meetingViewAllRoute = '/meeting/view_all';
  static const String meetingDetailRoute = '/meeting-detail';

  // GetPages
  static final List<GetPage> routes = [
    GetPage(
      name: welcomeRoute,
      page: () => const WelcomeScreen(),
    ),
    GetPage(
      name: loginRoute,
      page: () => const LoginScreen(),
      binding: AuthBinding(),
    ),
    GetPage(
      name: homeRoute,
      page: () => const HomeScreen(),
    ),
    GetPage(
      name: adminRoute,
      page: () => const AdminScreen(),
    ),
    GetPage(
      name: usersRoute,
      page: () => const UsersScreen(),
    ),
    GetPage(
      name: userCreationRoute,
      page: () => const UserCreationForm(),
    ),
    GetPage(
      name: memberFormRoute,
      page: () => const MemberForm(),
    ),
    
    // Meeting routes
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
      binding: MeetingBinding(),
    ),
    GetPage(
      name: meetingViewAllRoute,
      page: () {
        final args = Get.arguments as List<MeetingModel>;
        return ViewAllMeetingList(meetings: args);
      },
      binding: MeetingBinding(),
    ),
    GetPage(
      name: meetingDetailRoute,
      page: () {
        final args = Get.arguments as Map<String, dynamic>;
        return MeetingDetailPage(meetingId: args['meetingId']);
      },
      binding: MeetingDetailBinding(),
    ),
  ];
}
