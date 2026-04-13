import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_theme.dart';
import '../widgets/shared_widgets.dart';
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
  int  _selectedAvatar = 0;
  int  _selectedAccent = 0;
  bool _saving         = false;
  bool _isEditing      = false;

  late AnimationController _animCtrl;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;

  static const _avatarEmojis = ['🧑', '👩', '👨', '🧙', '🦸', '🤖', '🦊', '🐼'];

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 700),
    );
    _fadeAnim  = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
    _loadExisting();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    final prefs     = await SharedPreferences.getInstance();
    final savedName = prefs.getString('user_name') ?? '';
    if (!mounted) return;
    setState(() {
      _isEditing      = savedName.isNotEmpty;
      _nameCtrl.text  = savedName;
      _selectedAvatar = prefs.getInt('user_avatar') ?? 0;
      _selectedAccent = prefs.getInt('accent_idx')  ?? 0;
    });
  }

  bool get _canSave => _nameCtrl.text.trim().isNotEmpty;

  Future<void> _save() async {
    if (!_canSave || _saving) return;
    setState(() => _saving = true);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name',   _nameCtrl.text.trim());
    await prefs.setInt('user_avatar',    _selectedAvatar);
    await prefs.setInt('accent_idx',     _selectedAccent);

    appTheme.setAccent(kAccentPresets[_selectedAccent]);

    // Sync system UI brightness
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: appTheme.isDark ? Brightness.light : Brightness.dark,
    ));

    if (!mounted) return;
    if (_isEditing && Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (ctx, a1, a2) => const ChatScreen(),
          transitionsBuilder: (ctx, anim, a2, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = appTheme.isDark;
    final accent = kAccentPresets[_selectedAccent];
    final bg     = isDark ? RamaColors.darkBg      : RamaColors.lightBg;
    final card   = isDark ? RamaColors.darkCard     : RamaColors.lightSurface;
    final border = isDark ? RamaColors.darkBorder   : RamaColors.lightBorder;
    final text   = isDark ? RamaColors.darkText     : RamaColors.lightText;
    final sub    = isDark ? RamaColors.darkTextSub  : RamaColors.lightTextSub;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Hero(tag: 'rama_logo', child: LogoBadge(size: 80, accent: accent)),
                  const SizedBox(height: 16),
                  Text(
                    _isEditing ? 'Edit Your Profile' : 'Welcome to RAMA AI',
                    style: TextStyle(
                      color: text,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isEditing ? 'Update your name, avatar & theme' : 'Set up your profile to get started',
                    style: TextStyle(color: sub, fontSize: 14),
                  ),
                  const SizedBox(height: 40),

                  // ── Avatar picker ─────────────────────────────────────────
                  _label('CHOOSE YOUR AVATAR', sub),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 12, runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: List.generate(_avatarEmojis.length, (i) {
                      final sel = i == _selectedAvatar;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedAvatar = i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 58, height: 58,
                          decoration: BoxDecoration(
                            color: sel ? accent.withValues(alpha: 0.15) : card,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: sel ? accent : border,
                              width: sel ? 2.5 : 1,
                            ),
                            boxShadow: sel
                                ? [BoxShadow(
                                    color: accent.withValues(alpha: 0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  )]
                                : [],
                          ),
                          child: Center(
                            child: Text(_avatarEmojis[i],
                                style: const TextStyle(fontSize: 25)),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 32),

                  // ── Name field ────────────────────────────────────────────
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _label('YOUR NAME', sub),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: border),
                    ),
                    child: TextField(
                      controller: _nameCtrl,
                      onChanged: (_) => setState(() {}),
                      style: TextStyle(
                        color: text,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        hintText: 'e.g. Shyam',
                        hintStyle: TextStyle(
                          color: sub.withValues(alpha: 0.5),
                          fontSize: 15,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 14),
                        border: InputBorder.none,
                        prefixIcon: Icon(Icons.person_outline_rounded,
                            color: sub, size: 20),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── Accent color picker ────────────────────────────────────
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _label('THEME ACCENT COLOR', sub),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 12, runSpacing: 12,
                    children: List.generate(kAccentPresets.length, (i) {
                      final sel = i == _selectedAccent;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedAccent = i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: kAccentPresets[i],
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: sel ? Colors.white : Colors.transparent,
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: kAccentPresets[i].withValues(
                                    alpha: sel ? 0.6 : 0.3),
                                blurRadius: sel ? 14 : 6,
                                offset: const Offset(0, 3),
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
                  const SizedBox(height: 48),

                  // ── Save button ────────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: AnimatedOpacity(
                      opacity: _canSave ? 1.0 : 0.45,
                      duration: const Duration(milliseconds: 200),
                      child: GestureDetector(
                        onTap: _save,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [accent, accent.withValues(alpha: 0.7)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: accent.withValues(alpha: 0.45),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Center(
                            child: _saving
                                ? const SizedBox(
                                    width: 24, height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2.5),
                                  )
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _isEditing
                                            ? Icons.save_rounded
                                            : Icons.auto_awesome_rounded,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        _isEditing ? 'Save Changes' : 'Get Started',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String t, Color color) => Text(
        t,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      );
}
