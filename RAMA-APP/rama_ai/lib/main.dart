import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/app_theme.dart';
import 'core/chat_controller.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock orientation to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Always dark — no persisted preference needed
  appTheme = AppTheme();

  // System UI chrome — always dark style
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor:                    Colors.transparent,
    statusBarIconBrightness:           Brightness.light,
    systemNavigationBarColor:          RamaColors.darkBg,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  runApp(
    ChangeNotifierProvider(
      create: (_) => ChatController(),
      child:  const RamaApp(),
    ),
  );
}

// ─── Root widget ──────────────────────────────────────────────────────────────
class RamaApp extends StatelessWidget {
  const RamaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title:                    'RAMA AI',
      debugShowCheckedModeBanner: false,
      theme:                    appTheme.themeData,
      home:                     const SplashScreen(),
    );
  }
}
