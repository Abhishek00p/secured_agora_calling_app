import 'package:flutter/material.dart';
import '../../widgets/speaker_ripple_effect.dart';

class NameTile extends StatelessWidget {
  const NameTile({super.key, required this.name, required this.isSpeaking, required this.isMicMuted});

  final String name;
  final bool isSpeaking;
  final bool isMicMuted;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (isSpeaking)
          const WaterRipple(color: Colors.greenAccent),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade900.withOpacity(0.9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSpeaking ? Colors.greenAccent : Colors.grey.shade700, width: 1.2),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(isMicMuted ? Icons.mic_off : Icons.mic, color: isMicMuted ? Colors.redAccent : Colors.white70),
              const SizedBox(height: 8),
              Text(
                name,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}


