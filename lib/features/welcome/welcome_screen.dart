import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/audio/audio_service_provider.dart';
import '../../core/data/state_data_service.dart';
import '../../core/data/user_prefs_repository.dart';
import 'usa_welcome_painter.dart';

// ── Star data model ────────────────────────────────────────────────────────

class _Star {
  final double x;     // 0.0–1.0 fractional horizontal position
  final double y;     // 0.0–1.0 fractional vertical position
  final double size;  // radius in logical pixels (0.7–2.1)
  final double phase; // twinkle phase offset 0.0–1.0

  const _Star({
    required this.x,
    required this.y,
    required this.size,
    required this.phase,
  });
}

// ── Star field painter ────────────────────────────────────────────────────

class _StarFieldPainter extends CustomPainter {
  const _StarFieldPainter({
    required this.stars,
    required this.twinkleValue,
  });

  final List<_Star> stars;
  final double twinkleValue; // AnimationController.value, 0.0 → 1.0, repeating

  @override
  bool shouldRepaint(covariant _StarFieldPainter old) =>
      (old.twinkleValue - twinkleValue).abs() > 0.005;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final star in stars) {
      // Each star has its own sine-wave phase so they twinkle independently.
      final raw = (twinkleValue + star.phase) % 1.0;
      final opacity = 0.10 + 0.58 * (0.5 + 0.5 * math.sin(raw * 2 * math.pi));
      paint.color = Colors.white.withValues(alpha: opacity);
      canvas.drawCircle(
        Offset(star.x * size.width, star.y * size.height),
        star.size,
        paint,
      );
    }
  }
}

// ── Title widget with glow text shadows ───────────────────────────────────

class _TitleWidget extends StatelessWidget {
  const _TitleWidget();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Text(
        'STATE THE STATES',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          height: 1.15,
          letterSpacing: 2.5,
          shadows: [
            // Near-white halo for lift
            Shadow(
              color: Colors.white.withValues(alpha: 0.25),
              blurRadius: 16,
            ),
            // Deep-blue bloom for depth
            Shadow(
              color: const Color(0xFF60A0E8).withValues(alpha: 0.55),
              blurRadius: 32,
              offset: const Offset(0, 4),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Pulsing CTA button ────────────────────────────────────────────────────

class _PulsingButton extends StatelessWidget {
  const _PulsingButton({
    required this.glowIntensity,
    required this.onPressed,
    required this.child,
  });

  final double glowIntensity; // 0.0–1.0 from the pulse controller
  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Get started, opens the game',
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.15 + glowIntensity * 0.42),
              blurRadius: 8 + glowIntensity * 24,
              spreadRadius: glowIntensity * 4,
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF0A2F70),
            overlayColor: const Color(0xFF1148A8),
            splashFactory: InkRipple.splashFactory,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            elevation: 4 + glowIntensity * 4,
            shadowColor: Colors.white.withValues(alpha: 0.2),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ── WelcomeScreen ─────────────────────────────────────────────────────────

/// Opening screen — deep-navy gradient with ambient star field, animated USA
/// hero silhouette (parchment + gold, stagger-fills then floats), and a
/// pulsing GET STARTED CTA.
///
/// Requirements: WEL-01 (premium opening screen), WEL-02 (anthem on load),
/// WEL-03 (fade-out on navigation).
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen>
    with TickerProviderStateMixin {

  // ── Animation controllers ─────────────────────────────────────────────
  late final AnimationController _staggerCtrl; // state fill-in (1.5 s, once)
  late final AnimationController _introCtrl;   // entry reveals  (1.2 s, once)
  late final AnimationController _floatCtrl;   // map float      (3.6 s, ∞)
  late final AnimationController _pulseCtrl;   // button glow    (2.0 s, ∞)
  late final AnimationController _starCtrl;    // star twinkle   (3.5 s, ∞)

  // ── Intro fade+slide animations ───────────────────────────────────────
  late final Animation<double> _titleFade;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _subtitleFade;
  late final Animation<Offset> _subtitleSlide;
  late final Animation<double> _mapFade;
  late final Animation<Offset> _mapSlide;
  late final Animation<double> _buttonFade;
  late final Animation<Offset> _buttonSlide;

  // ── Continuous animations ─────────────────────────────────────────────
  late final Animation<double> _floatOffset; // logical px: -9 ↔ +9
  late final Animation<double> _pulseGlow;   // 0.0 ↔ 1.0

  // ── State ─────────────────────────────────────────────────────────────
  final _random = math.Random();
  late final List<_Star> _stars;
  List<int> _staggerOrder = [];

  // ── Helpers: build interval-based intro animations ─────────────────

  Animation<double> _fadeIn(double begin, double end) =>
      Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _introCtrl,
          curve: Interval(begin, end, curve: Curves.easeOut),
        ),
      );

  Animation<Offset> _slideIn(double begin, double end, {double dy = 0.3}) =>
      Tween<Offset>(begin: Offset(0, dy), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _introCtrl,
          curve: Interval(begin, end, curve: Curves.easeOut),
        ),
      );

  @override
  void initState() {
    super.initState();

    // 1. State-fill stagger (unchanged from original)
    _staggerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();

    // 2. Entry reveals — elements appear in a tight staggered cascade
    _introCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();

    _titleFade    = _fadeIn(0.00, 0.40);
    _titleSlide   = _slideIn(0.00, 0.40);
    _subtitleFade = _fadeIn(0.10, 0.55);
    _subtitleSlide= _slideIn(0.10, 0.55);
    _mapFade      = _fadeIn(0.20, 0.75);
    _mapSlide     = _slideIn(0.20, 0.75, dy: 0.12);
    _buttonFade   = _fadeIn(0.50, 1.00);
    _buttonSlide  = _slideIn(0.50, 1.00);

    // 3. Map float — smooth perpetual up/down translation
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat(reverse: true);

    _floatOffset = Tween<double>(begin: -9.0, end: 9.0).animate(
      CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut),
    );

