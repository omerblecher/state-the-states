import 'package:flutter/material.dart';

import 'package:state_states/features/game/game_mode.dart';
import 'package:state_states/features/game/game_session.dart';

/// A card shown on HomeScreen when a saved session is available.
///
/// Provides Continue (calls [onContinue]) and Dismiss (calls [onDismiss]).
/// Extracted as a StatelessWidget — callbacks are provided by HomeScreen.
class SessionRestoreCard extends StatelessWidget {
  const SessionRestoreCard({
    super.key,
    required this.session,
    required this.hintPenalty,
    required this.onContinue,
    required this.onDismiss,
  });

  final GameSession session;
  final int hintPenalty;
  final VoidCallback onContinue;
  final VoidCallback onDismiss;

  // Identical format to GameHud's elapsed display (game_hud.dart lines 35-37).
  String _formatElapsed(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _modeLabel(GameMode mode) {
    switch (mode) {
      case GameMode.learn:
        return 'Learn';
      case GameMode.statesMaster:
        return 'States Master';
      case GameMode.geographicalMaster:
        return 'Geographical Master';
      case GameMode.grandMaster:
        return 'Grand Master';
    }
  }

  @override
  Widget build(BuildContext context) {
    final modeLabel = _modeLabel(session.mode);
    return Semantics(
      label: 'Resume $modeLabel game, score ${session.score}',
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Color(0xFF37474F), Color(0xFF263238)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF37474F).withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.play_arrow, color: Colors.white70),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Resume $modeLabel',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    'Score: ${session.score}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Time: ${_formatElapsed(session.elapsed)}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '${session.matchedPostals.length} / 50',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      button: true,
                      label: 'Continue $modeLabel game',
                      child: ElevatedButton(
                        onPressed: onContinue,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF263238),
                        ),
                        child: const Text('CONTINUE'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Semantics(
                    button: true,
                    label: 'Dismiss saved game',
                    child: TextButton(
                      onPressed: onDismiss,
                      child: const Text(
                        'Dismiss',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
