// import 'dart:async';
// import 'dart:convert';
// import 'dart:io';

// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:secured_calling/core/routes/app_router.dart';
// import 'package:secured_calling/core/services/app_firebase_service.dart';
// import 'package:secured_calling/features/meeting/services/agora_service.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:flutter_timezone/flutter_timezone.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:timezone/data/latest_all.dart' as tz;
// import 'package:timezone/timezone.dart' as tz;

// /// Define top-level handler for background FCM messages
// @pragma('vm:entry-point')
// Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
//   // Initialize Firebase if not already initialized
//   await Firebase.initializeApp();

//   AppLogger.print('Handling a background message: ${message.messageId}');

//   // Initialize notification service for background messages
//   await NotificationService.instance.setupFlutterNotifications();

//   // Handle the message - especially important for calls
//   await NotificationService.instance.handleBackgroundMessage(message);
// }

// enum CallState { incoming, ongoing, ended }

// class NotificationService {
//   // Singleton pattern
//   NotificationService._();
//   static final NotificationService _instance = NotificationService._();
//   static NotificationService get instance => _instance;

//   // Flutter Local Notifications Plugin
//   final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
//       FlutterLocalNotificationsPlugin();

//   // Firebase Messaging
//   final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

//   // Android Notification Channel for high importance notifications
//   late AndroidNotificationChannel _highImportanceChannel;

//   // App call state
//   CallState? _currentCallState;
//   String? _currentCallChannelName;
//   String? _currentCallerId;

//   // Stream controller for call events
//   final StreamController<Map<String, dynamic>> _callEventStreamController =
//       StreamController<Map<String, dynamic>>.broadcast();

//   // Getters
//   Stream<Map<String, dynamic>> get callEventStream =>
//       _callEventStreamController.stream;
//   bool get isInitialized => _initialized;
//   CallState? get currentCallState => _currentCallState;
//   String? get currentCallChannelName => _currentCallChannelName;
//   String? get currentCallerId => _currentCallerId;

//   // Private fields
//   bool _initialized = false;

//   // Initialize notification service
//   Future<void> init() async {
//     if (_initialized) return;

//     // Configure timezone
//     await _configureLocalTimeZone();

//     // Setup Flutter local notifications
//     await setupFlutterNotifications();

//     // Request permissions
//     await _requestPermissions();

//     // Setup Firebase Messaging handlers
//     _setupFirebaseMessaging();

//     _initialized = true;
//   }

//   // Configure local timezone for scheduled notifications
//   Future<void> _configureLocalTimeZone() async {
//     if (kIsWeb || Platform.isLinux) {
//       return;
//     }

//     tz.initializeTimeZones();
//     final String timeZoneName = await FlutterTimezone.getLocalTimezone();
//     tz.setLocalLocation(tz.getLocation(timeZoneName));
//   }

//   // Setup Flutter Local Notifications
//   Future<void> setupFlutterNotifications() async {
//     // Create android notification channel for high importance notifications
//     _highImportanceChannel = const AndroidNotificationChannel(
//       'high_importance_channel',
//       'High Importance Notifications',
//       description: 'This channel is used for important notifications.',
//       importance: Importance.high,
//       enableVibration: true,
//       enableLights: true,
//       playSound: true,
//     );

//     // Initialize Flutter Local Notifications
//     const AndroidInitializationSettings androidInitializationSettings =
//         AndroidInitializationSettings('@mipmap/ic_launcher');

//     DarwinInitializationSettings darwinInitializationSettings =
//         DarwinInitializationSettings(
//           requestAlertPermission: false,
//           requestBadgePermission: false,
//           requestSoundPermission: false,
//           notificationCategories: [
//             DarwinNotificationCategory(
//               'call_category',
//               actions: [
//                 DarwinNotificationAction.plain(
//                   'accept_call',
//                   'Accept',
//                   options: {DarwinNotificationActionOption.foreground},
//                 ),
//                 DarwinNotificationAction.plain(
//                   'decline_call',
//                   'Decline',
//                   options: {DarwinNotificationActionOption.destructive},
//                 ),
//               ],
//               options: {
//                 DarwinNotificationCategoryOption.allowAnnouncement,
//                 DarwinNotificationCategoryOption.hiddenPreviewShowTitle,
//               },
//             ),
//           ],
//         );

