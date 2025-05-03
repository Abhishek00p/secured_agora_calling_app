import 'package:flutter/material.dart';

class JoinRequestPopup extends StatelessWidget {
  final String userName;
  final VoidCallback onAdmit;
  final VoidCallback onDeny;

  const JoinRequestPopup({
    Key? key,
    required this.userName,
    required this.onAdmit,
    required this.onDeny,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 12 : 24,
            vertical: isMobile ? 10 : 20,
          ),
          child: Material(
            elevation: 12,
            borderRadius: BorderRadius.circular(20),
            color: Colors.white,
            child: Container(
              width: isMobile ? double.infinity : 500,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person, size: 32, color: Colors.grey),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '$userName wants to join the meeting',
                      style: TextStyle(
                        fontSize: isMobile ? 14 : 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: onDeny,
                    child: Text(
                      'Deny',
                      style: TextStyle(
                        fontSize: isMobile ? 12 : 14,
                        color: Colors.red,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  ElevatedButton(
                    onPressed: onAdmit,
                    child: Text(
                      'Admit',
                      style: TextStyle(fontSize: isMobile ? 12 : 14),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
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
