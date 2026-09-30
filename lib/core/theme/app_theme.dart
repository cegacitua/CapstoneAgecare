import 'package:flutter/material.dart';

/// Design system de AgeCare: tokens de color, tipografía y tema Material 3.
/// Paleta pensada para transmitir calma (azules/verdes suaves) con
/// acentos claros para los estados del semáforo.
class AppColors {
  AppColors._();

  static const primary = Color(0xFF1F6F8B);
  static const primaryDark = Color(0xFF14505F);
  static const secondary = Color(0xFF7FB685);
  static const background = Color(0xFFF7F9FA);
  static const surface = Colors.white;
  static const textPrimary = Color(0xFF1D2B33);
  static const textSecondary = Color(0xFF5C6B73);
  static const divider = Color(0xFFE3E8EB);

  // Semáforo de bienestar
  static const statusOk = Color(0xFF2E9E5B);
  static const statusWarning = Color(0xFFE8A13A);
  static const statusAttention = Color(0xFFD9534F);

  // Alertas
  static const critical = Color(0xFFC0392B);
}

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.surface,
      ),
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'Roboto',
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.divider),
        ),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primary.withOpacity(.12),
        labelTextStyle: WidgetStatePropertyAll(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.divider, thickness: 1),
    );
  }
}

/// Estado del semáforo de bienestar (alineado con la API: WellbeingStatus).
enum WellbeingStatus {
  ok('ok', 'Bien', AppColors.statusOk, Icons.check_circle_rounded),
  warning('warning', 'Regular', AppColors.statusWarning, Icons.error_rounded),
  attention('attention', 'Requiere atención', AppColors.statusAttention,
      Icons.warning_rounded);

  const WellbeingStatus(this.apiValue, this.label, this.color, this.icon);

  final String apiValue;
  final String label;
  final Color color;
  final IconData icon;

  static WellbeingStatus fromApi(String value) =>
      WellbeingStatus.values.firstWhere(
        (s) => s.apiValue == value,
        orElse: () => WellbeingStatus.ok,
      );
}