//     final InitializationSettings initializationSettings =
//         InitializationSettings(
//           android: androidInitializationSettings,
//           iOS: darwinInitializationSettings,
//           macOS: darwinInitializationSettings,
//         );

//     await _flutterLocalNotificationsPlugin.initialize(
//       initializationSettings,
//       onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
//       onDidReceiveBackgroundNotificationResponse:
//           _onDidReceiveBackgroundNotificationResponse,
//     );

//     // Create the Android notification channel
//     await _flutterLocalNotificationsPlugin
//         .resolvePlatformSpecificImplementation<
//           AndroidFlutterLocalNotificationsPlugin
//         >()
//         ?.createNotificationChannel(_highImportanceChannel);

//     // Set iOS/macOS foreground presentation options
//     await _firebaseMessaging.setForegroundNotificationPresentationOptions(
//       alert: true,
//       badge: true,
//       sound: true,
//     );
//   }

//   // Request notification permissions
//   Future<void> _requestPermissions() async {
//     if (kIsWeb) return;

//     // Request permission from Firebase Messaging
//     NotificationSettings settings = await _firebaseMessaging.requestPermission(
//       alert: true,
//       announcement: true,
//       badge: true,
//       carPlay: true,
//       criticalAlert: true,
//       provisional: false,
//       sound: true,
//     );

//     AppLogger.print('User granted permission: ${settings.authorizationStatus}');

//     // Request permission from Flutter Local Notifications
//     if (Platform.isIOS || Platform.isMacOS) {
//       await _flutterLocalNotificationsPlugin
//           .resolvePlatformSpecificImplementation<
//             IOSFlutterLocalNotificationsPlugin
//           >()
//           ?.requestPermissions(
//             alert: true,
//             badge: true,
//             sound: true,
//             critical: true,
//           );

//       await _flutterLocalNotificationsPlugin
//           .resolvePlatformSpecificImplementation<
//             MacOSFlutterLocalNotificationsPlugin
//           >()
//           ?.requestPermissions(
//             alert: true,
//             badge: true,
//             sound: true,
//             critical: true,
//           );
//     } else if (Platform.isAndroid) {
//       await _flutterLocalNotificationsPlugin
//           .resolvePlatformSpecificImplementation<
//             AndroidFlutterLocalNotificationsPlugin
//           >()
//           ?.requestNotificationsPermission();
//     }
//   }

//   // Setup Firebase Messaging handlers
//   void _setupFirebaseMessaging() {
//     // Set up handler for messages received when the app is in the foreground
//     FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

//     // Set up handler for when a message opens the app from a terminated state
//     FirebaseMessaging.instance.getInitialMessage().then((message) {
//       if (message != null) {
//         _handleInitialMessage(message);
//       }
//     });

//     // Set up handler for when a message opens the app from the background
//     FirebaseMessaging.onMessageOpenedApp.listen(_handleAppOpenedFromMessage);

//     // Set up background message handler
//     FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
//   }

//   // Get FCM token for the device
//   Future<String?> getFcmToken() async {
//     return await _firebaseMessaging.getToken();
//   }

//   // Save FCM token to Firebase
//   Future<void> saveTokenToDatabase(String token) async {
//     final userId = AppFirebaseService.instance.currentUser?.uid;
//     if (userId == null) return;

//     await AppFirebaseService.instance.usersCollection.doc(userId).update({
//       'fcmTokens': FieldValue.arrayUnion([token]),
//     });
//   }

//   // Remove FCM token from Firebase
//   Future<void> removeTokenFromDatabase(String token) async {
//     final userId = AppFirebaseService.instance.currentUser?.uid;
//     if (userId == null) return;

//     await AppFirebaseService.instance.usersCollection.doc(userId).update({
//       'fcmTokens': FieldValue.arrayRemove([token]),
//     });
//   }

