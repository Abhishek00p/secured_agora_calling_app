import 'package:flutter/material.dart';
import 'package:secured_calling/core/utils/responsive_utils.dart';

class JoinRequestPopup extends StatelessWidget {
  final String userName;
  final VoidCallback onAdmit;
  final VoidCallback onDeny;

  const JoinRequestPopup({super.key, required this.userName, required this.onAdmit, required this.onDeny});

  @override
  Widget build(BuildContext context) {
    final padding = responsivePadding(context);

    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: padding, vertical: padding),
          child: Material(
            elevation: 12,
            borderRadius: BorderRadius.circular(20),
            color: Colors.white,
            child: Container(
              width: context.isMobile ? double.infinity : dialogMaxWidth(context),
              padding: EdgeInsets.symmetric(horizontal: padding, vertical: 14),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(20)),
              child: Row(
                children: [
                  const Icon(Icons.person, size: 32, color: Colors.grey),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: userName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: context.isMobile ? 10 : 14,
                            ),
                          ),
                          TextSpan(
                            text: ' wants to join the meeting',
                            style: TextStyle(
                              fontSize: context.isMobile ? 8 : 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: onDeny,
                    child: Text(
                      'Deny',
                      style: TextStyle(fontSize: context.isMobile ? 12 : 14, color: Colors.red),
                    ),
                  ),
                  const SizedBox(width: 4),
                  ElevatedButton(
                    onPressed: onAdmit,
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: responsivePadding(context),
                        vertical: 10,
                      ),
                    ),
                    child: Text(
                      'Admit',
                      style: TextStyle(fontSize: context.isMobile ? 12 : 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
