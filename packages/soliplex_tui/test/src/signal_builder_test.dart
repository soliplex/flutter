import 'package:nocterm/nocterm.dart';
import 'package:signals_core/signals_core.dart';
import 'package:soliplex_tui/src/signal_builder.dart';
import 'package:test/test.dart';

void main() {
  group('SignalBuilder', () {
    test('renders initial signal value', () async {
      final count = signal(0);

      await testNocterm('initial value', (tester) async {
        await tester.pumpComponent(
          SignalBuilder<int>(
            signal: count,
            builder: (context, value) => Text('Count: $value'),
          ),
        );

        expect(tester.terminalState, containsText('Count: 0'));
      });
    });

    test('rebuilds when signal value changes', () async {
      final count = signal(0);

      await testNocterm('rebuild on change', (tester) async {
        await tester.pumpComponent(
          SignalBuilder<int>(
            signal: count,
            builder: (context, value) => Text('Count: $value'),
          ),
        );

        expect(tester.terminalState, containsText('Count: 0'));

        count.value = 42;
        await tester.pump();

        expect(tester.terminalState, containsText('Count: 42'));
      });
    });

    test('rebuilds on multiple changes', () async {
      final label = signal('hello');

      await testNocterm('multiple changes', (tester) async {
        await tester.pumpComponent(
          SignalBuilder<String>(
            signal: label,
            builder: (context, value) => Text('Label: $value'),
          ),
        );

        expect(tester.terminalState, containsText('Label: hello'));

        label.value = 'world';
        await tester.pump();
        expect(tester.terminalState, containsText('Label: world'));

        label.value = 'done';
        await tester.pump();
        expect(tester.terminalState, containsText('Label: done'));
      });
    });

    test('works with computed signals', () async {
      final first = signal('John');
      final last = signal('Doe');
      final full = computed(() => '${first.value} ${last.value}');

      await testNocterm('computed signal', (tester) async {
        await tester.pumpComponent(
          SignalBuilder<String>(
            signal: full,
            builder: (context, value) => Text('Name: $value'),
          ),
        );

        expect(tester.terminalState, containsText('Name: John Doe'));

        last.value = 'Smith';
        await tester.pump();

        expect(tester.terminalState, containsText('Name: John Smith'));
      });
    });
  });
}
