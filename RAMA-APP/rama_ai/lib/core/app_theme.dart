import 'package:flutter/material.dart';

// ─── Accent color presets ─────────────────────────────────────────────────────
const List<Color> kAccentPresets = [
  Color(0xFF7C6EF5), // Purple (default)
  Color(0xFF42A5F5), // Sky blue
  Color(0xFF26C6DA), // Teal
  Color(0xFF66BB6A), // Green
  Color(0xFFFFA726), // Amber
  Color(0xFFEF5350), // Red
  Color(0xFFEC407A), // Pink
  Color(0xFFAB47BC), // Violet
];

// ─── Color tokens ─────────────────────────────────────────────────────────────
class RamaColors {
  // Dark
  static const darkBg      = Color(0xFF080814);
  static const darkSurface = Color(0xFF10101F);
  static const darkCard    = Color(0xFF161628);
  static const darkBorder  = Color(0xFF252540);
  static const darkText    = Color(0xFFEAEAF8);
  static const darkTextSub = Color(0xFF8888AA);
  static const darkTextDim = Color(0xFF44445A);
  static const darkUserBg  = Color(0xFF2A2060);

  // Light
  static const lightBg      = Color(0xFFF4F4FB);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightCard    = Color(0xFFF0F0FA);
  static const lightBorder  = Color(0xFFDDDDF0);
  static const lightText    = Color(0xFF1A1A2E);
  static const lightTextSub = Color(0xFF6666AA);
  static const lightTextDim = Color(0xFFAAAACC);

  static const error = Color(0xFFE57373);
}

// ─── AppTheme ChangeNotifier ──────────────────────────────────────────────────
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

  ThemeData get themeData {
    if (_isDark) {
      return ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: RamaColors.darkBg,
        fontFamily: 'sans-serif',
        useMaterial3: true,
        colorScheme: ColorScheme.dark(
          primary: _accent,
          surface: RamaColors.darkSurface,
          onSurface: RamaColors.darkText,
        ),
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: _accent,
          selectionColor: _accent.withValues(alpha: 0.35),
          selectionHandleColor: _accent,
        ),
      );
    } else {
      return ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: RamaColors.lightBg,
        fontFamily: 'sans-serif',
        useMaterial3: true,
        colorScheme: ColorScheme.light(
          primary: _accent,
          surface: RamaColors.lightSurface,
          onSurface: RamaColors.lightText,
        ),
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: _accent,
          selectionColor: _accent.withValues(alpha: 0.3),
          selectionHandleColor: _accent,
        ),
      );
    }
  }
}

// ─── Global singleton (initialised in main) ───────────────────────────────────
// ignore: library_private_types_in_public_api
late AppTheme appTheme;
