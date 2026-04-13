import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import 'entry_point.dart';

// ─── Splash Screen ────────────────────────────────────────────────────────────
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _logoCtrl;
  late final AnimationController _textCtrl;
  late final AnimationController _tagCtrl;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _textFade;
  late final Animation<Offset>  _textSlide;
  late final Animation<double> _tagFade;

  @override
  void initState() {
    super.initState();

    // Logo: pop in + fade
    _logoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _logoScale = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut),
    );
    _logoFade = CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOut);

    // Title text: slide-up + fade
    _textCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _textFade  = CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut);
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end:   Offset.zero,
    ).animate(CurvedAnimation(parent: _textCtrl, curve: Curves.easeOutCubic));

    // Tag line: fade in last
    _tagCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _tagFade = CurvedAnimation(parent: _tagCtrl, curve: Curves.easeOut);

    _runSequence();
  }

  Future<void> _runSequence() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    _logoCtrl.forward();

    await Future<void>.delayed(const Duration(milliseconds: 400));
    _textCtrl.forward();

    await Future<void>.delayed(const Duration(milliseconds: 300));
    _tagCtrl.forward();

    // Hold for a moment, then navigate
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (ctx, a1, a2) => const EntryPoint(),
        transitionsBuilder: (ctx, anim, a2, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _textCtrl.dispose();
    _tagCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = appTheme.isDark;
    final accent  = appTheme.accent;
    final bg      = isDark ? RamaColors.darkBg : RamaColors.lightBg;
    final textCol = isDark ? RamaColors.darkText : RamaColors.lightText;
    final subCol  = isDark ? RamaColors.darkTextSub : RamaColors.lightTextSub;

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          // Ambient glow
          Positioned(
            top: -100,
            left: -80,
            child: Container(
              width: 340,
              height: 340,
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
          ),
          Positioned(
            bottom: -80,
            right: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    accent.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Centre content
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animated logo badge
                ScaleTransition(
                  scale: _logoScale,
                  child: FadeTransition(
                    opacity: _logoFade,
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [accent, accent.withValues(alpha: 0.65)],
                          begin: Alignment.topLeft,
                          end:   Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: [
                          BoxShadow(
                            color:      accent.withValues(alpha: 0.45),
                            blurRadius: 40,
                            offset:     const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color: Colors.white,
                        size: 44,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // RAMA AI title
                FadeTransition(
                  opacity: _textFade,
                  child: SlideTransition(
                    position: _textSlide,
                    child: Text(
                      'RAMA AI',
                      style: TextStyle(
                        color:       textCol,
                        fontSize:    36,
                        fontWeight:  FontWeight.w900,
                        letterSpacing: 6,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Tagline
                FadeTransition(
                  opacity: _tagFade,
                  child: Text(
                    'Your offline AI assistant',
                    style: TextStyle(
                      color:    subCol,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),

                const SizedBox(height: 48),

                // Pulse dots indicator
                FadeTransition(
                  opacity: _tagFade,
                  child: _PulseDots(accent: accent),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Animated pulse dots ──────────────────────────────────────────────────────
class _PulseDots extends StatefulWidget {
  final Color accent;
  const _PulseDots({required this.accent});

  @override
  State<_PulseDots> createState() => _PulseDotsState();
}

class _PulseDotsState extends State<_PulseDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
    _anim = Tween<double>(begin: 0, end: 1).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (ctx, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final phase   = ((_anim.value * 3) - i) % 3;
          final opacity = phase < 1
              ? phase
              : (phase < 2 ? 1.0 : 3.0 - phase);
          return Container(
            margin:    const EdgeInsets.symmetric(horizontal: 3),
            width:     7,
            height:    7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.accent.withValues(
                alpha: (0.25 + opacity.clamp(0.0, 1.0) * 0.75)),
            ),
          );
        }),
      ),
    );
  }
}
