import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Claude-inspired Accent Presets ───────────────────────────────────────────
const List<Color> kAccentPresets = [
  Color(0xFFDA7756), // Claude Orange/Peach (default)
  Color(0xFF7C6EF5), // Indigo
  Color(0xFF3B82F6), // Blue
  Color(0xFF06B6D4), // Cyan
  Color(0xFF10B981), // Emerald
  Color(0xFFF59E0B), // Amber
  Color(0xFFEC4899), // Pink
  Color(0xFF8B5CF6), // Violet
];

// ─── Color tokens ─────────────────────────────────────────────────────────────
class RamaColors {
  // Dark palette — Claude AI inspired
  static const darkBg       = Color(0xFF121212);
  static const darkSurface  = Color(0xFF1A1A1A);
  static const darkCard     = Color(0xFF1E1E1E);
  static const darkElevated = Color(0xFF242424);
  static const darkBorder   = Color(0xFF2A2A2A);
  static const darkBorder2  = Color(0xFF333333);
  static const darkText     = Color(0xFFE0E0E0);
  static const darkTextSub  = Color(0xFF8A8A8A);
  static const darkTextDim  = Color(0xFF3A3A3A);

  // Light palette
  static const lightBg       = Color(0xFFF8F7F5);
  static const lightSurface  = Color(0xFFFFFFFF);
  static const lightCard     = Color(0xFFF3F2EF);
  static const lightElevated = Color(0xFFEAE9E6);
  static const lightBorder   = Color(0xFFE0DDD8);
  static const lightBorder2  = Color(0xFFD0CEC9);
  static const lightText     = Color(0xFF1A1A1A);
  static const lightTextSub  = Color(0xFF666666);
  static const lightTextDim  = Color(0xFFAAAAAA);

  static const error   = Color(0xFFEF4444);
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);

  // Claude accent shades
  static const claudeOrange = Color(0xFFDA7756);
  static const claudeOrangeSoft = Color(0xFFF0A882);
}

// ─── AppTheme ─────────────────────────────────────────────────────────────────
class AppTheme extends ChangeNotifier {
  bool  _isDark;
  Color _accent;

  AppTheme({bool isDark = true, Color accent = RamaColors.claudeOrange})
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

  TextTheme _textTheme(Color textColor) => GoogleFonts.interTextTheme().apply(
        bodyColor: textColor,
        displayColor: textColor,
      );

  ThemeData get _dark => ThemeData(
    brightness:             Brightness.dark,
    scaffoldBackgroundColor: RamaColors.darkBg,
    useMaterial3:           true,
    textTheme:              _textTheme(RamaColors.darkText),
    colorScheme: ColorScheme.dark(
      primary:   _accent,
      surface:   RamaColors.darkSurface,
      onSurface: RamaColors.darkText,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor:          _accent,
      selectionColor:       _accent.withValues(alpha: 0.30),
      selectionHandleColor: _accent,
    ),
    splashColor:     _accent.withValues(alpha: 0.08),
    highlightColor:  Colors.transparent,
    dividerColor:    RamaColors.darkBorder,
    cardColor:       RamaColors.darkCard,
    dialogTheme:     const DialogThemeData(
      backgroundColor: RamaColors.darkCard,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: RamaColors.darkCard,
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor:   _accent,
      thumbColor:         _accent,
      inactiveTrackColor: RamaColors.darkBorder2,
      overlayColor:       _accent.withValues(alpha: 0.12),
    ),
    switchTheme: SwitchThemeData(
      thumbColor:  WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Colors.white : RamaColors.darkTextSub,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? _accent
            : RamaColors.darkBorder2,
      ),
    ),
  );

  ThemeData get _light => ThemeData(
    brightness:             Brightness.light,
    scaffoldBackgroundColor: RamaColors.lightBg,
    useMaterial3:           true,
    textTheme:              _textTheme(RamaColors.lightText),
    colorScheme: ColorScheme.light(
      primary:   _accent,
      surface:   RamaColors.lightSurface,
      onSurface: RamaColors.lightText,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor:          _accent,
      selectionColor:       _accent.withValues(alpha: 0.25),
      selectionHandleColor: _accent,
    ),
    splashColor:    _accent.withValues(alpha: 0.06),
    highlightColor: Colors.transparent,
    dividerColor:   RamaColors.lightBorder,
    cardColor:      RamaColors.lightCard,
    sliderTheme: SliderThemeData(
      activeTrackColor:   _accent,
      thumbColor:         _accent,
      inactiveTrackColor: RamaColors.lightBorder2,
      overlayColor:       _accent.withValues(alpha: 0.12),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Colors.white : RamaColors.lightTextSub,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? _accent
            : RamaColors.lightBorder2,
      ),
    ),
  );
}

// ─── Global singleton ─────────────────────────────────────────────────────────
// ignore: library_private_types_in_public_api
late AppTheme appTheme;
