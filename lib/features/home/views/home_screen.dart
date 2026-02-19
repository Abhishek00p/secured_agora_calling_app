import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:secured_calling/core/extensions/app_int_extension.dart';
import 'package:secured_calling/core/extensions/app_string_extension.dart';
import 'package:secured_calling/core/extensions/app_color_extension.dart';
import 'package:secured_calling/core/extensions/date_time_extension.dart';
import 'package:secured_calling/core/models/app_user_model.dart';
import 'package:secured_calling/core/routes/app_router.dart';
import 'package:secured_calling/core/services/app_firebase_service.dart';

import 'package:secured_calling/core/services/app_local_storage.dart';
import 'package:secured_calling/core/services/app_user_role_service.dart';
import 'package:secured_calling/core/services/notification_service.dart';
import 'package:secured_calling/core/services/permission_service.dart';
import 'package:secured_calling/core/theme/app_theme.dart';
import 'package:secured_calling/core/utils/responsive_utils.dart';
import 'package:secured_calling/features/admin/admin_home.dart';
import 'package:secured_calling/features/home/network_log_screen.dart';
import 'package:secured_calling/features/home/views/membar_tab_view_widget.dart';
import 'package:secured_calling/features/home/views/user_tab.dart';
import 'package:secured_calling/features/home/views/users_screen.dart';
import 'package:flutter/material.dart';
import 'package:secured_calling/utils/app_logger.dart';
import 'package:secured_calling/utils/app_tost_util.dart';

enum UserType { user, member }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<Widget> _pages = [MembarTabViewWidget(), UserTab()];
  int _selectedIndex = 0;

  int poppedTimes = 0;

  void _showNotificationPermissionSheet(BuildContext context) async {
    final result = await PermissionService.requestPermission(context: context, type: AppPermissionType.notification);
    if (result) {
      return; // Permission granted, no need to show the sheet
    }
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder:
          (_) => Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Enable Notifications", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 10),
                Text(
                  "We use notifications to remind you of meetings, alerts, and important messages. You can enable them now or later.",
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 20),
                ElevatedButton.icon(
                  icon: Icon(Icons.notifications),
                  label: Text("Enable Notifications"),
                  onPressed: () async {
                    Navigator.pop(context);
                    // await NotificationService()
                    //     .requestPermissionAndInitialize();
                  },
                ),
                TextButton(onPressed: () => Navigator.pop(context), child: Text("Maybe later")),
              ],
            ),
          ),
    );
  }

  AppUser user = AppUser.toEmpty();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadUserData();
    });
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _selectedIndex = _tabController.index;
        });
      }
    });
  }

  Future<void> loadUserData() async {
    try {
      final userId = AppLocalStorage.getUserDetails().userId.toString();
      AppLogger.print("app firebase : ${Firebase.apps.map((e) => e.name)} --- > userId :$userId");
      final data = await AppFirebaseService.instance.getUserData(userId);
      final userData = data.data() as Map<String, dynamic>? ?? {};
      AppLogger.print("User data fetched in home screen : $userData");
      setState(() {
        user = AppUser.fromJson(userData);
      });
    } catch (e) {
      AppLogger.print("error while fetching user data in home screen : $e");
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (poppedTimes == 0) {
          setState(() {
            poppedTimes++;
          });
          AppToastUtil.showInfoToast(title: 'Exit Confirmation', 'Press back again to exit the app');

          // Reset after a short delay (to avoid double count after timeout)
          Future.delayed(const Duration(seconds: 2), () {
            poppedTimes = 0;
          });
        } else {
          // Exit the app
          SystemNavigator.pop(); // or use exit(0) from 'dart:io' if needed
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('SecuredCalling'),

          actions: [
            PopupMenuButton<String>(
              offset: Offset(0, 50),
              icon: const Icon(Icons.logout_rounded), // You can use Icons.exit_to_app if preferred
              onSelected: (value) async {
                if (value == 'sign_out') {
                  if (await AppLocalStorage.signOut(context)) {
                    Navigator.pushReplacementNamed(context, AppRouter.welcomeRoute);
                  }
                }
              },
              itemBuilder:
                  (BuildContext context) => <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(
                      value: 'sign_out',
                      padding: EdgeInsets.zero,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [8.w, Text('Sign Out'), 10.w, const Icon(Icons.logout_rounded, color: Colors.red)],
                      ),
                    ),
                  ],
            ),

            if (kDebugMode) ...[
              IconButton(
                onPressed: () {
                  Get.to(() => NetworkLogScreen());
                },
                icon: Icon(Icons.show_chart_rounded),
              ),
            ],
          ],
          leading:
              !AppUserRoleService.isAdmin() && !AppUserRoleService.isMember()
                  ? null
                  : IconButton(
                    icon: const Icon(Icons.people_alt_outlined),
                    onPressed: () {
                      if (AppUserRoleService.isAdmin()) {
                        // Admin navigation
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminScreen()));
                      } else if (AppUserRoleService.isMember()) {
                        // Member navigation
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const UsersScreen()));
                      }
                    },
                    tooltip: AppUserRoleService.isAdmin() ? 'Admin Section' : 'View Associated Users',
                  ),
        ),

        body: LayoutBuilder(
          builder: (context, constraints) {
            final padding = responsivePadding(context);
            final maxWidth = (context.layoutType != AppLayoutType.mobile) ? 700.0 : double.infinity;
            return SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: Column(
                    children: [
                      // User profile card
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(padding),
                        margin: EdgeInsets.all(padding),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(user.name.titleCase, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 4),
                    if (user.memberCode.isNotEmpty) ...[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Code: ${user.memberCode}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                          4.w,
                          IconButton(
                            icon: const Icon(Icons.copy, color: Colors.white, size: 14),
                            padding: EdgeInsets.zero,

                            onPressed: () {
                              // Copy member code to clipboard
                              Clipboard.setData(ClipboardData(text: user.memberCode));
                              AppToastUtil.showSuccessToast('Member code copied to clipboard');
                            },
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white.withAppOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                      child: Text(
                        'Role : ${AppUserRoleService.getCurrentUserRoleDisplayName()}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 12),
                      ),
                    ),

                    if (!user.subscription.isEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        // mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Plan: ${user.subscription.plan}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          8.w,
                          Text(
                            'Expires: ${user.subscription.expiryDate.formatDate ?? 'N/A'}',
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

                      // Tab Bar
                      Container(
                        margin: EdgeInsets.symmetric(horizontal: padding),
                        decoration: BoxDecoration(color: Theme.of(context).cardTheme.color, borderRadius: BorderRadius.circular(12)),
                // height: 50,
                // width: double.infinity,
                        child: TabBar(
                          onTap: (index) {
                            setState(() {
                              _selectedIndex = index;
                            });
                          },
                          controller: _tabController,
                          indicatorSize: TabBarIndicatorSize.tab,
                          indicator: BoxDecoration(borderRadius: BorderRadius.circular(12), color: AppTheme.primaryColor),
                          labelColor: Colors.white,
                          indicatorPadding: EdgeInsets.all(8),
                          dividerColor: Colors.transparent,
                          unselectedLabelColor: Theme.of(context).textTheme.bodyLarge?.color,
                          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                          tabs: const [Tab(icon: Icon(Icons.video_call), text: 'Host Meeting'), Tab(icon: Icon(Icons.people), text: 'Join Meeting')],
                        ),
                      ),
                      const Divider(),
                      // Tab content
                      _pages[_selectedIndex],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
