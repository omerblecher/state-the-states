import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import 'package:state_states/features/game/game_mode.dart';
import 'package:state_states/features/game/game_session.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';

/// Returns the number of stars (1–3) earned for this game result.
///
/// D-11 formula (lower score is better — golf-style):
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

/// Full completion screen shown after all 50 states are placed.
///
/// Shows a 1–3 star rating (D-11), personal-best badge with confetti overlay,
/// a score card with stat rows, and Back to Menu / Play Again CTAs.
/// Share flow is widget-layer only; GameSessionNotifier has zero ad/share imports (COMP-03 walled-garden).
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
  int _starCount = 3;
  bool _isNewPb = false;
  bool _showPbOverlay = false;
  late AnimationController _pbController;
  final GlobalKey _scoreCardKey = GlobalKey();
  bool _isSharing = false;

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

  Future<void> _onSharePressed() async {
    final passed = await _showParentalGate();
    if (passed != true || !mounted) return;
    await _captureAndShare();
  }

  Future<bool?> _showParentalGate() {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const MathChallengeDialog(),
    );
  }

  Future<void> _captureAndShare() async {
    if (!mounted) return;
    File? file;
    try {
      final boundary = _scoreCardKey.currentContext
          ?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final bytes = byteData.buffer.asUint8List();
      file = File('${Directory.systemTemp.path}/score_card.png');
      await file.writeAsBytes(bytes);

      final modeName = widget.session.mode.displayName;
      final score = widget.session.score;

      if (mounted) setState(() => _isSharing = true);
      await SharePlus.instance.share(ShareParams(
        text:
            'New lowest score in $modeName! Score: $score — State the States 🇺🇸',
        files: [XFile(file.path)],
      ));
    } finally {
      file?.deleteSync();
      if (mounted) setState(() => _isSharing = false);
    }
  }

  Color _modeColor(GameMode mode) => switch (mode) {
        GameMode.learn => const Color(0xFF2E7D32),
        GameMode.statesMaster => const Color(0xFF1565C0),
        GameMode.geographicalMaster => const Color(0xFFBF360C),
        GameMode.grandMaster => const Color(0xFF4A148C),
        GameMode.speedTyping => const Color(0xFF00695C),
      };

  String _formatTime(Duration elapsed) {
    final minutes = elapsed.inMinutes;
    final seconds = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '${minutes}m ${seconds}s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: _modeColor(widget.session.mode),
        foregroundColor: Colors.white,
        title: Text(widget.session.mode.displayName),
        leading: IconButton(
          icon: const Icon(Icons.home),
          tooltip: 'Back to menu',
          onPressed: () => context.go('/'),
        ),
      ),
      body: Stack(
        children: [
          _buildBody(),
          if (_showPbOverlay) _buildConfettiOverlay(),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final modeColor = _modeColor(widget.session.mode);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Star row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              3,
              (i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  i < _starCount
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  color:
                      i < _starCount ? Colors.amber : Colors.grey.shade400,
                  size: 56,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Well done! title
          Text(
            'Well done!',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: modeColor,
            ),
            textAlign: TextAlign.center,
          ),
          // Personal best badge
          if (_isNewPb)
            Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: Colors.amber.shade700,
                  ),
                  child: const Text(
                    'New Personal Best!',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 32),
          // Score card
          RepaintBoundary(
            key: _scoreCardKey,
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _StatRow(
                      label: 'Score',
                      value: '${widget.session.score}',
                    ),
                    const Divider(height: 24),
                    _StatRow(
                      label: 'Time',
                      value: _formatTime(widget.session.elapsed),
                    ),
                    const Divider(height: 24),
                    _StatRow(
                      label: 'Mode',
                      value: widget.session.mode.displayName,
                    ),
                    if (widget.previousBest != null) ...[
                      const Divider(height: 24),
                      _StatRow(
                        label: 'Previous best',
                        value: '${widget.previousBest}',
                      ),
                    ],
                  ],
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
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.home),
              label: const Text(
                'Back to Menu',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Secondary CTA — play again same mode
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () {
                final route = widget.session.mode == GameMode.speedTyping
                    ? '/type'
                    : '/play';
                context.go(route, extra: widget.session.mode);
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: modeColor,
                side: BorderSide(color: modeColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.replay),
              label: const Text('Play Again'),
            ),
          ),
          if (_isNewPb) ...[
            const SizedBox(height: 12),
            if (_isSharing)
              const SizedBox(
                height: 48,
                child: Center(child: CircularProgressIndicator()),
              )
            else
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _onSharePressed,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey.shade700,
                    side: BorderSide(color: Colors.grey.shade400),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.share),
                  label: const Text('Share result'),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildConfettiOverlay() {
    return AnimatedBuilder(
      animation: _pbController,
      builder: (ctx, _) {
        final opacity = _pbController.value < 0.8
            ? 1.0
            : (1.0 - ((_pbController.value - 0.8) / 0.2)).clamp(0.0, 1.0);
        return IgnorePointer(
          child: Opacity(
            opacity: opacity,
            child: SizedBox.expand(
              child: CustomPaint(
                painter: _ConfettiPainter(progress: _pbController.value),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// COPPA-required adult verification before sharing.
/// Shows a simple multiplication problem; only a grown-up who can do mental arithmetic
/// can proceed, preventing a child from accidentally sharing.
@visibleForTesting
class MathChallengeDialog extends StatefulWidget {
  const MathChallengeDialog({super.key});

  @override
  State<MathChallengeDialog> createState() => _MathChallengeDialogState();
}

class _MathChallengeDialogState extends State<MathChallengeDialog> {
  final _controller = TextEditingController();
  String? _error;
  late int _a;
  late int _b;

  @override
  void initState() {
    super.initState();
    final rng = math.Random();
    _a = 10 + rng.nextInt(90);
    _b = 2 + rng.nextInt(8);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onConfirm() {
    final entered = int.tryParse(_controller.text.trim());
    if (entered == _a * _b) {
      Navigator.of(context).pop(true);
    } else {
      _controller.clear();
      final rng = math.Random();
      _a = 10 + rng.nextInt(90);
      _b = 2 + rng.nextInt(8);
      setState(() => _error = 'Incorrect — try again');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Grown-up check'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('To share, a grown-up needs to answer:'),
          const SizedBox(height: 16),
          Text(
            'What is $_a × $_b?',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Answer',
              errorText: _error,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => _onConfirm(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _onConfirm,
          child: const Text('Share'),
        ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;

  const _StatRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Colors.grey.shade600,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.right,
        ),
      ],
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
      Colors.orange,
    ];
    return List.generate(
      40,
      (i) => _Particle(
        x: rng.nextDouble(),
        speed: 0.5 + rng.nextDouble(),
        color: colors[i % colors.length],
      ),
    );
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
