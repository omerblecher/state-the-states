import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/user_prefs_repository.dart';

/// Tutorial screen — Plan 04 will implement the full PageView onboarding flow.
/// This stub satisfies the /tutorial route registration in app.dart and allows
/// the WelcomeScreen navigation to compile and run in the interim.
class TutorialScreen extends ConsumerStatefulWidget {
  const TutorialScreen({super.key});

  @override
  ConsumerState<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends ConsumerState<TutorialScreen> {
  Future<void> _completeTutorial() async {
    final repo = await ref.read(userPrefsRepositoryProvider.future);
    await repo.setTutorialSeen(true);
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Tutorial',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _completeTutorial,
                child: const Text('Get Started'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
