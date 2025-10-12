import 'package:flutter/material.dart';

class AppTextContainer extends StatelessWidget {
  final String label;
  final String text;
  final VoidCallback onPressed;
  final IconData? prefixIcon;
  final IconData? suffixIcon;

  const AppTextContainer({
    super.key,
    required this.label,
    required this.text,
    required this.onPressed,
    this.prefixIcon,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade800, fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade400),
              color: Colors.grey.shade50,
            ),
            child: Row(
              children: [
                if (prefixIcon != null) ...[Icon(prefixIcon, color: Colors.black, size: 20), const SizedBox(width: 12)],
                Expanded(child: Text(text, style: const TextStyle(fontSize: 16, color: Colors.black87))),
                if (suffixIcon != null) ...[const SizedBox(width: 12), Icon(suffixIcon, color: Colors.grey.shade600)],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