//   // Show a local notification
//   Future<void> showLocalNotification({
//     required int id,
//     required String title,
//     required String body,
//     String? payload,
//     NotificationDetails? notificationDetails,
//   }) async {
//     notificationDetails ??= NotificationDetails(
//       android: AndroidNotificationDetails(
//         _highImportanceChannel.id,
//         _highImportanceChannel.name,
//         channelDescription: _highImportanceChannel.description,
//         importance: Importance.high,
//         priority: Priority.high,
//       ),
//       iOS: const DarwinNotificationDetails(
//         presentAlert: true,
//         presentBadge: true,
//         presentSound: true,
//       ),
//     );

//     await _flutterLocalNotificationsPlugin.show(
//       id,
//       title,
//       body,
//       notificationDetails,
//       payload: payload,
//     );
//   }

//   // Show a local incoming call notification
//   Future<void> showIncomingCallNotification({
//     required String callerId,
//     required String callerName,
//     required String channelName,
//   }) async {
//     // Update call state
//     _currentCallState = CallState.incoming;
//     _currentCallChannelName = channelName;
//     _currentCallerId = callerId;

//     // Create notification details
//     final androidDetails = AndroidNotificationDetails(
//       _highImportanceChannel.id,
//       _highImportanceChannel.name,
//       channelDescription: _highImportanceChannel.description,
//       importance: Importance.max,
//       priority: Priority.max,
//       fullScreenIntent: true,
//       category: AndroidNotificationCategory.call,
//       actions: [
//         AndroidNotificationAction(
//           'accept_call',
//           'Accept',
//           showsUserInterface: true,
//         ),
//         AndroidNotificationAction(
//           'decline_call',
//           'Decline',
//           cancelNotification: true,
//         ),
//       ],
//       ongoing: true,
//     );

//     final iosDetails = DarwinNotificationDetails(
//       presentAlert: true,
//       presentBadge: true,
//       presentSound: true,
//       interruptionLevel: InterruptionLevel.timeSensitive,
//       categoryIdentifier: 'call_category',
//     );

//     final notificationDetails = NotificationDetails(
//       android: androidDetails,
//       iOS: iosDetails,
//       macOS: iosDetails,
//     );

//     // Payload for notification actions
//     final payload = jsonEncode({
//       'type': 'call',
//       'action': 'incoming',
//       'callerId': callerId,
//       'callerName': callerName,
//       'channelName': channelName,
//     });

//     await _flutterLocalNotificationsPlugin.show(
//       0, // Use a consistent ID for calls to replace existing call notifications
//       'Incoming Call',
//       callerName,
//       notificationDetails,
//       payload: payload,
//     );

//     // Notify listeners about incoming call
//     _callEventStreamController.add({
//       'type': 'call',
//       'state': 'incoming',
//       'callerId': callerId,
//       'callerName': callerName,
//       'channelName': channelName,
//     });
//   }

//   // Cancel a specific notification
//   Future<void> cancelNotification(int id) async {
//     await _flutterLocalNotificationsPlugin.cancel(id);
//   }

//   // Cancel all notifications
//   Future<void> cancelAllNotifications() async {
//     await _flutterLocalNotificationsPlugin.cancelAll();
//   }

//   // Handle a foreground message from FCM
//   Future<void> _handleForegroundMessage(RemoteMessage message) async {
//     AppLogger.print('Got a message whilst in the foreground!');
//     AppLogger.print('Message data: ${message.data}');

//     if (message.notification != null) {
//       AppLogger.print(
//         'Message also contained a notification: ${message.notification}',
//       );
//     }

//     // Check if the message is a call notification
//     if (message.data.containsKey('type') && message.data['type'] == 'call') {
//       _handleCallMessage(message);
//     } else {
//       // For regular notifications, show them as a local notification
//       if (message.notification != null) {
//         await showLocalNotification(
//           id: message.hashCode,
//           title: message.notification!.title ?? 'SecuredCalling',
//           body: message.notification!.body ?? '',
//           payload: jsonEncode(message.data),
//         );
//       }
//     }
//   }

//   // Handle a background message from FCM
//   Future<void> handleBackgroundMessage(RemoteMessage message) async {
//     AppLogger.print('Handling a background message: ${message.messageId}');

