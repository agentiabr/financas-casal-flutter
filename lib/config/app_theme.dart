import 'package:flutter/material.dart';

class AppTheme {
  // Cores do Tema Claro (Flat Blue - Padrão V5.1)
  static const Color primaryBlue = Color(0xFF1D4ED8);
  static const Color primaryLight = Color(0xFF3B82F6);
  static const Color lightBg = Color(0xFFEEF3FB);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color borderSubtle = Color(0xFFDCE5F3);
  static const Color textMain = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);

  // Cores de Status e Atalhos Compatíveis
  static const Color emeraldGreen = Color(0xFF059669);
  static const Color emerald = Color(0xFF059669);
  static const Color slate = Color(0xFF64748B);
  static const Color amberWarning = Color(0xFFD97706);
  static const Color roseDanger = Color(0xFFE11D48);
  static const Color alertNegative = Color(0xFFDC2626);
  static const Color purpleInstallments = Color(0xFF7C3AED);

  // Tema Claro
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBg,
      primaryColor: primaryBlue,
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: borderSubtle, width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: textMain,
      ),
    );
  }

  // Tema Escuro
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0F172A),
      primaryColor: const Color(0xFF3B82F6),
      cardTheme: CardThemeData(
        color: const Color(0xFF1E293B),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFF334155), width: 1),
        ),
      ),
    );
  }
}
