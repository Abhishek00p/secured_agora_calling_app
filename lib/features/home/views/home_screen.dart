import 'package:flutter/services.dart';
import 'package:secured_calling/core/extensions/app_int_extension.dart';
import 'package:secured_calling/core/extensions/app_string_extension.dart';
import 'package:secured_calling/core/extensions/date_time_extension.dart';
import 'package:secured_calling/core/routes/app_router.dart';
import 'package:secured_calling/core/services/app_firebase_service.dart';
import 'package:secured_calling/core/services/app_local_storage.dart';
import 'package:secured_calling/core/theme/app_theme.dart';
import 'package:secured_calling/features/admin/admin_home.dart';
import 'package:secured_calling/features/home/views/membar_tab_view_widget.dart';
import 'package:secured_calling/features/home/views/user_tab.dart';
import 'package:secured_calling/features/home/views/users_screen.dart';
import 'package:flutter/material.dart';

enum UserType { user, member }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AppFirebaseService _firebaseService = AppFirebaseService.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = AppLocalStorage.getUserDetails();

    return Scaffold(
      appBar: AppBar(
        title: const Text('SecuredCalling'),

        actions: [
          PopupMenuButton<String>(
            offset: Offset(0, 50),
            icon: const Icon(
              Icons.logout_rounded,
            ), // You can use Icons.exit_to_app if preferred
            onSelected: (value) async {
              if (value == 'sign_out') {
                if (await AppLocalStorage.signOut(context)) {
                  Navigator.pushReplacementNamed(
                    context,
                    AppRouter.welcomeRoute,
                  );
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
                      children: [
                        8.w,
                        Text('Sign Out'),
                        10.w,
                        const Icon(Icons.logout_rounded, color: Colors.red),
                      ],
                    ),
                  ),
                ],
          ),
        ],
        leading:
            !AppLocalStorage.getUserDetails().email.contains('flutter') &&
                    !AppLocalStorage.getUserDetails().isMember
                ? null
                : IconButton(
                  icon: const Icon(Icons.people_alt_outlined),
                  onPressed: () {
                    final user = AppLocalStorage.getUserDetails();
                    if (user.email.contains('flutter')) {
                      // Admin navigation
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AdminScreen()),
                      );
                    } else if (user.isMember) {
                      // Member navigation
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const UsersScreen()),
                      );
                    }
                  },
                  tooltip:
                      user.email.contains('flutter')
                          ? 'Admin Section'
                          : 'View Associated Users',
                ),
      ),

      body: Column(
        children: [
          // User profile card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  user.name.sentenceCase,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                if (user.isMember && user.memberCode.isNotEmpty) ...[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Code: ${user.memberCode}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      4.w,
                      IconButton(
                        icon: const Icon(
                          Icons.copy,
                          color: Colors.white,
                          size: 14,
                        ),
                        padding: EdgeInsets.zero,

                        onPressed: () {
                          // Copy member code to clipboard
                          Clipboard.setData(
                            ClipboardData(text: user.memberCode),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              duration: Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                              content: Text('Member code copied!'),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Role : ${user.isMember ? 'Member' : 'User'}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ),

                if (user.isMember && !user.subscription.isEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Expires On : ${user.subscription.expiryDate.formatDate}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 8,
                          ),
                        ),
                      ),

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          user.subscription.expiryDate.differenceInDays < 0
                              ? 'Days Left : ${-user.subscription.expiryDate.differenceInDays}'
                              : user.subscription.expiryDate.differenceInDays ==
                                  0
                              ? 'Expiring Today'
                              : 'Expired',
                          style: const TextStyle(
                            color: AppTheme.primaryColor,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Tab Bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: AppTheme.primaryColor,
              ),
              labelColor: Colors.white,
              indicatorPadding: EdgeInsets.all(8),
              dividerColor: Colors.transparent,
              unselectedLabelColor:
                  Theme.of(context).textTheme.bodyLarge?.color,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold),
              tabs: const [
                Tab(icon: Icon(Icons.video_call), text: 'Host Meeting'),
                Tab(icon: Icon(Icons.people), text: 'Join Meeting'),
              ],
            ),
          ),
          Divider(),
          // Tab content
          Expanded(
            child: TabBarView(
              physics: NeverScrollableScrollPhysics(),
              controller: _tabController,
              children: [
                MembarTabViewWidget(isMember: user.isMember),
                UserTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
