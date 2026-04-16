import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_theme.dart';
import 'entry_point.dart';

// ─── Phase 1: Opening Sequence ────────────────────────────────────────────────
// Fluid 1.5-second intro: fade-in scale-up logo → text reveal → crossfade.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // ── Phase 1: Logo entrance (0ms → 600ms) ─────────────────────────────────
  late final AnimationController _logoCtrl;
  late final Animation<double>   _logoScale;
  late final Animation<double>   _logoFade;

  // ── Phase 2: Text reveal (350ms → 900ms) ──────────────────────────────────
  late final AnimationController _textCtrl;
  late final Animation<double>   _textFade;
  late final Animation<Offset>   _textSlide;

  // ── Phase 3: Tagline (600ms → 1000ms) ────────────────────────────────────
  late final AnimationController _tagCtrl;
  late final Animation<double>   _tagFade;

  // ── Ambient pulse ─────────────────────────────────────────────────────────
  late final AnimationController _pulseCtrl;
  late final Animation<double>   _pulseAnim;

  @override
  void initState() {
    super.initState();

    _logoCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 600),
    );
    // Curves.easeInOutCubic as specified in requirements
    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _logoCtrl, curve: Curves.easeInOutCubic),
    );
    _logoFade = CurvedAnimation(parent: _logoCtrl, curve: Curves.easeInOutCubic);

    _textCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 500),
    );
    _textFade  = CurvedAnimation(parent: _textCtrl, curve: Curves.easeInOutCubic);
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end:   Offset.zero,
    ).animate(CurvedAnimation(parent: _textCtrl, curve: Curves.easeInOutCubic));

    _tagCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 400),
    );
    _tagFade = CurvedAnimation(parent: _tagCtrl, curve: Curves.easeInOutCubic);

    _pulseCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseAnim = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);

    _runSequence();
  }

  // ── Precisely timed 1.5-second sequence ───────────────────────────────────
  Future<void> _runSequence() async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    _logoCtrl.forward();                                           // 0 → 600ms

    await Future<void>.delayed(const Duration(milliseconds: 350));
    _textCtrl.forward();                                           // 350 → 850ms

    await Future<void>.delayed(const Duration(milliseconds: 250));
    _tagCtrl.forward();                                            // 600 → 1000ms

    // Total visible time: 1500ms from first frame
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;

    // Crossfade to main workspace
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder:        (_, a1, a2) => const EntryPoint(),
        transitionsBuilder: (context, anim, _, child) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeInOutCubic),
          child:   child,
        ),
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _textCtrl.dispose();
    _tagCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent  = appTheme.accent;
    final isDark  = appTheme.isDark;
    final bg      = isDark ? RamaColors.darkBg     : RamaColors.lightBg;
    final textCol = isDark ? RamaColors.darkText    : RamaColors.lightText;
    final subCol  = isDark ? RamaColors.darkTextSub : RamaColors.lightTextSub;

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Ambient pulse glow ────────────────────────────────────────────
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, __) => Stack(
              children: [
                Positioned(
                  top: -120, left: -100,
                  child: _GlowCircle(
                    color: accent,
                    size:  380,
                    alpha: 0.08 + _pulseAnim.value * 0.06,
                  ),
                ),
                Positioned(
                  bottom: -120, right: -80,
                  child: _GlowCircle(
                    color: accent,
                    size:  300,
                    alpha: 0.05 + _pulseAnim.value * 0.05,
                  ),
                ),
              ],
            ),
          ),

          // ── Centre content ────────────────────────────────────────────────
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Logo badge ─────────────────────────────────────────────
                ScaleTransition(
                  scale: _logoScale,
                  child: FadeTransition(
                    opacity: _logoFade,
                    child: Container(
                      width: 96, height: 96,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [accent, accent.withValues(alpha: 0.70)],
                          begin: Alignment.topLeft,
                          end:   Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color:      accent.withValues(alpha: 0.40),
                            blurRadius: 48,
                            offset:     const Offset(0, 16),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color: Colors.white,
                        size:  44,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // ── RAMA AI title ──────────────────────────────────────────
                FadeTransition(
                  opacity: _textFade,
                  child: SlideTransition(
                    position: _textSlide,
                    child: Text(
                      'RAMA AI',
                      style: GoogleFonts.inter(
                        color:         textCol,
                        fontSize:      34,
                        fontWeight:    FontWeight.w800,
                        letterSpacing: 5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // ── Tagline ────────────────────────────────────────────────
                FadeTransition(
                  opacity: _tagFade,
                  child: Text(
                    'Your 100% offline AI assistant',
                    style: GoogleFonts.inter(
                      color:         subCol,
                      fontSize:      14,
                      fontWeight:    FontWeight.w400,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const SizedBox(height: 56),

                // ── Subtle loading dots ────────────────────────────────────
                FadeTransition(
                  opacity: _tagFade,
                  child: AnimatedBuilder(
                    animation: _pulseCtrl,
                    builder: (_, __) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(3, (i) {
                        final phase   = ((_pulseCtrl.value * 3) - i) % 3;
                        final opacity = phase < 1
                            ? phase
                            : (phase < 2 ? 1.0 : 3.0 - phase);
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: 6, height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: accent.withValues(
                                alpha: 0.20 + opacity.clamp(0.0, 1.0) * 0.60),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Ambient glow helper ──────────────────────────────────────────────────────
class _GlowCircle extends StatelessWidget {
  final Color  color;
  final double size;
  final double alpha;
  const _GlowCircle({required this.color, required this.size, required this.alpha});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: alpha), Colors.transparent],
        ),
      ),
    );
  }
}
