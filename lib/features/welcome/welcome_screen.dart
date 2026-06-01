import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/audio/audio_service_provider.dart';
import '../../core/data/state_data_service.dart';
import '../../core/data/user_prefs_repository.dart';
import 'usa_welcome_painter.dart';

/// Opening screen — shows the deep-blue gradient background with a white USA
/// silhouette that fills in state-by-state with a stagger animation (~1.5s).
///
/// Ported from FlagsRoundTheWorld's WelcomeScreen — globe hero replaced with
/// the USA stagger painter.
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
  late final AnimationController _staggerController;
  final _random = math.Random();
  List<int> _staggerOrder = [];

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward(); // run once — states fill in over ~1.5s (D-W2)

    // Anthem fade-in starts after first frame so audioServiceProvider is ready.
    // T-05-06: AnimationController disposed in dispose() to prevent DoS.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(audioServiceProvider).fadeInAnthem();
    });
  }

  @override
  void dispose() {
    _staggerController.dispose();
    // _fadeTimer is owned by RealAudioService — no cancel needed here.
    super.dispose();
  }

  void _onStartPressed() {
    // Pitfall 5 (RESEARCH.md): do NOT await fadeOutAnthem() — fire and forget
    // so the button tap feels instant. Navigation waits 850ms for fade to begin.
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0D47A1), // deep blue
              Color(0xFF1565C0),
              Color(0xFF1976D2),
              Color(0xFF42A5F5), // sky blue
            ],
            stops: [0.0, 0.3, 0.6, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 32),

              // Title
              const Text(
                'STATE THE STATES',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1.15,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Place all 50 states on the map',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withValues(alpha: 0.85),
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 16),

              // Hero area — USA silhouette with stagger-fill animation
              Expanded(
                child: ref.watch(stateDataProvider).when(
                  loading: () => const SizedBox(height: 260),
                  error: (_, e) => const SizedBox(height: 260),
                  data: (mapData) {
                    // Compute stagger order once on first data arrival.
                    if (_staggerOrder.isEmpty) {
                      _staggerOrder =
                          List.generate(mapData.states.length, (i) => i)
                            ..shuffle(_random);
                    }
                    return AnimatedBuilder(
                      animation: _staggerController,
                      builder: (_, child) => CustomPaint(
                        painter: UsaWelcomePainter(
                          states: mapData.states,
                          staggerOrder: _staggerOrder,
                          animValue: _staggerController.value,
                        ),
                      ),
                    );
                  },
                ),
              ),

              // GET STARTED CTA button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Semantics(
                  button: true,
                  label: 'Get started, opens the game',
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _onStartPressed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF1565C0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                        elevation: 4,
                      ),
                      child: const Text(
                        'GET STARTED',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Privacy footer — Flags pattern (no url_launcher call in v1)
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
                          onPressed: () {
                            // Privacy Policy link — url_launcher deferred to v2
                          },
                          child: Text(
                            'Privacy Policy',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Text(
                      '·',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        '© 2026 Otis & Brooke',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
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
      ),
    );
  }
}
