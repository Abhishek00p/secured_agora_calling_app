// import 'package:secured_calling/core/services/notification_service.dart';
// import 'package:secured_calling/core/theme/app_theme.dart';
// import 'package:flutter/material.dart';

// class IncomingCallScreen extends StatefulWidget {
//   final String callerId;
//   final String callerName;
//   final String channelName;

//   const IncomingCallScreen({
//     required this.callerId,
//     required this.callerName,
//     required this.channelName,
//     super.key,
//   });

//   @override
//   State<IncomingCallScreen> createState() => _IncomingCallScreenState();
// }

// class _IncomingCallScreenState extends State<IncomingCallScreen>
//     with SingleTickerProviderStateMixin {
//   late AnimationController _animationController;
//   late Animation<double> _scaleAnimation;
//   late Animation<double> _opacityAnimation;

//   @override
//   void initState() {
//     super.initState();

//     // Setup animations
//     _animationController = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 2000),
//     );

//     _scaleAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
//       CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
//     );

//     _opacityAnimation = Tween<double>(begin: 0.6, end: 0.0).animate(
//       CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
//     );

//     // Repeat the animation continuously
//     _animationController.repeat(reverse: true);
//   }

//   @override
//   void dispose() {
//     _animationController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Container(
//         width: double.infinity,
//         height: double.infinity,
//         decoration: BoxDecoration(
//           gradient: LinearGradient(
//             begin: Alignment.topCenter,
//             end: Alignment.bottomCenter,
//             colors: [
//               AppTheme.primaryColor,
//               AppTheme.secondaryColor.withOpacity(0.8),
//             ],
//           ),
//         ),
//         child: SafeArea(
//           child: Column(
//             children: [
//               const SizedBox(height: 60),
//               const Text(
//                 'Incoming Call',
//                 style: TextStyle(
//                   color: Colors.white,
//                   fontSize: 24,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//               const SizedBox(height: 40),
//               Stack(
//                 alignment: Alignment.center,
//                 children: [
//                   // Animated ring
//                   AnimatedBuilder(
//                     animation: _animationController,
//                     builder: (context, child) {
//                       return Container(
//                         width: 140 * _scaleAnimation.value,
//                         height: 140 * _scaleAnimation.value,
//                         decoration: BoxDecoration(
//                           shape: BoxShape.circle,
//                           color: Colors.white.withOpacity(
//                             _opacityAnimation.value,
//                           ),
//                         ),
//                       );
//                     },
//                   ),
//                   // Caller avatar
//                   Container(
//                     width: 120,
//                     height: 120,
//                     decoration: const BoxDecoration(
//                       color: Colors.white,
//                       shape: BoxShape.circle,
//                     ),
//                     child: Center(
//                       child: Text(
//                         widget.callerName.isNotEmpty
//                             ? widget.callerName[0].toUpperCase()
//                             : '?',
//                         style: TextStyle(
//                           fontSize: 48,
//                           fontWeight: FontWeight.bold,
//                           color: AppTheme.primaryColor,
//                         ),
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//               const SizedBox(height: 30),
//               Text(
//                 widget.callerName,
//                 style: const TextStyle(
//                   color: Colors.white,
//                   fontSize: 28,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//               const SizedBox(height: 8),
//               const Text(
//                 'is calling you...',
//                 style: TextStyle(color: Colors.white70, fontSize: 16),
//               ),
//               const Spacer(),
//               Padding(
//                 padding: const EdgeInsets.symmetric(
//                   horizontal: 40,
//                   vertical: 40,
//                 ),
//                 child: Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                   children: [
//                     _buildActionButton(
//                       icon: Icons.call_end,
//                       backgroundColor: Colors.red,
//                       onPressed: () => _handleDeclineCall(),
//                       label: 'Decline',
//                     ),
//                     _buildActionButton(
//                       icon: Icons.call,
//                       backgroundColor: Colors.green,
//                       onPressed: () => _handleAcceptCall(),
//                       label: 'Accept',
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildActionButton({
//     required IconData icon,
//     required Color backgroundColor,
//     required VoidCallback onPressed,
//     required String label,
//   }) {
//     return Column(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         Container(
//           width: 70,
//           height: 70,
//           decoration: BoxDecoration(
//             color: backgroundColor,
//             shape: BoxShape.circle,
//           ),
//           child: IconButton(
//             icon: Icon(icon, color: Colors.white, size: 30),
//             onPressed: onPressed,
//           ),
//         ),
//         const SizedBox(height: 10),
//         Text(
//           label,
//           style: const TextStyle(
//             color: Colors.white,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//       ],
//     );
//   }

//   void _handleAcceptCall() {
//     NotificationService.instance.acceptCall(context);
//   }

//   void _handleDeclineCall() {
//     NotificationService.instance.declineCall();
//     Navigator.of(context).pop();
//   }
// }
