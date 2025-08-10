// import 'package:flutter/material.dart';

// extension HexColor on Color {
//   /// Prefixes a hash sign if [leadingHashSign] is set to `true` (default is `true`).
//   String toHex({bool leadingHashSign = true}) => '${leadingHashSign ? '#' : ''}'
//       '${a.toRadixString(16).padLeft(2, '0')}'
//       '${r.toRadixString(16).padLeft(2, '0')}'
//       '${g.toRadixString(16).padLeft(2, '0')}'
//       '${b.toRadixString(16).padLeft(2, '0')}';
// }

import 'package:flutter/material.dart';

extension AppColorExtension on Color {
  /// Converts the color to a hex string.
 Color withAppOpacity(double opacity) {
  return withAlpha((opacity * 255).toInt());

  }

 
}