import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF4A6CFA);
  static const Color secondaryColor = Color(0xFF32B5FF);
  static const Color accentColor = Color(0xFF01C58C);
  static const Color errorColor = Color(0xFFE53935);
  static const Color warningColor = Color(0xFFFFAB40);
  static const Color successColor = Color(0xFF43A047);

  // Light theme colors
  static const Color lightBackgroundColor = Color(0xFFFFFFFF);
  static const Color lightSurfaceColor = Color(0xFFF5F7FA);
  static const Color lightTextColor = Color(0xFF202124);
  static const Color lightSecondaryTextColor = Color(0xFF5F6368);

  // Dark theme colors
  static const Color darkBackgroundColor = Color(0xFF121212);
  static const Color darkSurfaceColor = Color(0xFF1E1E1E);
  static const Color darkTextColor = Color(0xFFE8EAED);
  static const Color darkSecondaryTextColor = Color(0xFFAEAEAE);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryColor, secondaryColor],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static List<Color> cardBackgroundColors = [
    Colors.white, //  White
    Colors.grey.shade50, //  Grey
  ];

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.light(
        primary: primaryColor,
        secondary: secondaryColor,
        error: errorColor,
        surface: lightSurfaceColor,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: lightTextColor,
        onError: Colors.white,
      ),
      textTheme: GoogleFonts.interTextTheme().copyWith(
        displayLarge: GoogleFonts.montserrat(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: lightTextColor,
        ),
        displayMedium: GoogleFonts.montserrat(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: lightTextColor,
        ),
        displaySmall: GoogleFonts.montserrat(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: lightTextColor,
        ),
        titleLarge: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: lightTextColor,
        ),
        titleMedium: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: lightTextColor,
        ),
        titleSmall: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: lightTextColor,
        ),
        bodyLarge: GoogleFonts.inter(fontSize: 16, color: lightTextColor),
        bodyMedium: GoogleFonts.inter(fontSize: 14, color: lightTextColor),
        bodySmall: GoogleFonts.inter(
          fontSize: 12,
          color: lightSecondaryTextColor,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: lightBackgroundColor,
        foregroundColor: lightTextColor,
        elevation: 0,
        centerTitle: true,
      ),
      scaffoldBackgroundColor: lightBackgroundColor,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 25),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: const BorderSide(color: primaryColor, width: 1.5),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 25),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 25),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightSurfaceColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorColor, width: 2),
        ),
        hintStyle: TextStyle(color: lightSecondaryTextColor.withOpacity(0.7)),
      ),
      cardTheme: CardThemeData(
        color: lightSurfaceColor,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE0E0E0),
        thickness: 1,
        space: 32,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: lightBackgroundColor,
        selectedItemColor: primaryColor,
        unselectedItemColor: lightSecondaryTextColor,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: lightBackgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: lightBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  // static ThemeData get darkTheme {
  //   return ThemeData(
  //     useMaterial3: true,
  //     colorScheme: ColorScheme.dark(
  //       primary: primaryColor,
  //       secondary: secondaryColor,
  //       error: errorColor,
  //       surface: darkSurfaceColor,
  //       onPrimary: Colors.white,
  //       onSecondary: Colors.white,
  //       onSurface: darkTextColor,
  //       onError: Colors.white,
  //     ),
  //     textTheme: GoogleFonts.interTextTheme().copyWith(
  //       displayLarge: GoogleFonts.montserrat(
  //         fontSize: 32,
  //         fontWeight: FontWeight.bold,
  //         color: darkTextColor,
  //       ),
  //       displayMedium: GoogleFonts.montserrat(
  //         fontSize: 28,
  //         fontWeight: FontWeight.bold,
  //         color: darkTextColor,
  //       ),
  //       displaySmall: GoogleFonts.montserrat(
  //         fontSize: 24,
  //         fontWeight: FontWeight.bold,
  //         color: darkTextColor,
  //       ),
  //       titleLarge: GoogleFonts.inter(
  //         fontSize: 20,
  //         fontWeight: FontWeight.w600,
  //         color: darkTextColor,
  //       ),
  //       titleMedium: GoogleFonts.inter(
  //         fontSize: 18,
  //         fontWeight: FontWeight.w600,
  //         color: darkTextColor,
  //       ),
  //       titleSmall: GoogleFonts.inter(
  //         fontSize: 16,
  //         fontWeight: FontWeight.w600,
  //         color: darkTextColor,
  //       ),
  //       bodyLarge: GoogleFonts.inter(fontSize: 16, color: darkTextColor),
  //       bodyMedium: GoogleFonts.inter(fontSize: 14, color: darkTextColor),
  //       bodySmall: GoogleFonts.inter(
  //         fontSize: 12,
  //         color: darkSecondaryTextColor,
  //       ),
  //     ),
  //     appBarTheme: const AppBarTheme(
  //       backgroundColor: darkBackgroundColor,
  //       foregroundColor: darkTextColor,
  //       elevation: 0,
  //       centerTitle: true,
  //     ),
  //     scaffoldBackgroundColor: darkBackgroundColor,
  //     elevatedButtonTheme: ElevatedButtonThemeData(
  //       style: ElevatedButton.styleFrom(
  //         backgroundColor: primaryColor,
  //         foregroundColor: Colors.white,
  //         textStyle: const TextStyle(fontWeight: FontWeight.w600),
  //         padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 25),
  //         shape: RoundedRectangleBorder(
  //           borderRadius: BorderRadius.circular(10),
  //         ),
  //         elevation: 0,
  //       ),
  //     ),
  //     outlinedButtonTheme: OutlinedButtonThemeData(
  //       style: OutlinedButton.styleFrom(
  //         foregroundColor: primaryColor,
  //         side: const BorderSide(color: primaryColor, width: 1.5),
  //         textStyle: const TextStyle(fontWeight: FontWeight.w600),
  //         padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 25),
  //         shape: RoundedRectangleBorder(
  //           borderRadius: BorderRadius.circular(10),
  //         ),
  //       ),
  //     ),
  //     textButtonTheme: TextButtonThemeData(
  //       style: TextButton.styleFrom(
  //         foregroundColor: primaryColor,
  //         textStyle: const TextStyle(fontWeight: FontWeight.w600),
  //         padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 25),
  //       ),
  //     ),
  //     inputDecorationTheme: InputDecorationTheme(
  //       filled: true,
  //       fillColor: darkSurfaceColor,
  //       contentPadding: const EdgeInsets.symmetric(
  //         horizontal: 20,
  //         vertical: 18,
  //       ),
  //       border: OutlineInputBorder(
  //         borderRadius: BorderRadius.circular(12),
  //         borderSide: BorderSide.none,
  //       ),
  //       focusedBorder: OutlineInputBorder(
  //         borderRadius: BorderRadius.circular(12),
  //         borderSide: const BorderSide(color: primaryColor, width: 2),
  //       ),
  //       errorBorder: OutlineInputBorder(
  //         borderRadius: BorderRadius.circular(12),
  //         borderSide: const BorderSide(color: errorColor, width: 2),
  //       ),
  //       hintStyle: TextStyle(color: darkSecondaryTextColor.withOpacity(0.7)),
  //     ),
  //     cardTheme: CardThemeData(
  //       color: darkSurfaceColor,
  //       elevation: 0,
  //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  //       margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
  //     ),
  //     dividerTheme: const DividerThemeData(
  //       color: Color(0xFF3D3D3D),
  //       thickness: 1,
  //       space: 32,
  //     ),
  //     floatingActionButtonTheme: const FloatingActionButtonThemeData(
  //       backgroundColor: primaryColor,
  //       foregroundColor: Colors.white,
  //     ),
  //     bottomNavigationBarTheme: const BottomNavigationBarThemeData(
  //       backgroundColor: darkBackgroundColor,R
  //       selectedItemColor: primaryColor,
  //       unselectedItemColor: darkSecondaryTextColor,
  //       type: BottomNavigationBarType.fixed,
  //       elevation: 8,
  //     ),
  //     bottomSheetTheme: const BottomSheetThemeData(
  //       backgroundColor: darkBackgroundColor,
  //       shape: RoundedRectangleBorder(
  //         borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
  //       ),
  //     ),
  //     dialogTheme: DialogThemeData(
  //       backgroundColor: darkBackgroundColor,
  //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
  //     ),
  //   );
  // }
}
