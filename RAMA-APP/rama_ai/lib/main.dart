import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/app_theme.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock orientation to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Load persisted preferences
  final prefs     = await SharedPreferences.getInstance();
  final isDark    = prefs.getBool('theme_dark')  ?? true;
  final accentIdx = (prefs.getInt('accent_idx')  ?? 0)
      .clamp(0, kAccentPresets.length - 1);

  // Initialise global theme
  appTheme = AppTheme(
    isDark: isDark,
    accent: kAccentPresets[accentIdx],
  );

  // System UI chrome
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    statusBarColor:                  Colors.transparent,
    statusBarIconBrightness:         isDark ? Brightness.light : Brightness.dark,
    systemNavigationBarColor:        isDark ? RamaColors.darkBg : RamaColors.lightBg,
    systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
  ));

  runApp(RamaApp(theme: appTheme));
}

// ─── Root widget ──────────────────────────────────────────────────────────────
class RamaApp extends StatefulWidget {
  final AppTheme theme;
  const RamaApp({super.key, required this.theme});

  @override
  State<RamaApp> createState() => _RamaAppState();
}

class _RamaAppState extends State<RamaApp> {
  @override
  void initState() {
    super.initState();
    widget.theme.addListener(_rebuild);
  }

  void _rebuild() { if (mounted) setState(() {}); }

  @override
  void dispose() {
    widget.theme.removeListener(_rebuild);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title:                    'RAMA AI',
      debugShowCheckedModeBanner: false,
      theme:                    widget.theme.themeData,
      home:                     const SplashScreen(),
    );
  }
}