//     // Check if the message is a call notification
//     if (message.data.containsKey('type') && message.data['type'] == 'call') {
//       await _handleCallMessage(message);

//       // For background call notifications, we need to store the call state
//       // so that we can handle it when the app is opened
//       final prefs = await SharedPreferences.getInstance();
//       await prefs.setString(
//         'pending_call',
//         jsonEncode({
//           'callerId': message.data['callerId'],
//           'callerName': message.data['callerName'] ?? 'Unknown Caller',
//           'channelName': message.data['channelName'],
//         }),
//       );
//     } else {
//       // For regular notifications, show them as a local notification
//       if (message.notification != null) {
//         await showLocalNotification(
//           id: message.hashCode,
//           title: message.notification!.title ?? 'SecuredCalling',
//           body: message.notification!.body ?? '',
//           payload: jsonEncode(message.data),
//         );
//       }
//     }
//   }

//   // Handle a message that opens the app from a terminated state
//   void _handleInitialMessage(RemoteMessage message) {
//     AppLogger.print(
//       'App opened from terminated state with message: ${message.data}',
//     );

//     // Check if there's a pending call
//     _checkForPendingCalls().then((hasPendingCall) {
//       if (!hasPendingCall) {
//         // Handle any navigation based on the notification
//         if (message.data.containsKey('route')) {
//           // Example: navigate to a specific route
//           // _navigatorKey.currentState?.pushNamed(message.data['route']);
//         }
//       }
//     });
//   }

//   // Handle a message that opens the app from the background
//   void _handleAppOpenedFromMessage(RemoteMessage message) {
//     AppLogger.print('App opened from background with message: ${message.data}');

//     // Check if there's a pending call
//     _checkForPendingCalls().then((hasPendingCall) {
//       if (!hasPendingCall) {
//         // Handle any navigation based on the notification
//         if (message.data.containsKey('route')) {
//           // Example: navigate to a specific route
//           // _navigatorKey.currentState?.pushNamed(message.data['route']);
//         }
//       }
//     });
//   }

//   // Handle a call message
//   Future<void> _handleCallMessage(RemoteMessage message) async {
//     final callAction = message.data['action'];
//     final callerId = message.data['callerId'];
//     final callerName = message.data['callerName'] ?? 'Unknown Caller';
//     final channelName = message.data['channelName'];

//     if (callAction == 'invite') {
//       // Incoming call
//       await showIncomingCallNotification(
//         callerId: callerId,
//         callerName: callerName,
//         channelName: channelName,
//       );
//     } else if (callAction == 'cancel') {
//       // Call was canceled, remove the notification
//       await cancelNotification(0);

//       // Update call state
//       _currentCallState = CallState.ended;

//       // Notify listeners
//       _callEventStreamController.add({
//         'type': 'call',
//         'state': 'canceled',
//         'callerId': callerId,
//         'channelName': channelName,
//       });

//       // Clear any stored pending call
//       final prefs = await SharedPreferences.getInstance();
//       await prefs.remove('pending_call');
//     }
//   }

//   // Check for pending calls when the app starts
//   Future<bool> _checkForPendingCalls() async {
//     final prefs = await SharedPreferences.getInstance();
//     final pendingCallJson = prefs.getString('pending_call');

//     if (pendingCallJson != null) {
//       try {
//         final pendingCall = jsonDecode(pendingCallJson) as Map<String, dynamic>;

//         // Notify listeners about pending call
//         _callEventStreamController.add({
//           'type': 'call',
//           'state': 'incoming',
//           'callerId': pendingCall['callerId'],
//           'callerName': pendingCall['callerName'],
//           'channelName': pendingCall['channelName'],
//         });

//         // Update call state
//         _currentCallState = CallState.incoming;
//         _currentCallChannelName = pendingCall['channelName'];
//         _currentCallerId = pendingCall['callerId'];

//         // Clear the pending call from storage
//         await prefs.remove('pending_call');

//         return true;
//       } catch (e) {
//         AppLogger.print('Error parsing pending call: $e');
//         await prefs.remove('pending_call');
//       }
//     }

//     return false;
//   }

