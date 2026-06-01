import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:state_states/features/game/game_mode.dart';
import 'package:state_states/features/game/game_session.dart';

/// Returns the number of stars (1–3) earned for this game result.
///
/// D-11 formula:
/// - previousBest == null → 3 (first ever game)
/// - score < previousBest  → 3 (personal best)
/// - score <= ceil(previousBest * 1.20) → 2 (within 20%)
/// - otherwise → 1
int computeStarCount(int score, int? previousBest) {
  if (previousBest == null) return 3;
  if (score < previousBest) return 3;
  if (score <= (previousBest * 1.20).ceil()) return 2;
  return 1;
}

/// Stub completion screen shown after all 50 states are placed.
///
/// Plan 04-01: stub only — score display and navigation CTAs.
/// Plan 04-05: full UI (star animation, confetti, time display).
class CompletionScreen extends ConsumerStatefulWidget {
  const CompletionScreen({
    super.key,
    required this.session,
    this.previousBest,
  });

  final GameSession session;
  final int? previousBest;

  @override
  ConsumerState<CompletionScreen> createState() => _CompletionScreenState();
}

class _CompletionScreenState extends ConsumerState<CompletionScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pbController;
  late final int _starCount;
  bool _isNewPb = false;
  bool _showPbOverlay = false;

  @override
  void initState() {
    super.initState();
    final prev = widget.previousBest;
    final score = widget.session.score;
    if (prev == null) {
      _isNewPb = false;
      _starCount = 3;
    } else if (score < prev) {
      _isNewPb = true;
      _starCount = 3;
    } else if (score <= (prev * 1.20).ceil()) {
      _isNewPb = false;
      _starCount = 2;
    } else {
      _isNewPb = false;
      _starCount = 1;
    }

    _pbController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    if (_isNewPb) {
      setState(() => _showPbOverlay = true);
      _pbController.forward().whenComplete(() {
        if (mounted) setState(() => _showPbOverlay = false);
      });
    }
    // NOTE: NO ad call here (D-13 — v2 only)
  }

  @override
  void dispose() {
    _pbController.dispose();
    super.dispose();
  }

  Color _modeColor(GameMode mode) => switch (mode) {
        GameMode.learn => const Color(0xFF2E7D32),
        GameMode.statesMaster => const Color(0xFF1565C0),
        GameMode.geographicalMaster => const Color(0xFFE65100),
        GameMode.grandMaster => const Color(0xFF4A148C),
      };

  @override
  Widget build(BuildContext context) {
    final modeColor = _modeColor(widget.session.mode);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.session.mode.name),
        backgroundColor: modeColor,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Score display
                Center(
                  child: Text(
                    'Score: ${widget.session.score}',
                    style: const TextStyle(
                        fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                ),
                // Stars
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                      3,
                      (i) => Icon(
                        i < _starCount
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: i < _starCount ? Colors.amber : Colors.grey,
                        size: 40,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                // Primary CTA — back to home
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: () => context.go('/'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: modeColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.home),
                    label: const Text('Back to Menu',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 12),
                // Secondary CTA — play again same mode
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        context.go('/play', extra: widget.session.mode),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: modeColor,
                      side: BorderSide(color: modeColor),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.replay),
                    label: const Text('Play Again'),
                  ),
                ),
                // NOTE: NO share button (D-13 — v2 only)
              ],
            ),
          ),
          // Confetti overlay for personal best
          if (_showPbOverlay)
            AnimatedBuilder(
              animation: _pbController,
              builder: (ctx, _) {
                final opacity = _pbController.value < 0.8
                    ? 1.0
                    : (1.0 - ((_pbController.value - 0.8) / 0.2))
                        .clamp(0.0, 1.0);
                return IgnorePointer(
                  child: Opacity(
                    opacity: opacity,
                    child: Positioned.fill(
                      child: CustomPaint(
                        painter:
                            _ConfettiPainter(progress: _pbController.value),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _Particle {
  final double x;
  final double speed;
  final Color color;
  const _Particle({required this.x, required this.speed, required this.color});
}

class _ConfettiPainter extends CustomPainter {
  final double progress;
  static final List<_Particle> _particles = _generateParticles();
  const _ConfettiPainter({required this.progress});

  static List<_Particle> _generateParticles() {
    final rng = math.Random(42); // seed 42 = deterministic
    final colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.yellow,
      Colors.purple,
      Colors.orange
    ];
    return List.generate(
        40,
        (i) => _Particle(
              x: rng.nextDouble(),
              speed: 0.5 + rng.nextDouble(),
              color: colors[i % colors.length],
            ));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in _particles) {
      final px = p.x * size.width +
          math.sin(progress * math.pi * 3 + p.x * math.pi * 2) * 20;
      final py = progress * p.speed * size.height;
      final opacity = (1.0 - progress * 1.2).clamp(0.0, 1.0);
      paint.color = p.color.withValues(alpha: opacity);
      canvas.drawCircle(Offset(px, py), 6, paint);
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}
