import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import 'entry_point.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Logo pop-in
  late final AnimationController _logoCtrl;
  late final Animation<double>   _logoScale;
  late final Animation<double>   _logoFade;

  // Text fade+slide
  late final AnimationController _textCtrl;
  late final Animation<double>   _textFade;
  late final Animation<Offset>   _textSlide;

  // Tagline fade
  late final AnimationController _tagCtrl;
  late final Animation<double>   _tagFade;

  // Dots fade
  late final AnimationController _dotsCtrl;

  @override
  void initState() {
    super.initState();

    _logoCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 750),
    );
    _logoScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut));
    _logoFade = CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOut);

    _textCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 550),
    );
    _textFade  = CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut);
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end:   Offset.zero,
    ).animate(CurvedAnimation(parent: _textCtrl, curve: Curves.easeOutCubic));

    _tagCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 450),
    );
    _tagFade = CurvedAnimation(parent: _tagCtrl, curve: Curves.easeOut);

    _dotsCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 900),
    )..repeat();

    _run();
  }

  Future<void> _run() async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    _logoCtrl.forward();
    await Future<void>.delayed(const Duration(milliseconds: 380));
    _textCtrl.forward();
    await Future<void>.delayed(const Duration(milliseconds: 280));
    _tagCtrl.forward();
    await Future<void>.delayed(const Duration(milliseconds: 950));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder:    (_, a1, a2) => const EntryPoint(),
        transitionsBuilder: (context, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _textCtrl.dispose();
    _tagCtrl.dispose();
    _dotsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent   = appTheme.accent;
    final isDark   = appTheme.isDark;
    final bg       = isDark ? RamaColors.darkBg      : RamaColors.lightBg;
    final textCol  = isDark ? RamaColors.darkText     : RamaColors.lightText;
    final subCol   = isDark ? RamaColors.darkTextSub  : RamaColors.lightTextSub;

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Ambient glows ──────────────────────────────────────────────────
          Positioned(
            top: -120, left: -100,
            child: _Glow(color: accent, size: 360, alpha: 0.18),
          ),
          Positioned(
            bottom: -100, right: -80,
            child: _Glow(color: accent, size: 280, alpha: 0.12),
          ),

          // ── Centre content ─────────────────────────────────────────────────
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo
                ScaleTransition(
                  scale: _logoScale,
                  child: FadeTransition(
                    opacity: _logoFade,
                    child: Container(
                      width: 92, height: 92,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [accent, accent.withValues(alpha: 0.62)],
                          begin: Alignment.topLeft,
                          end:   Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: [
                          BoxShadow(
                            color:      accent.withValues(alpha: 0.42),
                            blurRadius: 42,
                            offset:     const Offset(0, 12),
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
                const SizedBox(height: 28),

                // RAMA AI title
                FadeTransition(
                  opacity: _textFade,
                  child: SlideTransition(
                    position: _textSlide,
                    child: Text(
                      'RAMA AI',
                      style: TextStyle(
                        color:         textCol,
                        fontSize:      34,
                        fontWeight:    FontWeight.w900,
                        letterSpacing: 7,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Tagline
                FadeTransition(
                  opacity: _tagFade,
                  child: Text(
                    'Your 100% offline AI assistant',
                    style: TextStyle(
                      color:      subCol,
                      fontSize:   14,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                const SizedBox(height: 50),

                // Dots
                FadeTransition(
                  opacity: _tagFade,
                  child: AnimatedBuilder(
                    animation: _dotsCtrl,
                    builder: (context, _) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(3, (i) {
                        final phase   = ((_dotsCtrl.value * 3) - i) % 3;
                        final opacity = phase < 1
                            ? phase
                            : (phase < 2 ? 1.0 : 3.0 - phase);
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: 7, height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: accent.withValues(
                                alpha: 0.25 + opacity.clamp(0.0, 1.0) * 0.75),
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

class _Glow extends StatelessWidget {
  final Color  color;
  final double size;
  final double alpha;
  const _Glow({required this.color, required this.size, required this.alpha});

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
