import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_frontend/core/logging/logging_provider_observer.dart';
import 'package:soliplex_logging/soliplex_logging.dart';

final _counter = NotifierProvider<_Counter, int>(
  _Counter.new,
  name: 'counter',
);

class _Counter extends Notifier<int> {
  @override
  int build() => 0;

  void increment() => state = state + 1;
}

final _unnamed = NotifierProvider<_Unnamed, int>(_Unnamed.new);

class _Unnamed extends Notifier<int> {
  @override
  int build() => 0;

  void increment() => state = state + 1;
}

void main() {
  late MemorySink sink;

  setUp(() {
    LogManager.instance.reset();
    sink = MemorySink();
    LogManager.instance
      ..minimumLevel = LogLevel.debug
      ..addSink(sink);
  });

  tearDown(() {
    LogManager.instance
      ..removeSink(sink)
      ..reset();
    sink.close();
  });

  group('LoggingProviderObserver', () {
    test('logs state changes to State logger', () {
      final container = ProviderContainer(
        observers: [LoggingProviderObserver()],
      );
      addTearDown(container.dispose);

      // Initialize and update.
      container.read(_counter.notifier).increment();

      final stateRecords =
          sink.records.where((r) => r.loggerName == 'State').toList();
      expect(stateRecords, isNotEmpty);
      expect(stateRecords.last.message, contains('counter'));
      expect(stateRecords.last.message, contains('1'));
      expect(stateRecords.last.level, LogLevel.debug);
    });

    test('uses runtimeType when provider has no name', () {
      final container = ProviderContainer(
        observers: [LoggingProviderObserver()],
      );
      addTearDown(container.dispose);

      container.read(_unnamed.notifier).increment();

      final stateRecords =
          sink.records.where((r) => r.loggerName == 'State').toList();
      expect(stateRecords, isNotEmpty);
      expect(stateRecords.last.message, contains('1'));
    });
  });
}
