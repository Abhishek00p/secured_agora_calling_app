import 'package:flutter/material.dart';

class PermissionPopup extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const PermissionPopup({
    Key? key,
    required this.icon,
    required this.title,
    required this.description,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.all(20),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 60, color: Theme.of(context).primaryColor),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Text(description, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                child: const Text('Later'),
                onPressed: () => Navigator.pop(context, false),
              ),
              ElevatedButton(
                child: const Text('Allow'),
                onPressed: () => Navigator.pop(context, true),
              ),
            ],
          )
        ],
      ),
    );
  }
}
