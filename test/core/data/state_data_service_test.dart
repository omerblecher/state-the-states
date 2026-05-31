import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:state_states/core/data/state_data_service.dart';

void main() {
  // rootBundle asset access + compute() require an initialized binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('stateDataProvider resolves 51 records, exactly 50 placeable', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final mapData = await container.read(stateDataProvider.future);

    expect(mapData.states.length, 51);
    expect(mapData.states.where((s) => s.isPlaceable).length, 50);
  });

  test('DC item is non-placeable', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final mapData = await container.read(stateDataProvider.future);
    final dc = mapData.states.firstWhere((s) => s.postal == 'DC');

    expect(dc.isPlaceable, isFalse);
  });

  test('stateDataProvider resolves 2 inset frame rects (alaska, hawaii)', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final mapData = await container.read(stateDataProvider.future);

    expect(mapData.insetFrameRects.length, 2);
    // Alaska frame: x≈0
    expect(mapData.insetFrameRects[0].left, closeTo(0.0, 1.0));
    // Hawaii frame: x≈255
    expect(mapData.insetFrameRects[1].left, closeTo(255.0, 1.0));
  });
}
