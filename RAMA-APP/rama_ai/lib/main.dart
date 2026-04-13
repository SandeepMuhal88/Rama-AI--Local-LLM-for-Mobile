import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/app_theme.dart';
import 'screens/splash_screen.dart';

// ─── App entry ────────────────────────────────────────────────────────────────
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load persisted theme preferences
  final prefs     = await SharedPreferences.getInstance();
  final isDark    = prefs.getBool('theme_dark') ?? true;
  final accentIdx = (prefs.getInt('accent_idx') ?? 0)
      .clamp(0, kAccentPresets.length - 1);

  // Initialise the global theme notifier
  appTheme = AppTheme(
    isDark: isDark,
    accent: kAccentPresets[accentIdx],
  );

  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    statusBarColor:           Colors.transparent,
    statusBarIconBrightness:  isDark ? Brightness.light : Brightness.dark,
    systemNavigationBarColor: isDark ? RamaColors.darkBg : RamaColors.lightBg,
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
    widget.theme.addListener(() => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title:                    'RAMA AI',
      debugShowCheckedModeBanner: false,
      theme:                    widget.theme.themeData,
      home:                     const SplashScreen(),   // ← Splash first
    );
  }
}
