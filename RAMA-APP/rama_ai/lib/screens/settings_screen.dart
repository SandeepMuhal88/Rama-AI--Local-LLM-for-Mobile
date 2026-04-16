import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../core/app_theme.dart';
import '../core/chat_controller.dart';
import '../widgets/shared_widgets.dart';

// ─── Phase 3: Settings View ───────────────────────────────────────────────────
// Slide-up modal with smooth PageRouteBuilder transition.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entryCtrl;
  late final Animation<double>   _entryFade;

  late TextEditingController _instructionsCtrl;
  late TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 350),
    )..forward();
    _entryFade = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);

    final ctrl = context.read<ChatController>();
    _instructionsCtrl = TextEditingController(text: ctrl.customInstructions);
    _nameCtrl         = TextEditingController();
    _loadName();
  }

  Future<void> _loadName() async {
    final prefs = await SharedPreferences.getInstance();
    _nameCtrl.text = prefs.getString('user_name') ?? '';
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _instructionsCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final ctrl  = context.read<ChatController>();
    final prefs = await SharedPreferences.getInstance();

    ctrl.setCustomInstructions(_instructionsCtrl.text.trim());

    if (_nameCtrl.text.trim().isNotEmpty) {
      await prefs.setString('user_name', _nameCtrl.text.trim());
    }

    if (mounted) Navigator.pop(context);
  }

  // ── Theme helpers ──────────────────────────────────────────────────────────
  Color get _bg      => appTheme.bg;
  Color get _surface => appTheme.surface;
  Color get _card    => appTheme.card;
  Color get _border  => appTheme.border;
  Color get _text    => appTheme.text;
  Color get _sub     => appTheme.sub;
  Color get _dim     => appTheme.dim;
  Color get _accent  => appTheme.accent;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _entryFade,
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: ThinScrollbar(
                  controller: ScrollController(),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    child: Consumer<ChatController>(
                      builder: (_, ctrl, __) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Appearance Section ──────────────────────────
                          _sectionLabel('Appearance'),
                          _themeToggle(ctrl),
                          const SizedBox(height: 16),
                          _accentPicker(),
                          const SizedBox(height: 28),

                          // ── Profile Section ─────────────────────────────
                          _sectionLabel('Profile'),
                          _textField(
                            controller: _nameCtrl,
                            label:      'Your Name',
                            hint:       'e.g. Alex',
                            icon:       Icons.person_outline_rounded,
                          ),
                          const SizedBox(height: 28),

                          // ── Global Memory (Custom Instructions) ─────────
                          _sectionLabel('Global Memory'),
                          _memoryNote(),
                          const SizedBox(height: 10),
                          _memoryField(),
                          const SizedBox(height: 28),

                          // ── Model Parameters ────────────────────────────
                          _sectionLabel('Model Parameters'),
                          _sliderRow(
                            label:    'Temperature',
                            value:    ctrl.temperature,
                            min:      0.0,
                            max:      1.5,
                            onChanged: (v) => ctrl.setTemperature(
                              double.parse(v.toStringAsFixed(2)),
                            ),
                            valueStr: ctrl.temperature.toStringAsFixed(2),
                            hint:     'Controls creativity (0 = deterministic, 1.5 = very creative)',
                          ),
                          const SizedBox(height: 16),
                          _sliderRow(
                            label:    'Max Tokens',
                            value:    ctrl.maxTokens.toDouble(),
                            min:      64,
                            max:      2048,
                            divisions: 60,
                            onChanged: (v) => ctrl.setMaxTokens(v.round()),
                            valueStr: '${ctrl.maxTokens}',
                            hint:     'Maximum length of each AI response',
                          ),
                          const SizedBox(height: 16),
                          _sliderRow(
                            label:    'Context Window',
                            value:    ctrl.contextWindowSize.toDouble(),
                            min:      512,
                            max:      8192,
                            divisions: 30,
                            onChanged: (v) => ctrl.setContextWindowSize(v.round()),
                            valueStr: '${ctrl.contextWindowSize}',
                            hint:     'Total token budget for your model\'s memory',
                          ),
                          const SizedBox(height: 32),

                          // ── Save Button ─────────────────────────────────
                          _saveButton(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color:  _surface,
        border: Border(bottom: BorderSide(color: _border, width: 0.5)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color:        _card,
                borderRadius: BorderRadius.circular(10),
                border:       Border.all(color: _border),
              ),
              child: Icon(Icons.arrow_back_rounded, color: _sub, size: 18),
            ),
          ),
          const SizedBox(width: 14),
          Text('Settings',
              style: GoogleFonts.inter(
                color:      _text,
                fontWeight: FontWeight.w700,
                fontSize:   17,
              )),
          const Spacer(),
          LogoBadge(size: 30, accent: _accent),
        ],
      ),
    );
  }

  // ── Section label ──────────────────────────────────────────────────────────
  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(label,
          style: GoogleFonts.inter(
            color:         _sub,
            fontSize:      11,
            fontWeight:    FontWeight.w600,
            letterSpacing: 1.1,
          )),
    );
  }

  // ── Theme toggle ───────────────────────────────────────────────────────────
  Widget _themeToggle(ChatController ctrl) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color:        _surface,
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: _border),
      ),
      child: Row(
        children: [
          Icon(
            appTheme.isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
            color: _accent,
            size:  18,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Dark Mode',
                    style: GoogleFonts.inter(
                      color:      _text,
                      fontWeight: FontWeight.w600,
                      fontSize:   14,
                    )),
                Text(appTheme.isDark ? 'Currently dark' : 'Currently light',
                    style: GoogleFonts.inter(color: _dim, fontSize: 11)),
              ],
            ),
          ),
          Switch(
            value:     appTheme.isDark,
            onChanged: (_) async {
              appTheme.toggle();
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('theme_dark', appTheme.isDark);
              SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
                statusBarColor:          Colors.transparent,
                statusBarIconBrightness: appTheme.isDark
                    ? Brightness.light
                    : Brightness.dark,
              ));
              if (mounted) setState(() {});
            },
          ),
        ],
      ),
    );
  }

  // ── Accent color picker ────────────────────────────────────────────────────
  Widget _accentPicker() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        _surface,
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Accent Color',
              style: GoogleFonts.inter(
                color:      _text,
                fontWeight: FontWeight.w600,
                fontSize:   14,
              )),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: List.generate(kAccentPresets.length, (i) {
              final c       = kAccentPresets[i];
              final current = appTheme.accent == c;
              return GestureDetector(
                onTap: () async {
                  appTheme.setAccent(c);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setInt('accent_idx', i);
                  if (mounted) setState(() {});
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width:  36,
                  height: 36,
                  decoration: BoxDecoration(
                    color:        c,
                    borderRadius: BorderRadius.circular(10),
                    border: current
                        ? Border.all(color: Colors.white, width: 2.5)
                        : Border.all(color: Colors.transparent, width: 2.5),
                    boxShadow: current
                        ? [BoxShadow(
                            color:      c.withValues(alpha: 0.45),
                            blurRadius: 10,
                          )]
                        : [],
                  ),
                  child: current
                      ? const Icon(Icons.check_rounded,
                          color: Colors.white, size: 18)
                      : null,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ── Text field helper ──────────────────────────────────────────────────────
  Widget _textField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color:        _surface,
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: _border),
      ),
      child: TextField(
        controller: controller,
        style:      GoogleFonts.inter(color: _text, fontSize: 14),
        decoration: InputDecoration(
          labelText:      label,
          labelStyle:     GoogleFonts.inter(color: _sub, fontSize: 13),
          hintText:       hint,
          hintStyle:      GoogleFonts.inter(color: _dim, fontSize: 13),
          prefixIcon:     Icon(icon, color: _accent, size: 18),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 14),
          border:         InputBorder.none,
          focusedBorder:  OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:   BorderSide(color: _accent.withValues(alpha: 0.50)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:   BorderSide(color: _border),
          ),
        ),
      ),
    );
  }

  // ── Memory note ────────────────────────────────────────────────────────────
  Widget _memoryNote() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color:        _accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(color: _accent.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          Icon(Icons.memory_rounded, color: _accent, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'These instructions are prepended to every conversation\'s system prompt.',
              style: GoogleFonts.inter(
                color:    _sub,
                fontSize: 12,
                height:   1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Memory text area ───────────────────────────────────────────────────────
  Widget _memoryField() {
    return Container(
      decoration: BoxDecoration(
        color:        _surface,
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: _border),
      ),
      child: TextField(
        controller: _instructionsCtrl,
        maxLines:   5,
        style:      GoogleFonts.inter(color: _text, fontSize: 13.5, height: 1.6),
        decoration: InputDecoration(
          hintText: 'e.g. "Always reply in Dart code. I am a Senior Flutter developer."',
          hintStyle: GoogleFonts.inter(
            color:    _dim,
            fontSize: 13,
            height:   1.6,
          ),
          contentPadding: const EdgeInsets.all(16),
          border:         InputBorder.none,
          focusedBorder:  OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:   BorderSide(color: _accent.withValues(alpha: 0.50)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:   BorderSide(color: _border),
          ),
        ),
      ),
    );
  }

  // ── Slider row helper ──────────────────────────────────────────────────────
  Widget _sliderRow({
    required String label,
    required double value,
    required double min,
    required double max,
    int? divisions,
    required ValueChanged<double> onChanged,
    required String valueStr,
    required String hint,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      decoration: BoxDecoration(
        color:        _surface,
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: _border),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: GoogleFonts.inter(
                    color:      _text,
                    fontWeight: FontWeight.w600,
                    fontSize:   14,
                  )),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color:        _accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border:       Border.all(color: _accent.withValues(alpha: 0.25)),
                ),
                child: Text(valueStr,
                    style: GoogleFonts.inter(
                      color:      _accent,
                      fontWeight: FontWeight.w700,
                      fontSize:   13,
                    )),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight:      2,
              thumbShape:       const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape:     const RoundSliderOverlayShape(overlayRadius: 14),
              activeTrackColor: _accent,
              thumbColor:       _accent,
              inactiveTrackColor: _border,
              overlayColor:     _accent.withValues(alpha: 0.10),
            ),
            child: Slider(
              value:     value.clamp(min, max),
              min:       min,
              max:       max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
          Text(hint,
              style: GoogleFonts.inter(
                color:    _dim,
                fontSize: 11,
                height:   1.4,
              )),
        ],
      ),
    );
  }

  // ── Save button ────────────────────────────────────────────────────────────
  Widget _saveButton() {
    return GestureDetector(
      onTap: _save,
      child: Container(
        width:   double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_accent, _accent.withValues(alpha: 0.78)],
            begin: Alignment.topLeft,
            end:   Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color:      _accent.withValues(alpha: 0.30),
              blurRadius: 20,
              offset:     const Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: Text('Save Settings',
              style: GoogleFonts.inter(
                color:      Colors.white,
                fontWeight: FontWeight.w700,
                fontSize:   15,
              )),
        ),
      ),
    );
  }
}
