import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/user_prefs_repository.dart';

/// Data container for a single tutorial slide.
class _SlideData {
  const _SlideData({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}

/// Full 4-slide PageView onboarding screen.
///
/// Both the Skip button (top-right, always visible) and the GET STARTED button
/// (last slide) call the shared [_completeTutorial] helper — satisfying the
/// RESEARCH.md Pitfall 3 invariant: `setTutorialSeen(true)` is never missed.
///
/// Navigation: both exit paths replace the current route with `context.go('/')`.
class TutorialScreen extends ConsumerStatefulWidget {
  const TutorialScreen({super.key});

  @override
  ConsumerState<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends ConsumerState<TutorialScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const List<_SlideData> _slides = [
    _SlideData(
      icon: Icons.map,
      title: 'Learn All 50 States!',
      body:
          'Place each state token on its correct location on the USA map.',
    ),
    _SlideData(
      icon: Icons.touch_app,
      title: 'Drag & Drop',
      body:
          'Drag a state token from the tray and drop it on the map. Try to place it correctly!',
    ),
    _SlideData(
      icon: Icons.sports_golf,
      title: 'Golf Scoring',
      body:
          'Lower is better. Time and wrong placements add points. Play fast and accurately!',
    ),
    _SlideData(
      icon: Icons.lightbulb,
      title: 'Use Your Hints',
      body:
          'Each round gives you 2 hints. A hint zooms the map to your target state (+5 points each).',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Shared exit helper called by both Skip and Done paths.
  ///
  /// Sets the tutorial-seen flag and navigates home. Avoids duplicating logic
  /// across the two exit points (RESEARCH.md Pitfall 3).
  Future<void> _completeTutorial() async {
    final repo = await ref.read(userPrefsRepositoryProvider.future);
    await repo.setTutorialSeen(true);
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D47A1),
      body: Stack(
        children: [
          // Main page content
          SafeArea(
            child: Column(
              children: [
                // Reserve space at top for Skip button
                const SizedBox(height: 48),
                // PageView occupies most of the screen
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _slides.length,
                    onPageChanged: (page) => setState(() => _currentPage = page),
                    itemBuilder: (context, index) {
                      final slide = _slides[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              slide.icon,
                              size: 80,
                              color: Colors.white,
                            ),
                            const SizedBox(height: 32),
                            Text(
                              slide.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              slide.body,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                // Dot indicators + Next/Done button
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Page dot indicators
                      Row(
                        children: List.generate(_slides.length, (i) {
                          return Container(
                            margin: const EdgeInsets.only(right: 8),
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: i == _currentPage
                                  ? Colors.white
                                  : Colors.white38,
                            ),
                          );
                        }),
                      ),
                      // Next or Done button
                      _currentPage < _slides.length - 1
                          ? ElevatedButton(
                              onPressed: () => _pageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              ),
                              child: const Text('NEXT'),
                            )
                          : Semantics(
                              button: true,
                              label: 'Finish tutorial',
                              child: ElevatedButton(
                                onPressed: _completeTutorial,
                                child: const Text('GET STARTED'),
                              ),
                            ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Skip button — top-right, always visible
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Semantics(
                button: true,
                label: 'Skip tutorial',
                child: TextButton(
                  onPressed: _completeTutorial,
                  child: const Text(
                    'Skip',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
