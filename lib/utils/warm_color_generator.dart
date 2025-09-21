import 'package:flutter/material.dart';

class WarmColorGenerator {
  static final List<Color> _warmColors = [
    Color(0xFFFF6B6B), // Soft red
    Color(0xFFFF8C42), // Orange
    Color(0xFFFFC857), // Warm yellow
    Color(0xFFFFA69E), // Peach
    Color(0xFFFFD97D), // Light mustard
    Color(0xFFFF9F1C), // Deep orange
    Color(0xFFF4A261), // Sandy orange
    Color(0xFFE76F51), // Burnt orange
    Color(0xFFD62828), // Strong red
    Color(0xFFEB5E28), // Reddish orange
    // Warm purples
    Color(0xFFB388EB), // Soft lavender purple
    Color(0xFF9D4EDD), // Vivid purple
    Color(0xFFC084FC), // Pastel purple
    Color(0xFFD291BC), // Mauve
    Color(0xFFE0AAFF),
  ];

  static final List<Color> _shuffledColors = List.from(_warmColors)..shuffle();
  static int _index = 0;
  static List<Color> get warmColors => _warmColors;
  static Color getRandomWarmColor() {
    if (_index >= _shuffledColors.length) {
      _shuffledColors.shuffle();
      _index = 0;
    }
    return _shuffledColors[_index++];
  }

  static Color getRandomWarmColorByIndex(int index) {
    if (index < 0 || index >= _shuffledColors.length) {
      return _shuffledColors[0];
    }
    return _shuffledColors[index];
  }
}
