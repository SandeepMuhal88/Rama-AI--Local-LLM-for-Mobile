import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── RAMA AI Color System (Dark-Only) ─────────────────────────────────────────
// Single locked accent — Cosmic Amber. No color picker exposed.
const Color kRamaAccent = Color(0xFFE8A838); // Rich amber-gold

// ─── Color tokens ─────────────────────────────────────────────────────────────
class RamaColors {
  // Dark palette — deep cosmic dark
  static const darkBg       = Color(0xFF0D0D0D);
  static const darkSurface  = Color(0xFF141414);
  static const darkCard     = Color(0xFF1A1A1A);
  static const darkElevated = Color(0xFF1F1F1F);
  static const darkBorder   = Color(0xFF252525);
  static const darkBorder2  = Color(0xFF2E2E2E);
  static const darkText     = Color(0xFFEAEAEA);
  static const darkTextSub  = Color(0xFF888888);
  static const darkTextDim  = Color(0xFF3A3A3A);

  // Keep light palette stubs so nothing breaks if referenced
  static const lightBg       = Color(0xFF0D0D0D);
  static const lightSurface  = Color(0xFF141414);
  static const lightCard     = Color(0xFF1A1A1A);
  static const lightElevated = Color(0xFF1F1F1F);
  static const lightBorder   = Color(0xFF252525);
  static const lightBorder2  = Color(0xFF2E2E2E);
  static const lightText     = Color(0xFFEAEAEA);
  static const lightTextSub  = Color(0xFF888888);
  static const lightTextDim  = Color(0xFF3A3A3A);

  static const error   = Color(0xFFEF4444);
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);

  // Accent shades
  static const accent     = kRamaAccent;
  static const accentSoft = Color(0xFFF0C060);

  // Legacy aliases
  static const claudeOrange     = kRamaAccent;
  static const claudeOrangeSoft = accentSoft;
}

// ─── AppTheme ─────────────────────────────────────────────────────────────────
// Always dark. Accent is locked — no setter exposed in UI.
class AppTheme extends ChangeNotifier {
  // Always dark, always amber.
  bool  get isDark => true;
  Color get accent => kRamaAccent;

  // Keep toggle/setAccent as no-ops so callers don't break at compile time
  void toggle()         {}
  void setAccent(Color c) {}

  // Theme tokens — always dark
  Color get bg        => RamaColors.darkBg;
  Color get surface   => RamaColors.darkSurface;
  Color get card      => RamaColors.darkCard;
  Color get elevated  => RamaColors.darkElevated;
  Color get border    => RamaColors.darkBorder;
  Color get border2   => RamaColors.darkBorder2;
  Color get text      => RamaColors.darkText;
  Color get sub       => RamaColors.darkTextSub;
  Color get dim       => RamaColors.darkTextDim;

  ThemeData get themeData => _dark;

  TextTheme _textTheme(Color textColor) => GoogleFonts.interTextTheme().apply(
        bodyColor: textColor,
        displayColor: textColor,
      );

  ThemeData get _dark => ThemeData(
    brightness:              Brightness.dark,
    scaffoldBackgroundColor: RamaColors.darkBg,
    useMaterial3:            true,
    textTheme:               _textTheme(RamaColors.darkText),
    colorScheme: const ColorScheme.dark(
      primary:   kRamaAccent,
      surface:   RamaColors.darkSurface,
      onSurface: RamaColors.darkText,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor:          kRamaAccent,
      selectionColor:       kRamaAccent.withValues(alpha: 0.30),
      selectionHandleColor: kRamaAccent,
    ),
    splashColor:     kRamaAccent.withValues(alpha: 0.08),
    highlightColor:  Colors.transparent,
    dividerColor:    RamaColors.darkBorder,
    cardColor:       RamaColors.darkCard,
    dialogTheme: const DialogThemeData(
      backgroundColor: RamaColors.darkCard,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: RamaColors.darkCard,
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor:   kRamaAccent,
      thumbColor:         kRamaAccent,
      inactiveTrackColor: RamaColors.darkBorder2,
      overlayColor:       kRamaAccent.withValues(alpha: 0.12),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Colors.white : RamaColors.darkTextSub,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? kRamaAccent
            : RamaColors.darkBorder2,
      ),
    ),
  );
}

// ─── Global singleton ─────────────────────────────────────────────────────────
// ignore: library_private_types_in_public_api
late AppTheme appTheme;

// Legacy export — kept so old references compile
const List<Color> kAccentPresets = [kRamaAccent];
