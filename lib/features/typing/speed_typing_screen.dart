import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/audio/audio_service_provider.dart';
import '../../core/data/high_score_repository.dart';
import '../../core/data/state_data_service.dart';
import '../../features/game/game_lifecycle_observer.dart';
import '../../features/game/game_mode.dart';
import '../../features/game/game_phase.dart';
import '../../features/game/game_session.dart';
import '../../features/game/game_session_notifier.dart';

/// Speed Typing Mode screen (Mode 5) — ConsumerStatefulWidget.
///
/// Lifecycle patterns ported from MapScreen:
///   - GameLifecycleObserver mounts in initState(), removed in dispose()
///   - _maybeStartGame() guard prevents duplicate startGame() calls across rebuilds
///   - _navigationPending bool + addPostFrameCallback prevents navigation during build
///   - previousBest fetched BEFORE completeGame() (Pitfall 8 / MapScreen pattern)
///
/// UI-SPEC (approved):
///   AppBar: Color(0xFF00695C), white, title 'Speed Typing'
///   HUD: grey.shade800, 48dp
///   Chip: Colors.green.shade700, white label, FontWeight.w700, fontSize 16
///   TextField: TextCapitalization.characters, enabled when stateDataProvider has value
class SpeedTypingScreen extends ConsumerStatefulWidget {
  const SpeedTypingScreen({super.key});

  @override
  ConsumerState<SpeedTypingScreen> createState() => _SpeedTypingScreenState();
}

class _SpeedTypingScreenState extends ConsumerState<SpeedTypingScreen> {
  final TextEditingController _controller = TextEditingController();

  late final GameLifecycleObserver _lifecycleObserver;

  /// Guards against duplicate startGame() calls across rebuilds (race fix).
  bool _gameStartRequested = false;

  /// Guards against navigation during build (Pitfall 2 pattern from MapScreen).
  bool _navigationPending = false;

  /// Local mute state — follows MapScreen _toggleMute pattern.
  bool _isMuted = false;

  /// Local pause overlay visibility.
  bool _isPauseOverlayVisible = false;

