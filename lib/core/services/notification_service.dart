// import 'dart:io';

// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:flutter/foundation.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// class NotificationService {
//   static final NotificationService _instance = NotificationService._internal();
//   factory NotificationService() => _instance;
//   NotificationService._internal();

//   final FirebaseMessaging _messaging = FirebaseMessaging.instance;
//   final FlutterLocalNotificationsPlugin _localNotifications =
//       FlutterLocalNotificationsPlugin();

//   static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
//     'high_importance_channel',
//     'High Importance Notifications',
//     description: 'Used for important notifications',
//     importance: Importance.max,
//   );

//   bool _isInitialized = false;

//   Future<void> initializeAfterPermission() async {
//     if (_isInitialized) return;
//     _isInitialized = true;

//     await _localNotifications
//         .resolvePlatformSpecificImplementation<
//             AndroidFlutterLocalNotificationsPlugin>()
//         ?.createNotificationChannel(_channel);

//     const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
//     const iosSettings = DarwinInitializationSettings();

//     const initSettings = InitializationSettings(
//       android: androidSettings,
//       iOS: iosSettings,
//     );

//     await _localNotifications.initialize(initSettings,
//         onDidReceiveNotificationResponse: _onTapNotification);

//     FirebaseMessaging.onMessage.listen(_onMessageHandler);
//     FirebaseMessaging.onMessageOpenedApp.listen(_onTapRemoteNotification);
//     FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
//   }

//   Future<void> requestPermissionAndInitialize() async {
//     final settings = await _messaging.requestPermission();
//     if (settings.authorizationStatus == AuthorizationStatus.authorized) {
//       await initializeAfterPermission();
//     } else {
//       debugPrint("User denied notification permissions");
//     }
//   }

//   Future<String?> getDeviceToken() async {
//     return await _messaging.getToken();
//   }

//   void _onMessageHandler(RemoteMessage message) {
//     final notification = message.notification;
//     if (notification != null && Platform.isAndroid) {
//       _showLocalNotification(notification);
//     }
//   }

//   void _onTapNotification(NotificationResponse response) {
//     debugPrint("Tapped: ${response.payload}");
//   }

//   void _onTapRemoteNotification(RemoteMessage message) {
//     debugPrint("Remote Notification Tapped: ${message.data}");
//   }

//   Future<void> _showLocalNotification(RemoteNotification notification) async {
//     final androidDetails = AndroidNotificationDetails(
//       _channel.id,
//       _channel.name,
//       channelDescription: _channel.description,
//       importance: Importance.max,
//       priority: Priority.high,
//     );
//     const iosDetails = DarwinNotificationDetails();
//     final details = NotificationDetails(android: androidDetails, iOS: iosDetails);

//     await _localNotifications.show(
//       notification.hashCode,
//       notification.title,
//       notification.body,
//       details,
//     );
//   }
// }

// @pragma('vm:entry-point')
// Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
//   await Firebase.initializeApp();
//   debugPrint("BG Notification: ${message.messageId}");
// }
