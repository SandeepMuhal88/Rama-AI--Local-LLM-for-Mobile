import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../services/hardware_info.dart';
import 'chat_screen.dart';

// ─── Profile Setup Screen ─────────────────────────────────────────────────────
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen>
    with SingleTickerProviderStateMixin {
  final _nameCtrl = TextEditingController();
  int  _selAvatar = 0;
  int  _selAccent = 0;
  bool _saving    = false;
  bool _isEditing = false;
  Map<String, String> _hwInfo = {};

  late AnimationController _animCtrl;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;

  static const _avatarEmojis = [
    '🧑', '👩', '👨', '🧙', '🦸', '🤖', '🦊', '🐼',
  ];

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim  = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
    _loadExisting();
    _loadHardwareInfo();
  }

  Future<void> _loadHardwareInfo() async {
    final info = await HardwareInfoService.getAndroidHardwareInfo();
    if (mounted) setState(() => _hwInfo = info);
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    final prefs = await SharedPreferences.getInstance();
    final name  = prefs.getString('user_name') ?? '';
    if (!mounted) return;
    setState(() {
      _isEditing  = name.isNotEmpty;
      _nameCtrl.text = name;
      _selAvatar  = prefs.getInt('user_avatar') ?? 0;
      _selAccent  = prefs.getInt('accent_idx')  ?? 0;
    });
  }

  bool get _canSave => _nameCtrl.text.trim().isNotEmpty;

  Future<void> _save() async {
    if (!_canSave || _saving) return;
    setState(() => _saving = true);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name',  _nameCtrl.text.trim());
    await prefs.setInt('user_avatar',   _selAvatar);
    await prefs.setInt('accent_idx',    _selAccent);
    appTheme.setAccent(kAccentPresets[_selAccent]);

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor:          Colors.transparent,
      statusBarIconBrightness: appTheme.isDark ? Brightness.light : Brightness.dark,
    ));

    if (!mounted) return;
    if (_isEditing && Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, a1, a2) => const ChatScreen(),
          transitionsBuilder: (context, anim, _, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 450),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = appTheme.isDark;
    final accent  = kAccentPresets[_selAccent];
    final bg      = isDark ? RamaColors.darkBg      : RamaColors.lightBg;
    final card    = isDark ? RamaColors.darkCard     : RamaColors.lightCard;
    final border  = isDark ? RamaColors.darkBorder   : RamaColors.lightBorder;
    final text    = isDark ? RamaColors.darkText     : RamaColors.lightText;
    final sub     = isDark ? RamaColors.darkTextSub  : RamaColors.lightTextSub;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
              child: Column(
                children: [
                  // ── Logo + title ────────────────────────────────────────────
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 90, height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              accent.withValues(alpha: 0.18),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                      LogoBadge(size: 64, accent: accent),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isEditing ? 'Edit Profile' : 'Welcome to RAMA AI',
                    style: TextStyle(
                      color:      text,
                      fontSize:   24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isEditing
                        ? 'Change your name, avatar or theme'
                        : 'Set up your profile to get started',
                    style: TextStyle(color: sub, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 36),

                  // ── Avatar picker ───────────────────────────────────────────
                  _SectionLabel(label: 'CHOOSE YOUR AVATAR', color: sub),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10, runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: List.generate(_avatarEmojis.length, (i) {
                      final sel = i == _selAvatar;
                      return GestureDetector(
                        onTap: () => setState(() => _selAvatar = i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 56, height: 56,
                          decoration: BoxDecoration(
                            color: sel
                                ? accent.withValues(alpha: 0.12)
                                : card,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: sel ? accent : border,
                              width: sel ? 2 : 0.5,
                            ),
                            boxShadow: sel
                                ? [BoxShadow(
                                    color:      accent.withValues(alpha: 0.25),
                                    blurRadius: 10,
                                    offset:     const Offset(0, 4),
                                  )]
                                : [],
                          ),
                          child: Center(
                            child: Text(_avatarEmojis[i],
                                style: const TextStyle(fontSize: 24)),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 30),

                  // ── Name field ──────────────────────────────────────────────
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _SectionLabel(label: 'YOUR NAME', color: sub),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color:        card,
                      borderRadius: BorderRadius.circular(14),
                      border:       Border.all(color: border, width: 0.5),
                    ),
                    child: TextField(
                      controller: _nameCtrl,
                      onChanged:  (_) => setState(() {}),
                      style: TextStyle(
                        color:      text,
                        fontSize:   15,
                        fontWeight: FontWeight.w500,
                      ),
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        hintText:  'e.g. Sandeep',
                        hintStyle: TextStyle(
                          color:    sub.withValues(alpha: 0.45),
                          fontSize: 15,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        border:    InputBorder.none,
                        prefixIcon: Icon(
                            Icons.person_outline_rounded, color: sub, size: 20),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // ── Theme accent ────────────────────────────────────────────
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _SectionLabel(label: 'ACCENT COLOR', color: sub),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10, runSpacing: 10,
                    children: List.generate(kAccentPresets.length, (i) {
                      final sel = i == _selAccent;
                      return GestureDetector(
                        onTap: () => setState(() => _selAccent = i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color:  kAccentPresets[i],
                            shape:  BoxShape.circle,
                            border: Border.all(
                              color: sel ? Colors.white : Colors.transparent,
                              width: 2.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: kAccentPresets[i].withValues(
                                    alpha: sel ? 0.55 : 0.25),
                                blurRadius: sel ? 14 : 5,
                                offset:     const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: sel
                              ? const Icon(Icons.check, color: Colors.white, size: 18)
                              : null,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 18),

                  // ── Dark / light toggle ─────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color:        card,
                      borderRadius: BorderRadius.circular(14),
                      border:       Border.all(color: border, width: 0.5),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          appTheme.isDark
                              ? Icons.dark_mode_rounded
                              : Icons.light_mode_rounded,
                          color: accent, size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Theme',
                                  style: TextStyle(
                                    color:      text,
                                    fontWeight: FontWeight.w600,
                                    fontSize:   14,
                                  )),
                              Text(
                                appTheme.isDark ? 'Dark mode' : 'Light mode',
                                style: TextStyle(color: sub, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value:           appTheme.isDark,
                          onChanged: (_) {
                            appTheme.toggle();
                            setState(() {});
                          },
                          activeThumbColor: Colors.white,
                          activeTrackColor: accent,
                          inactiveThumbColor: accent.withValues(alpha: 0.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 44),

                  // ── Save button ─────────────────────────────────────────────
                  AnimatedOpacity(
                    opacity:  _canSave ? 1.0 : 0.45,
                    duration: const Duration(milliseconds: 200),
                    child: SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: GestureDetector(
                        onTap: _save,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [accent, accent.withValues(alpha: 0.72)],
                              begin: Alignment.topLeft,
                              end:   Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color:      accent.withValues(alpha: 0.38),
                                blurRadius: 18,
                                offset:     const Offset(0, 7),
                              ),
                            ],
                          ),
                          child: Center(
                            child: _saving
                                ? const SizedBox(
                                    width: 22, height: 22,
                                    child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2.5))
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _isEditing
                                            ? Icons.save_rounded
                                            : Icons.rocket_launch_rounded,
                                        color: Colors.white, size: 20,
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        _isEditing ? 'Save Changes' : 'Get Started',
                                        style: const TextStyle(
                                          color:      Colors.white,
                                          fontSize:   16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 36),

                  // ── Hardware Info ───────────────────────────────────────────
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _SectionLabel(label: 'DEVICE INFO', color: sub),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color:        card,
                      borderRadius: BorderRadius.circular(14),
                      border:       Border.all(color: border, width: 0.5),
                    ),
                    child: _hwInfo.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: CircularProgressIndicator(color: accent, strokeWidth: 2),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: _hwInfo.entries.map((e) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 100,
                                    child: Text(e.key, style: TextStyle(color: sub, fontSize: 12, fontWeight: FontWeight.w600)),
                                  ),
                                  Expanded(
                                    child: Text(e.value, style: TextStyle(color: text, fontSize: 12)),
                                  ),
                                ],
                              ),
                            )).toList(),
                          ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final Color  color;
  const _SectionLabel({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        color:         color,
        fontSize:      10.5,
        fontWeight:    FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }
}