  @override
  void initState() {
    super.initState();
    _lifecycleObserver = GameLifecycleObserver(
      ref.read(gameSessionProvider.notifier),
    );
    WidgetsBinding.instance.addObserver(_lifecycleObserver);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
    _controller.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Game lifecycle helpers
  // ---------------------------------------------------------------------------

  /// Starts a fresh game as soon as the session is in idle or completed phase.
  ///
  /// Called on every build pass from the data callback. The _gameStartRequested
  /// flag prevents duplicate calls when the phase transitions through states.
  void _maybeStartGame(GameSession? session) {
    if (_gameStartRequested) return;
    final phase = session?.phase;
    // idle   → app just launched or navigated from home for the first time.
    // completed → user finished a game and the provider was rebuilt.
    // paused  → restoreGame() was called; do NOT override it with startGame().
    if (phase != GamePhase.idle && phase != GamePhase.completed) return;
    _gameStartRequested = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref
            .read(gameSessionProvider.notifier)
            .startGame(GameMode.speedTyping, skipCountdown: true);
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Submit handler
  // ---------------------------------------------------------------------------

  /// Called when the user submits text (Enter / Done on the keyboard).
  ///
  /// D-03: Clear _controller immediately (before guard returns) so the field
  /// is always empty after submission regardless of hit/miss.
  void _onSubmit(String value) {
    _controller.clear();

    final trimmed = value.trim().toUpperCase();
    if (trimmed.isEmpty) return;

    final mapData = ref.read(stateDataProvider).value;
    if (mapData == null) return;

    final hit = ref
        .read(gameSessionProvider.notifier)
        .submitTyping(trimmed, mapData.states);

    if (hit) {
      ref.read(audioServiceProvider).playCorrect();
    } else {
      ref.read(audioServiceProvider).playError();
    }
  }

  // ---------------------------------------------------------------------------
  // Pause / mute
  // ---------------------------------------------------------------------------

  void _onPausePressed() {
    ref.read(gameSessionProvider.notifier).pauseGame();
    setState(() => _isPauseOverlayVisible = true);
  }

  void _dismissPauseOverlay() {
    ref.read(gameSessionProvider.notifier).resumeGame();
    setState(() => _isPauseOverlayVisible = false);
  }

  void _toggleMute() {
    try {
      ref.read(audioServiceProvider).setMuted(!_isMuted);
    } catch (_) {
      // StubAudioService may not implement setMuted — silence it.
    }
    setState(() => _isMuted = !_isMuted);
  }

  // ---------------------------------------------------------------------------
  // Build helpers
  // ---------------------------------------------------------------------------

  Widget _buildTimerText(Duration elapsed) {
    final minutes = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    return Text(
      '$minutes:$seconds',
      style: const TextStyle(
        fontSize: 14,
        color: Colors.white,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
    );
  }

  Widget _buildMuteButton() {
    return Semantics(
      label: 'Toggle sound, currently ${_isMuted ? "muted" : "on"}',
      child: SizedBox(
        width: 48,
        height: 48,
        child: IconButton(
          icon: Icon(_isMuted ? Icons.volume_off : Icons.volume_up),
          color: Colors.white,
          onPressed: _toggleMute,
        ),
      ),
    );
  }

  Widget _buildPauseButton() {
    return Semantics(
      label: 'Pause game',
      child: SizedBox(
        width: 48,
        height: 48,
        child: IconButton(
          icon: const Icon(Icons.pause),
          color: Colors.white,
          onPressed: _onPausePressed,
        ),
      ),
    );
  }

  Widget _buildPauseOverlay() {
    return GestureDetector(
      onTap: () {}, // consume taps — do not dismiss on tap-outside
      child: Container(
        color: Colors.black54,
        child: Center(
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Paused',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _dismissPauseOverlay,
                      child: const Text('Resume'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _toggleMute,
                      icon: Icon(
                        _isMuted ? Icons.volume_off : Icons.volume_up,
                      ),
                      label: Text(_isMuted ? 'Unmute' : 'Mute'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: TextButton(
                      onPressed: () {
                        ref.read(gameSessionProvider.notifier).endGame();
                        context.go('/');
                      },
                      child: const Text(
                        'End Game',
                        style: TextStyle(color: Colors.red),
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

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(gameSessionProvider);
    final mapDataAsync = ref.watch(stateDataProvider);

    return sessionAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: Center(child: Text('Error loading game: $e')),
      ),
      data: (session) {
        // Start the game as soon as the session is in an eligible phase.
        _maybeStartGame(session);

        // Phase-completed navigation guard (Pitfall 2 + Pitfall 8 pattern).
        // Fetch previousBest BEFORE completeGame() so the score used for
        // comparison is the pre-completion score (MapScreen pattern).
        if (session.phase == GamePhase.completed && !_navigationPending) {
          _navigationPending = true;
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!mounted) return;
            final repo = await ref.read(highScoreRepositoryProvider.future);
            final prev = await repo.getBestScore(GameMode.speedTyping);
            // Fetch prev BEFORE completeGame() — Pitfall 8 / MapScreen pattern.
            await ref.read(gameSessionProvider.notifier).completeGame();
            if (!mounted) return;
            // ignore: use_build_context_synchronously
            context.go('/complete', extra: {
              'session': session,
              'previousBest': prev,
            });
          });
        }

        final chips = <Widget>[];
        for (final postal in session.matchedPostals) {
          // Resolve postal → full state name without package:collection.
          String stateName = postal;
          final stateList = mapDataAsync.value?.states;
          if (stateList != null) {
            for (final s in stateList) {
              if (s.postal == postal) {
                stateName = s.name;
                break;
              }
            }
          }
          chips.add(Chip(
            backgroundColor: Colors.green.shade700,
            label: Text(
              stateName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ));
        }

        final scaffold = Scaffold(
          resizeToAvoidBottomInset: true,
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: const Color(0xFF00695C),
            foregroundColor: Colors.white,
            title: const Text('Speed Typing'),
            leading: IconButton(
              icon: const Icon(Icons.home),
              tooltip: 'Back to menu',
              onPressed: () => context.go('/'),
            ),
          ),
          body: Column(
            children: [
              // HUD bar
              Container(
                height: 48,
                color: Colors.grey.shade800,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    Text(
                      'Score: ${session.score}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${session.matchedPostals.length} / 50',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    _buildTimerText(session.elapsed),
                    const SizedBox(width: 4),
                    _buildMuteButton(),
                    _buildPauseButton(),
                  ],
                ),
              ),
              // Chip grid
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: chips,
                  ),
                ),
              ),
              // Text input
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  controller: _controller,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.done,
                  onSubmitted: _onSubmit,
                  style: const TextStyle(fontSize: 16),
                  enabled: mapDataAsync.hasValue,
                  decoration: const InputDecoration(
                    hintText: 'Type a state name or code...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
        );

        if (_isPauseOverlayVisible) {
          return Stack(
            children: [
              scaffold,
              Positioned.fill(child: _buildPauseOverlay()),
            ],
          );
        }

        return scaffold;
      },
    );
  }
}
