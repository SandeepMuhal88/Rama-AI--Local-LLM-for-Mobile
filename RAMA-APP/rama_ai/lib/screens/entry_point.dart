import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'profile_setup_screen.dart';
import 'chat_screen.dart';

// ─── First-launch gate ────────────────────────────────────────────────────────
// Checks SharedPreferences for a saved user name.
// → First launch  → ProfileSetupScreen
// → Returning     → ChatScreen
class EntryPoint extends StatefulWidget {
  const EntryPoint({super.key});

  @override
  State<EntryPoint> createState() => _EntryPointState();
}

class _EntryPointState extends State<EntryPoint> {
  bool _loading    = true;
  bool _hasProfile = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final prefs = await SharedPreferences.getInstance();
    final name  = prefs.getString('user_name') ?? '';
    if (mounted) {
      setState(() {
        _hasProfile = name.isNotEmpty;
        _loading    = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return _hasProfile ? const ChatScreen() : const ProfileSetupScreen();
  }
}
