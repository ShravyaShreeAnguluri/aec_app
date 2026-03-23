import 'package:flutter/material.dart';

class AppTheme {

  static const Color primaryBlue = Color(0xFF2E5FA5);
  static const Color accentOrange = Color(0xFFF28B39);
  static const Color softBackground = Color(0xFFF2F5FA);

  static ThemeData lightTheme = ThemeData(

    scaffoldBackgroundColor: softBackground,

    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryBlue,
      primary: primaryBlue,
      secondary: accentOrange,
    ),

    appBarTheme: const AppBarTheme(
      elevation: 0,
      centerTitle: true,
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.black,
    ),

    textTheme: const TextTheme(
      titleLarge: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 20,
      ),
      bodyMedium: TextStyle(
        color: Colors.black87,
      ),
    ),

    cardTheme: const CardThemeData(
      elevation: 6,
      shadowColor: Colors.black12,
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryBlue,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 14,
        ),
      ),
    ),

    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      selectedItemColor: Color(0xFFF28B39),
      unselectedItemColor: Colors.grey,
      type: BottomNavigationBarType.fixed,
      elevation: 10,
    ),
  );
}

// lib/utils/app_theme.dart

class AppColors {
  static const background  = Color(0xFFF0F4FF);
  static const white       = Colors.white;
  static const primary     = Color(0xFF1A56DB);
  static const primaryDark = Color(0xFF1141A8);
  static const primarySoft = Color(0xFFE8EFFF);

  static const textDark  = Color(0xFF0D1B3E);
  static const textMid   = Color(0xFF4A5568);
  static const textLight = Color(0xFF8FA0BC);
  static const border    = Color(0xFFDDE4F0);
  static const cardBg    = Color(0xFFFFFFFF);
  static const success   = Color(0xFF0BA360);
  static const error     = Color(0xFFE53E3E);
  static const warning   = Color(0xFFF6AD55);

  static const year1 = Color(0xFF1A56DB);
  static const year2 = Color(0xFF7C3AED);
  static const year3 = Color(0xFF059669);
  static const year4 = Color(0xFFD97706);

  static Color forYear(int y) {
    switch (y) {
      case 1:  return year1;
      case 2:  return year2;
      case 3:  return year3;
      case 4:  return year4;
      default: return year1;
    }
  }

  static Color forFileType(String t) {
    switch (t.toLowerCase()) {
      case 'pdf':            return const Color(0xFFE53E3E);
      case 'ppt':
      case 'pptx':           return const Color(0xFFDD6B20);
      case 'doc':
      case 'docx':           return const Color(0xFF1A56DB);
      case 'xls':
      case 'xlsx':           return const Color(0xFF059669);
      case 'jpg':
      case 'jpeg':
      case 'png':            return const Color(0xFF7C3AED);
      default:               return const Color(0xFF4A5568);
    }
  }
}

class AppTextStyles {
  static const heading1 = TextStyle(
    fontSize: 24, fontWeight: FontWeight.w800,
    color: AppColors.textDark, letterSpacing: -0.5,
  );
  static const heading2 = TextStyle(
    fontSize: 18, fontWeight: FontWeight.w700,
    color: AppColors.textDark, letterSpacing: -0.3,
  );
  static const heading3 = TextStyle(
    fontSize: 15, fontWeight: FontWeight.w600,
    color: AppColors.textDark,
  );
  static const body = TextStyle(
    fontSize: 14, color: AppColors.textMid, height: 1.5,
  );
  static const caption = TextStyle(
    fontSize: 12, color: AppColors.textLight, fontWeight: FontWeight.w500,
  );
  static const label = TextStyle(
    fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6,
    color: AppColors.textLight,
  );
}

class AppRadius {
  static const sm  = BorderRadius.all(Radius.circular(10));
  static const md  = BorderRadius.all(Radius.circular(14));
  static const lg  = BorderRadius.all(Radius.circular(20));
  static const xl  = BorderRadius.all(Radius.circular(28));
  static const top = BorderRadius.only(
    topLeft: Radius.circular(28), topRight: Radius.circular(28),
  );
}

// class AppTheme {
//   static ThemeData get light => ThemeData(
//     useMaterial3: true,
//     scaffoldBackgroundColor: AppColors.background,
//     fontFamily: 'Roboto',
//     colorScheme: ColorScheme.fromSeed(
//       seedColor: AppColors.primary,
//       surface: AppColors.background,
//     ),
//     appBarTheme: const AppBarTheme(
//       backgroundColor: AppColors.white,
//       foregroundColor: AppColors.textDark,
//       elevation: 0,
//       scrolledUnderElevation: 0,
//       titleTextStyle: TextStyle(
//         fontFamily: 'Roboto',
//         fontSize: 18,
//         fontWeight: FontWeight.w700,
//         color: AppColors.textDark,
//       ),
//     ),
//     inputDecorationTheme: InputDecorationTheme(
//       filled: true,
//       fillColor: AppColors.white,
//       contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
//       border: OutlineInputBorder(
//         borderRadius: BorderRadius.circular(14),
//         borderSide: const BorderSide(color: AppColors.border),
//       ),
//       enabledBorder: OutlineInputBorder(
//         borderRadius: BorderRadius.circular(14),
//         borderSide: const BorderSide(color: AppColors.border),
//       ),
//       focusedBorder: OutlineInputBorder(
//         borderRadius: BorderRadius.circular(14),
//         borderSide: const BorderSide(color: AppColors.primary, width: 2),
//       ),
//       errorBorder: OutlineInputBorder(
//         borderRadius: BorderRadius.circular(14),
//         borderSide: const BorderSide(color: AppColors.error),
//       ),
//       labelStyle: AppTextStyles.body,
//       hintStyle: AppTextStyles.caption,
//     ),
//     elevatedButtonTheme: ElevatedButtonThemeData(
//       style: ElevatedButton.styleFrom(
//         backgroundColor: AppColors.primary,
//         foregroundColor: AppColors.white,
//         elevation: 0,
//         padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(14),
//         ),
//         textStyle: const TextStyle(
//           fontWeight: FontWeight.w700,
//           fontSize: 15,
//         ),
//       ),
//     ),
//     // ✅ FIX: Use CardThemeData (not CardTheme) for Flutter 3.x+
//     cardTheme: CardThemeData(
//       color: AppColors.cardBg,
//       elevation: 0,
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(14),
//         side: const BorderSide(color: AppColors.border),
//       ),
//     ),
//   );
// }

class AppConstants {
  static const yearLabels    = ['1st Year', '2nd Year', '3rd Year', '4th Year'];
  static const yearRomanNums = ['I', 'II', 'III', 'IV'];
  static const categories    = [
    'Lecture Notes',
    'Assignment',
    'Reference Material',
    'Lab Manual',
    'Question Paper',
    'Others',
  ];

  static String fileEmoji(String type) {
    switch (type.toLowerCase()) {
      case 'pdf':            return '📄';
      case 'ppt':
      case 'pptx':           return '📊';
      case 'doc':
      case 'docx':           return '📝';
      case 'xls':
      case 'xlsx':           return '📈';
      case 'jpg':
      case 'jpeg':
      case 'png':            return '🖼️';
      default:               return '📁';
    }
  }
}