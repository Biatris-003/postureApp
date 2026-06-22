import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralized color tokens — slate-blue / navy palette inspired by the
/// CliniQ telehealth reference (soft slate-blue cards, dark navy accent
/// tiles, white surfaces, no gold/teal).
/// Add new colors here, not inline in widgets.
class AppColors {
  // Brand core
  static const ink = Color(0xFF1B2430); // dark navy — used on accent tiles/buttons, not as a bg gradient start
  static const primaryDeep = Color(0xFF35506E); // deep slate-blue, main brand color
  static const primaryMid = Color(0xFF5E7C9C); // mid slate-blue, gradient + buttons
  static const primaryTeal = Color(0xFF7C96B3); // light slate-blue, small accents only
  static const gold = Color(0xFF35506E); // kept for backward-compatibility with existing widgets; now mapped to slate-blue instead of gold

  // Surfaces
  static const surfaceLight = Color(0xFFEFF3F7); // cool pale blue-grey page background
  static const surfaceDark = Color(0xFF11161D);
  static const cardLight = Colors.white;
  static const cardDark = Color(0xFF1B2430);

  // Text
  static const textPrimaryLight = Color(0xFF1F2733);
  static const textSecondaryLight = Color(0xFF748094);
  static const textPrimaryDark = Color(0xFFE7EAEE);
  static const textSecondaryDark = Color(0xFF94A0B2);

  // Borders / dividers
  static const borderLight = Color(0xFFE3E8EE);
  static const borderDark = Color(0xFF2A3340);

  // Status — deeper, muted tones rather than neon
  static const dangerSoftLight = Color(0xFFFBEAEA);
  static const dangerSoftDark = Color(0xFF2A1717);
  static const danger = Color(0xFFB3261E);

  static const successSoftLight = Color(0xFFE7F0EC);
  static const successSoftDark = Color(0xFF112A1E);
  static const success = Color(0xFF3D7A63);

  // Smooth 5-stop ramp (ink → primaryDeep → primaryMid) with hand-picked
  // intermediate hex values, since const gradients can't use Color.lerp.
  // Explicit `stops` + close intermediate hues remove the banding/seams
  // that showed up with the original 3-color, no-stops version.
static const headerGradient = LinearGradient(
  colors: [
    Color(0xFFB8CCEB),
    Color(0xFFCBDAF0),
    Color(0xFFD6E4F7),
  ],
  stops: [0.0, 0.5, 1.0],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);
}

class AppTheme {
  static ThemeData get lightTheme {
    final base = ThemeData(
      useMaterial3: true,
      primaryColor: AppColors.primaryDeep,
      scaffoldBackgroundColor: AppColors.surfaceLight,
      cardColor: AppColors.cardLight,
      brightness: Brightness.light,
    );

    final textTheme = GoogleFonts.manropeTextTheme(base.textTheme).copyWith(
      headlineSmall: GoogleFonts.manrope(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimaryLight,
      ),
      titleMedium: GoogleFonts.manrope(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimaryLight,
      ),
      bodyMedium: GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimaryLight,
      ),
      bodySmall: GoogleFonts.manrope(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondaryLight,
      ),
      labelSmall: GoogleFonts.manrope(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondaryLight,
        letterSpacing: 0.5,
      ),
    );

    return base.copyWith(
      textTheme: textTheme,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.primaryDeep,
        secondary: AppColors.ink,
        surface: AppColors.cardLight,
        error: AppColors.danger,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.cardLight,
        foregroundColor: AppColors.textPrimaryLight,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.ink,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 16),
          elevation: 0,
          textStyle: GoogleFonts.manrope(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryDeep,
          side: const BorderSide(color: AppColors.primaryDeep),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.manrope(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceLight,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primaryDeep, width: 1.5),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.primaryTeal
              : Colors.grey.shade300,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.primaryTeal.withValues(alpha: 0.4)
              : Colors.grey.shade200,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderLight,
        thickness: 1,
        space: 1,
      ),
    );
  }

  static ThemeData get darkTheme {
    final base = ThemeData.dark(useMaterial3: true).copyWith(
      primaryColor: AppColors.primaryTeal,
      scaffoldBackgroundColor: AppColors.surfaceDark,
      cardColor: AppColors.cardDark,
    );

    final textTheme = GoogleFonts.manropeTextTheme(base.textTheme).copyWith(
      headlineSmall: GoogleFonts.manrope(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimaryDark,
      ),
      titleMedium: GoogleFonts.manrope(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimaryDark,
      ),
      bodyMedium: GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimaryDark,
      ),
      bodySmall: GoogleFonts.manrope(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondaryDark,
      ),
      labelSmall: GoogleFonts.manrope(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondaryDark,
        letterSpacing: 0.5,
      ),
    );

    return base.copyWith(
      textTheme: textTheme,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.primaryTeal,
        secondary: AppColors.primaryMid,
        surface: AppColors.cardDark,
        error: AppColors.danger,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.cardDark,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryTeal,
          foregroundColor: AppColors.ink,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 16),
          elevation: 0,
          textStyle: GoogleFonts.manrope(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryTeal,
          side: const BorderSide(color: AppColors.primaryTeal),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.manrope(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF222B36),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primaryTeal, width: 1.5),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.primaryTeal
              : Colors.grey.shade600,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.primaryTeal.withValues(alpha: 0.4)
              : Colors.grey.shade800,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderDark,
        thickness: 1,
        space: 1,
      ),
    );
  }
}

/// Custom "toast-style" feedback used instead of the default SnackBar look.
class AppToast {
  static void show(
    BuildContext context, {
    required String message,
    bool isError = false,
  }) {
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: 32,
        left: 24,
        right: 24,
        child: _ToastCard(message: message, isError: isError),
      ),
    );
    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 2), () => entry.remove());
  }
}

class _ToastCard extends StatelessWidget {
  final String message;
  final bool isError;

  const _ToastCard({required this.message, required this.isError});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isError ? AppColors.danger : AppColors.success;
    final bg = isError
        ? (isDark ? AppColors.dangerSoftDark : AppColors.dangerSoftLight)
        : (isDark ? AppColors.successSoftDark : AppColors.successSoftLight);
    final textColor =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;

    return Material(
      color: Colors.transparent,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        builder: (context, value, child) => Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 12),
            child: child,
          ),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                isError ? Icons.error_outline : Icons.check_circle_outline,
                color: color,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}