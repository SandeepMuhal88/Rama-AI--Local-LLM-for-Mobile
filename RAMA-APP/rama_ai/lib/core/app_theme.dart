import 'package:flutter/material.dart';

// ─── Accent presets ───────────────────────────────────────────────────────────
const List<Color> kAccentPresets = [
  Color(0xFF7C6EF5), // Indigo (default)
  Color(0xFF3B82F6), // Blue
  Color(0xFF06B6D4), // Cyan
  Color(0xFF10B981), // Emerald
  Color(0xFFF59E0B), // Amber
  Color(0xFFEF4444), // Red
  Color(0xFFEC4899), // Pink
  Color(0xFF8B5CF6), // Violet
];

// ─── Color tokens ─────────────────────────────────────────────────────────────
class RamaColors {
  // Dark palette — true OLED black base
  static const darkBg       = Color(0xFF000000);
  static const darkSurface  = Color(0xFF0A0A0A);
  static const darkCard     = Color(0xFF111111);
  static const darkElevated = Color(0xFF1A1A1A);
  static const darkBorder   = Color(0xFF222222);
  static const darkBorder2  = Color(0xFF2A2A2A);
  static const darkText     = Color(0xFFFFFFFF);
  static const darkTextSub  = Color(0xFF8A8A8A);
  static const darkTextDim  = Color(0xFF3A3A3A);

  // Light palette
  static const lightBg       = Color(0xFFF7F7F7);
  static const lightSurface  = Color(0xFFFFFFFF);
  static const lightCard     = Color(0xFFF0F0F0);
  static const lightElevated = Color(0xFFE8E8E8);
  static const lightBorder   = Color(0xFFE0E0E0);
  static const lightBorder2  = Color(0xFFD0D0D0);
  static const lightText     = Color(0xFF0A0A0A);
  static const lightTextSub  = Color(0xFF666666);
  static const lightTextDim  = Color(0xFFAAAAAA);

  static const error   = Color(0xFFEF4444);
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
}

// ─── AppTheme ─────────────────────────────────────────────────────────────────
class AppTheme extends ChangeNotifier {
  bool  _isDark;
  Color _accent;

  AppTheme({bool isDark = true, Color accent = const Color(0xFF7C6EF5)})
      : _isDark = isDark,
        _accent = accent;

  bool  get isDark => _isDark;
  Color get accent => _accent;

  void toggle() {
    _isDark = !_isDark;
    notifyListeners();
  }

  void setAccent(Color c) {
    _accent = c;
    notifyListeners();
  }

  // Convenience getters for the current theme's tokens
  Color get bg        => _isDark ? RamaColors.darkBg       : RamaColors.lightBg;
  Color get surface   => _isDark ? RamaColors.darkSurface  : RamaColors.lightSurface;
  Color get card      => _isDark ? RamaColors.darkCard     : RamaColors.lightCard;
  Color get elevated  => _isDark ? RamaColors.darkElevated : RamaColors.lightElevated;
  Color get border    => _isDark ? RamaColors.darkBorder   : RamaColors.lightBorder;
  Color get border2   => _isDark ? RamaColors.darkBorder2  : RamaColors.lightBorder2;
  Color get text      => _isDark ? RamaColors.darkText     : RamaColors.lightText;
  Color get sub       => _isDark ? RamaColors.darkTextSub  : RamaColors.lightTextSub;
  Color get dim       => _isDark ? RamaColors.darkTextDim  : RamaColors.lightTextDim;

  ThemeData get themeData => _isDark ? _dark : _light;

  ThemeData get _dark => ThemeData(
    brightness:             Brightness.dark,
    scaffoldBackgroundColor: RamaColors.darkBg,
    useMaterial3:           true,
    fontFamily:             'sans-serif',
    colorScheme: ColorScheme.dark(
      primary: _accent,
      surface: RamaColors.darkSurface,
      onSurface: RamaColors.darkText,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor:         _accent,
      selectionColor:      _accent.withValues(alpha: 0.30),
      selectionHandleColor: _accent,
    ),
    splashColor: _accent.withValues(alpha: 0.08),
    highlightColor: Colors.transparent,
  );

  ThemeData get _light => ThemeData(
    brightness:             Brightness.light,
    scaffoldBackgroundColor: RamaColors.lightBg,
    useMaterial3:           true,
    fontFamily:             'sans-serif',
    colorScheme: ColorScheme.light(
      primary: _accent,
      surface: RamaColors.lightSurface,
      onSurface: RamaColors.lightText,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor:         _accent,
      selectionColor:      _accent.withValues(alpha: 0.25),
      selectionHandleColor: _accent,
    ),
    splashColor: _accent.withValues(alpha: 0.06),
    highlightColor: Colors.transparent,
  );
}

// ─── Global singleton ─────────────────────────────────────────────────────────
// ignore: library_private_types_in_public_api
late AppTheme appTheme;