    // 4. Button glow pulse
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _pulseGlow = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    // 5. Star twinkle — non-reversing; phase offsets create variety
    _starCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    )..repeat();

    // Generate star field once with a fixed seed (consistent layout, no
    // per-frame allocation).
    final rng = math.Random(13);
    _stars = List.generate(26, (_) => _Star(
      x:     rng.nextDouble(),
      y:     rng.nextDouble(),
      size:  0.7 + rng.nextDouble() * 1.4,
      phase: rng.nextDouble(),
    ));

    // Anthem fade-in after first frame so audioServiceProvider is ready.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(audioServiceProvider).fadeInAnthem();
    });
  }

  @override
  void dispose() {
    _staggerCtrl.dispose();
    _introCtrl.dispose();
    _floatCtrl.dispose();
    _pulseCtrl.dispose();
    _starCtrl.dispose();
    super.dispose();
  }

  void _onStartPressed() {
    // Fire-and-forget anthem fade — do NOT await (keeps tap feel instant).
    ref.read(audioServiceProvider).fadeOutAnthem();
    Future.delayed(const Duration(milliseconds: 850), () async {
      if (!mounted) return;
      final repo = await ref.read(userPrefsRepositoryProvider.future);
      if (!mounted) return;
      final seen = await repo.getTutorialSeen();
      if (!mounted) return;
      context.go(seen ? '/' : '/tutorial');
    });
  }

  // ── Map hero ──────────────────────────────────────────────────────────

  Widget _buildMapHero() {
    return ref.watch(stateDataProvider).when(
      loading: () => const SizedBox.shrink(),
      error:   (_, _) => const SizedBox.shrink(),
      data: (mapData) {
        if (_staggerOrder.isEmpty) {
          _staggerOrder = List.generate(mapData.states.length, (i) => i)
            ..shuffle(_random);
        }
        return AnimatedBuilder(
          animation: _staggerCtrl,
          builder: (_, _) => CustomPaint(
            painter: UsaWelcomePainter(
              states:      mapData.states,
              staggerOrder: _staggerOrder,
              animValue:   _staggerCtrl.value,
              fillColor:   const Color(0xFFF0EBDF), // warm parchment
              strokeColor: const Color(0xFFC8A84B), // antique gold
              strokeWidth: 0.9,
            ),
          ),
        );
      },
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF03143A), // near-black navy (top)
              Color(0xFF0A2F70), // deep dark blue
              Color(0xFF1148A8), // rich royal blue
              Color(0xFF1F66CC), // vibrant blue (bottom)
            ],
            stops: [0.0, 0.25, 0.65, 1.0],
          ),
        ),
        child: Stack(
          children: [

            // ── Ambient star field ────────────────────────────────────
            // Painted directly on the gradient; does not repaint during
            // layout or map-float frames — only on _starCtrl ticks.
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _starCtrl,
                builder: (_, _) => CustomPaint(
                  painter: _StarFieldPainter(
                    stars: _stars,
                    twinkleValue: _starCtrl.value,
                  ),
                ),
              ),
            ),

            // ── Main content ──────────────────────────────────────────
            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 36),

                  // Title
                  FadeTransition(
                    opacity: _titleFade,
                    child: SlideTransition(
                      position: _titleSlide,
                      child: const _TitleWidget(),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Subtitle
                  FadeTransition(
                    opacity: _subtitleFade,
                    child: SlideTransition(
                      position: _subtitleSlide,
                      child: Text(
                        'Place all 50 states on the map',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withValues(alpha: 0.82),
                          height: 1.5,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Hero map — fades/slides in, then floats perpetually.
                  // The float uses Transform.translate (GPU layer move, no
                  // CustomPaint repaint) so the stagger painter only redraws
                  // during its own 1.5 s fill-in phase.
                  Expanded(
                    child: FadeTransition(
                      opacity: _mapFade,
                      child: SlideTransition(
                        position: _mapSlide,
                        child: AnimatedBuilder(
                          animation: _floatCtrl,
                          builder: (_, child) => Transform.translate(
                            offset: Offset(0, _floatOffset.value),
                            child: child,
                          ),
                          // child is built once and reused on every float tick
                          child: _buildMapHero(),
                        ),
                      ),
                    ),
                  ),

                  // GET STARTED button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: FadeTransition(
                      opacity: _buttonFade,
                      child: SlideTransition(
                        position: _buttonSlide,
                        child: AnimatedBuilder(
                          animation: _pulseCtrl,
                          builder: (_, child) => _PulsingButton(
                            glowIntensity: _pulseGlow.value,
                            onPressed: _onStartPressed,
                            child: child!,
                          ),
                          child: const Text(
                            'GET STARTED',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Privacy footer
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Semantics(
                          button: true,
                          label: 'View privacy policy',
                          child: SizedBox(
                            height: 48,
                            child: TextButton(
                              onPressed: () => launchUrl(
                                Uri.parse('https://omerblecher.github.io/state-the-states/privacy-policy.html'),
                                mode: LaunchMode.externalApplication,
                              ),
                              child: Text(
                                'Privacy Policy',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.55),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Text(
                          '·',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.35),
                            fontSize: 12,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            '© 2026 Otis & Brooke',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.35),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          ],
        ),
      ),
    );
  }
}