//   // Check for pending calls and handle them
//   Future<void> checkAndHandlePendingCalls() async {
//     await _checkForPendingCalls();
//   }

//   // Accept the current incoming call
//   Future<void> acceptCall(BuildContext context) async {
//     if (_currentCallState != CallState.incoming ||
//         _currentCallChannelName == null) {
//       return;
//     }

//     // Update call state
//     _currentCallState = CallState.ongoing;

//     // Cancel the notification
//     await cancelNotification(0);

//     // Navigate to the meeting room
//     Navigator.pushNamed(
//       context,
//       AppRouter.meetingRoomRoute,
//       arguments: {'channelName': _currentCallChannelName!, 'isHost': false},
//     );

//     // Clear the pending call from storage
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.remove('pending_call');
//   }

//   // Decline the current incoming call
//   Future<void> declineCall() async {
//     if (_currentCallState != CallState.incoming) {
//       return;
//     }

//     // Update call state
//     _currentCallState = CallState.ended;
//     _currentCallChannelName = null;
//     _currentCallerId = null;

//     // Cancel the notification
//     await cancelNotification(0);

//     // Clear the pending call from storage
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.remove('pending_call');

//     // Notify listeners
//     _callEventStreamController.add({'type': 'call', 'state': 'declined'});
//   }

//   // Send a call invitation to another user
//   Future<void> sendCallInvitation({
//     required String recipientId,
//     required String recipientName,
//     required String channelName,
//   }) async {
//     // In a real application, you would use a cloud function or server
//     // to send the FCM message. This is a placeholder for that functionality.

//     // Ideally, you'd have a Cloud Function like this:
//     // await FirebaseFunctions.instance.httpsCallable('sendCallInvitation').call({
//     //   'recipientId': recipientId,
//     //   'channelName': channelName,
//     //   'callerName': AppFirebaseService.instance.currentUser?.displayName ?? 'Unknown',
//     //   'callerId': AppFirebaseService.instance.currentUser?.uid,
//     // });

//     AppLogger.print(
//       'Would send call invitation to $recipientId for channel $channelName',
//     );
//   }

//   // Handle notification interaction in foreground mode
//   void _onDidReceiveLocalNotification(
//     int id,
//     String? title,
//     String? body,
//     String? payload,
//   ) {
//     AppLogger.print('Received local notification: $id, $title, $body, $payload');
//   }

//   // Handle notification response when app is in foreground or background (not terminated)
//   void _onDidReceiveNotificationResponse(NotificationResponse response) {
//     AppLogger.print(
//       'Notification response received: ${response.payload} with action ${response.actionId}',
//     );

//     if (response.payload != null) {
//       try {
//         final payloadData =
//             jsonDecode(response.payload!) as Map<String, dynamic>;

//         if (payloadData['type'] == 'call') {
//           // Handle call notification actions
//           if (response.actionId == 'accept_call') {
//             // We'll let the call screen handle this when it's displayed
//             _callEventStreamController.add({
//               'type': 'call',
//               'state': 'accepted',
//               'channelName': payloadData['channelName'],
//             });
//           } else if (response.actionId == 'decline_call') {
//             declineCall();
//           } else {
//             // Default action when notification is tapped (no specific action)
//             _callEventStreamController.add({
//               'type': 'call',
//               'state': 'notification_tapped',
//               'channelName': payloadData['channelName'],
//             });
//           }
//         } else {
//           // Handle other notification types
//           if (payloadData.containsKey('route')) {
//             // Navigate to the specified route
//             // _navigatorKey.currentState?.pushNamed(payloadData['route']);
//           }
//         }
//       } catch (e) {
//         AppLogger.print('Error parsing notification payload: $e');
//       }
//     }
//   }

//   // Handle notification response in background mode
//   @pragma('vm:entry-point')
//   static void _onDidReceiveBackgroundNotificationResponse(
//     NotificationResponse response,
//   ) {
//     AppLogger.print(
//       'Background notification response received: ${response.payload} with action ${response.actionId}',
//     );

//     // For background responses, we'll handle them when the app is brought to the foreground
//   }

//   // Dispose resources
//   void dispose() {
//     _callEventStreamController.close();
//   }
// }
