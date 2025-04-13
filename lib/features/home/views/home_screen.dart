import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:secured_calling/core/routes/app_router.dart';
import 'package:secured_calling/core/services/app_firebase_service.dart';
import 'package:secured_calling/core/theme/app_theme.dart';
import 'package:secured_calling/features/meeting/views/join_meeting_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// User type provider
final userTypeProvider = StateProvider<UserType>((ref) => UserType.user);

enum UserType { user, member }

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AppFirebaseService _firebaseService = AppFirebaseService.instance;
  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserData();

    // Listen to tab changes to update user type
    _tabController.addListener(_updateUserType);
  }

  void _updateUserType() {
    if (_tabController.index == 0) {
      ref.read(userTypeProvider.notifier).state = UserType.member;
    } else {
      ref.read(userTypeProvider.notifier).state = UserType.user;
    }
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (_firebaseService.currentUser != null) {
        final userData = await _firebaseService.getUserData(
          _firebaseService.currentUser!.uid,
        );

        setState(() {
          _userData = userData.data() as Map<String, dynamic>?;
          // Set initial user type based on membership status
          if (_userData != null && _userData!['isMember'] == true) {
            ref.read(userTypeProvider.notifier).state = UserType.member;
            _tabController.animateTo(0); // Switch to member tab
          } else {
            ref.read(userTypeProvider.notifier).state = UserType.user;
            _tabController.animateTo(1); // Switch to user tab
          }
        });
      }
    } catch (e) {
      // Handle error
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading user data: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _signOut() async {
    try {
      await _firebaseService.signOut();
      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRouter.welcomeRoute);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error signing out: $e')));
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_updateUserType);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userType = ref.watch(userTypeProvider);
    final user = _firebaseService.currentUser;

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('SecuredCalling'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: _signOut,
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: Column(
        children: [
          // User profile card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
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
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.white.withOpacity(0.9),
                      child: Text(
                        _userData?['name']?.substring(0, 1).toUpperCase() ??
                            user?.displayName?.substring(0, 1).toUpperCase() ??
                            '?',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _userData?['name'] ?? user?.displayName ?? 'User',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user?.email ?? '',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 14,
                            ),
                          ),
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
                              _userData?['isMember'] == true
                                  ? 'Premium Member'
                                  : 'Free User',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (_userData?['isMember'] == true &&
                    _userData?['subscription'] != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: RichText(
                    textAlign: TextAlign.center,
                      text: TextSpan(
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      
                        children: [
                          const TextSpan(
                            text: 'Subscription Status: ',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          TextSpan(
                            text:
                                'Active until ${_formatDate(_userData?['subscription']['expiryDate'])}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            
                          ),
                        ],
                      ),
                    ),
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
              unselectedLabelColor:
                  Theme.of(context).textTheme.bodyLarge?.color,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold),
              tabs: const [
                Tab(icon: Icon(Icons.video_call), text: 'Host Meeting'),
                Tab(icon: Icon(Icons.people), text: 'Join Meeting'),
              ],
            ),
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Member Tab - Create Meeting
                _buildMemberTab(),

                // User Tab - Join Meeting
                _buildUserTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberTab() {
    final isMember = _userData?['isMember'] == true;

    if (!isMember) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.workspace_premium,
                size: 72,
                color: AppTheme.secondaryColor,
              ),
              const SizedBox(height: 24),
              Text(
                'Premium Features',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(
                'Upgrade to a premium account to host your own meetings with extended features.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  // Upgrade membership logic would go here
                  // For demo, we'll just set the user as a member
                  // _simulateUpgrade();
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                ),
                child: const Text('Upgrade Now'),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // New meeting action card
          _buildActionCard(
            title: 'New Meeting',
            icon: Icons.videocam,
            description: 'Start an instant meeting with video',
            buttonText: 'Start Now',
            onPressed: () => _createNewMeeting(instant: true),
          ),

          // Schedule meeting card
          _buildActionCard(
            title: 'Schedule Meeting',
            icon: Icons.schedule,
            description: 'Plan a meeting for later with invites',
            buttonText: 'Schedule',
            onPressed: () => _createNewMeeting(instant: false),
          ),

          const SizedBox(height: 24),
          Text(
            'Your Meetings',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // Meetings list
          StreamBuilder<QuerySnapshot>(
            stream: _firebaseService.getHostMeetingsStream(
              _firebaseService.currentUser!.uid,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final meetings = snapshot.data?.docs ?? [];

              if (meetings.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.event_busy,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No meetings yet',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your scheduled and recent meetings will appear here',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: meetings.length,
                itemBuilder: (context, index) {
                  final meeting =
                      meetings[index].data() as Map<String, dynamic>;
                  final meetingId = meetings[index].id;
                  final status = meeting['status'] as String;
                  final isLive = status == 'live';
                  final isScheduled = status == 'scheduled';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      title: Row(
                        children: [
                          Text(
                            meeting['meetingName'] as String,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  isLive
                                      ? AppTheme.successColor
                                      : isScheduled
                                      ? AppTheme.warningColor
                                      : Colors.grey,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              isLive
                                  ? 'Live'
                                  : isScheduled
                                  ? 'Scheduled'
                                  : 'Ended',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_today,
                                size: 16,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isLive
                                    ? 'Started ${_formatDate(meeting['actualStartTime'])}'
                                    : isScheduled
                                    ? 'Scheduled for ${_formatDate(meeting['scheduledStartTime'])}'
                                    : 'Ended ${_formatDate(meeting['actualEndTime'])}',
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.link,
                                size: 16,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'ID: ${meeting['channelName']}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (isLive) ...[
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.login, size: 16),
                                  label: const Text('Join'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.successColor,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                  ),
                                  onPressed:
                                      () => _joinExistingMeeting(
                                        meeting['channelName'] as String,
                                        true, // isHost
                                      ),
                                ),
                              ] else if (isScheduled) ...[
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.play_arrow, size: 16),
                                  label: const Text('Start'),
                                  onPressed:
                                      () => _startScheduledMeeting(
                                        meetingId,
                                        meeting['channelName'] as String,
                                      ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildUserTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Join existing meeting card
          _buildActionCard(
            title: 'Join a Meeting',
            icon: Icons.group_add,
            description: 'Enter a meeting ID to join an existing call',
            buttonText: 'Join',
            onPressed: () => _showJoinMeetingDialog(),
          ),

          const SizedBox(height: 24),
          Text(
            'Recent Meetings',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // Placeholder for call history - in a full app, you'd show the user's
          // recently joined meetings here from Firestore
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.history, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'No recent meetings',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Meetings you join will appear here',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required IconData icon,
    required String description,
    required String buttonText,
    required VoidCallback onPressed,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: AppTheme.primaryColor, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(description),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onPressed,
                child: Text(buttonText),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createNewMeeting({required bool instant}) async {
   
    final now = DateTime.now();
    final meetingName = 'Meeting ${now.hour}:${now.minute}';

    try {
      final docRef = await _firebaseService.createMeeting(
        hostId: _firebaseService.currentUser!.uid,
        meetingName: meetingName,
        scheduledStartTime: now,
        duration: 60, // 1 hour meeting
      );

      final doc = await docRef.get();
      final meetingData = doc.data() as Map<String, dynamic>;

      if (instant) {
        // Start the meeting right away
        await _firebaseService.startMeeting(doc.id);

        // Navigate to meeting room
        if (mounted) {
          Navigator.pushNamed(
            context,
            AppRouter.meetingRoomRoute,
            arguments: {
              'channelName': 'testing',
              //  meetingData['channelName'],
              'isHost': true,
            },
          );
        }
      } else {
        // Show confirmation for scheduled meeting
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Meeting "$meetingName" scheduled successfully'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error creating meeting: $e')));
      }
    }
  }

  Future<void> _startScheduledMeeting(
    String meetingId,
    String channelName,
  ) async {
    try {
      await _firebaseService.startMeeting(meetingId);

      // Navigate to meeting room
      if (mounted) {
        Navigator.pushNamed(
          context,
          AppRouter.meetingRoomRoute,
          arguments: {'channelName': channelName, 'isHost': true},
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error starting meeting: $e')));
      }
    }
  }

  void _showJoinMeetingDialog() {
    showDialog(
      context: context,
      builder: (context) => const JoinMeetingDialog(),
    );
  }

  Future<void> _joinExistingMeeting(String channelName, bool isHost) async {
    Navigator.pushNamed(
      context,
      AppRouter.meetingRoomRoute,
      arguments: {'channelName': channelName, 'isHost': isHost},
    );
  }

  // Helper for date formatting
  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'N/A';

    final DateTime date = timestamp.toDate();

    return '${date.day}/${date.month}/${date.year} ${DateFormat('h:m a').format(date)}';
  }

  // For demo purposes - simulate upgrading to premium
  Future<void> _simulateUpgrade() async {
    try {
      final uid = _firebaseService.currentUser!.uid;
      final now = DateTime.now();
      final expiryDate = now.add(const Duration(days: 30));

      await _firebaseService.updateUserData(uid, {
        'isMember': true,
        'subscription': {
          'plan': 'Premium',
          'startDate': now,
          'expiryDate': expiryDate,
        },
      });

      await _loadUserData(); // Reload user data

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Successfully upgraded to Premium!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error upgrading: $e')));
      }
    }
  }
}
