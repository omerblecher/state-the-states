import 'package:flutter_test/flutter_test.dart';
import 'package:state_states/features/map/completion_screen.dart';

void main() {
  group('computeStarCount', () {
    test('returns 3 for first game (previousBest == null)', () {
      expect(computeStarCount(100, null), equals(3));
    });
    test('returns 3 for personal best', () {
      expect(computeStarCount(50, 100), equals(3));
    });
    test('returns 2 for score within 20% of best', () {
      // 115 <= ceil(100 * 1.20) = 120
      expect(computeStarCount(115, 100), equals(2));
    });
    test('returns 1 for score more than 20% above best', () {
      // 125 > 120
      expect(computeStarCount(125, 100), equals(1));
    });
  });
}
