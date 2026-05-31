import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Placeholder home menu. The full mode-card grid is Phase 4; for now this is a
/// title plus a button that navigates to the map (`/play`), proving routing is
/// wired end-to-end. CRITICAL (COMP-03): no file under features may import the
/// ad layer — it must stay unreachable from feature code (walled garden).
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'State the States',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/play'),
              child: const Text('Play'),
            ),
          ],
        ),
      ),
    );
  }
}
