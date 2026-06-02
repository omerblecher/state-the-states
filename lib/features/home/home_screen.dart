import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:state_states/core/data/game_state_repository.dart';
import 'package:state_states/core/data/high_score_repository.dart';
import 'package:state_states/features/game/game_mode.dart';
import 'package:state_states/features/game/game_session.dart';
import 'package:state_states/features/game/game_session_notifier.dart';
import 'package:state_states/features/map/completion_screen.dart';
import 'session_restore_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final repoAsync = ref.watch(highScoreRepositoryProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: SafeArea(
        child: repoAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (repo) => _buildBody(context, repo),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, HighScoreRepository repo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Session restore card (HOME-03): shown when a saved session exists.
        FutureBuilder<({GameSession session, int hintPenalty})?>(
          future: ref
              .read(gameStateRepositoryProvider.future)
              .then((r) => r.loadSession()),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data == null) {
              return const SizedBox.shrink();
            }
            final saved = snapshot.data!;
            return SessionRestoreCard(
              session: saved.session,
              hintPenalty: saved.hintPenalty,
              onContinue: () {
                ref
                    .read(gameSessionProvider.notifier)
                    .restoreGame(saved.session, hintPenalty: saved.hintPenalty);
                final route = saved.session.mode == GameMode.speedTyping
                    ? '/type'
                    : '/play';
                context.go(route, extra: saved.session.mode);
              },
              onDismiss: () {
                ref.read(gameSessionProvider.notifier).endGame();
                if (mounted) setState(() {});
              },
            );
          },
        ),
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 12, 4),
          child: Row(
            children: [
              const Icon(Icons.map, color: Color(0xFF1565C0), size: 28),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'State the States',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0D2E6B),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Subtitle
        const Padding(
          padding: EdgeInsets.only(left: 20, bottom: 12),
          child: Text(
            'Choose a mode',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ),
        // Mode cards
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _ModeCard(
                mode: GameMode.learn,
                name: 'Learn',
                description:
                    'Drag each state to the map. Abbreviations shown as hints.',
                icon: Icons.explore,
                cardColor: const Color(0xFF2E7D32),
                bestScoreFuture: repo.getBestScore(GameMode.learn),
                onTap: () => context.go('/play', extra: GameMode.learn),
              ),
              const SizedBox(height: 12),
              _ModeCard(
                mode: GameMode.statesMaster,
                name: 'States Master',
                description:
                    'Place all 50 states by name with no map labels.',
                icon: Icons.flag,
                cardColor: const Color(0xFF1565C0),
                bestScoreFuture: repo.getBestScore(GameMode.statesMaster),
                onTap: () =>
                    context.go('/play', extra: GameMode.statesMaster),
              ),
              const SizedBox(height: 12),
              _ModeCard(
                mode: GameMode.geographicalMaster,
                name: 'Geographical Master',
                description:
                    'Abbreviations on the map, nothing in your hand.',
                icon: Icons.compass_calibration,
                cardColor: const Color(0xFFBF360C),
                bestScoreFuture:
                    repo.getBestScore(GameMode.geographicalMaster),
                onTap: () =>
                    context.go('/play', extra: GameMode.geographicalMaster),
              ),
              const SizedBox(height: 12),
              _ModeCard(
                mode: GameMode.grandMaster,
                name: 'Grand Master',
                description: 'No labels, no names. Pure geography.',
                icon: Icons.emoji_events,
                cardColor: const Color(0xFF4A148C),
                bestScoreFuture: repo.getBestScore(GameMode.grandMaster),
                onTap: () =>
                    context.go('/play', extra: GameMode.grandMaster),
              ),
              const SizedBox(height: 12),
              _ModeCard(
                mode: GameMode.speedTyping,
                name: 'Speed Typing',
                description: 'Name all 50 states by typing — beat the clock.',
                icon: Icons.keyboard,
                cardColor: const Color(0xFF00695C),
                bestScoreFuture: repo.getBestScore(GameMode.speedTyping),
                onTap: () => context.go('/type'),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
        // Privacy footer
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Center(
            child: Semantics(
              button: true,
              label: 'View privacy policy',
              child: SizedBox(
                height: 48,
                child: TextButton(
                  onPressed: () {},
                  child: const Text(
                    'Privacy Policy',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Mode card widget
// ---------------------------------------------------------------------------

class _ModeCard extends StatefulWidget {
  final GameMode mode;
  final String name;
  final String description;
  final IconData icon;
  final Color cardColor;
  final Future<int?> bestScoreFuture;
  final VoidCallback onTap;

  const _ModeCard({
    required this.mode,
    required this.name,
    required this.description,
    required this.icon,
    required this.cardColor,
    required this.bestScoreFuture,
    required this.onTap,
  });

  @override
  State<_ModeCard> createState() => _ModeCardState();
}

class _ModeCardState extends State<_ModeCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
      reverseDuration: const Duration(milliseconds: 150),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  int _starsForScore(int? score) {
    if (score == null) return 0;
    // Use the same D-11 formula as CompletionScreen. A stored best score is by
    // definition a personal best (previousBest=null), so it always earns 3 stars.
    return computeStarCount(score, null);
  }

  Widget _buildCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            widget.cardColor,
            Color.lerp(widget.cardColor, Colors.black, 0.2)!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: widget.cardColor.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Mode icon container
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.white.withValues(alpha: 0.2),
              ),
              child: Icon(widget.icon, size: 28, color: Colors.white),
            ),
            const SizedBox(width: 12),
            // Name + description column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.name,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Score + stars column
            FutureBuilder<int?>(
              future: widget.bestScoreFuture,
              builder: (ctx, snap) {
                final stars = snap.hasData ? _starsForScore(snap.data) : 0;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(3, (i) {
                        return Icon(
                          i < stars
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: i < stars
                              ? Colors.amber
                              : Colors.white.withValues(alpha: 0.4),
                          size: 18,
                        );
                      }),
                    ),
                    const SizedBox(height: 4),
                    if (snap.hasData && snap.data != null)
                      Text(
                        'Best: ${snap.data}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 11,
                        ),
                      )
                    else
                      Text(
                        'Not played',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 11,
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _scaleController.forward(),
      onTapUp: (_) {
        _scaleController.reverse();
        widget.onTap();
      },
      onTapCancel: () => _scaleController.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (_, child) => Transform.scale(
          scale: _scaleAnim.value,
          child: child,
        ),
        child: Semantics(
          button: true,
          label: '${widget.name} mode',
          child: _buildCard(),
        ),
      ),
    );
  }
}
