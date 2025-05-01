import 'package:flutter/material.dart';

class GlowingText extends StatelessWidget {
  final String text;
  final TextStyle style;

  const GlowingText({super.key, required this.text, required this.style});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.5, end: 1.0),
      duration: const Duration(seconds: 1),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Text(
            text,
            style: style.copyWith(
              shadows: [
                Shadow(
                  blurRadius: 10 * value,
                  color: Colors.blue.withOpacity(value),
                  offset: const Offset(0, 0),
                ),
              ],
            ),
          ),
        );
      },
      onEnd: () {
        // Rebuild to loop the animation
        Future.microtask(() => (context as Element).markNeedsBuild());
      },
    );
  }
}
