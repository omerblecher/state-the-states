import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:state_states/core/data/state_data_service.dart';

void main() {
  // rootBundle asset access + compute() require an initialized binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('stateDataProvider resolves 51 records, exactly 50 placeable', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final states = await container.read(stateDataProvider.future);

    expect(states.length, 51);
    expect(states.where((s) => s.isPlaceable).length, 50);
  });

  test('DC item is non-placeable', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final states = await container.read(stateDataProvider.future);
    final dc = states.firstWhere((s) => s.postal == 'DC');

    expect(dc.isPlaceable, isFalse);
  });
}
