import 'dart:io';

import 'package:mocktail/mocktail.dart';
import 'package:soliplex_agent/soliplex_agent.dart';
import 'package:soliplex_tui/src/host/tui_host_api.dart';
import 'package:test/test.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class _MockAgentSession extends Mock implements AgentSession {
  _MockAgentSession({this.approveAll = true});

  final bool approveAll;

  @override
  Future<bool> requestApproval({
    required String toolCallId,
    required String toolName,
    required Map<String, dynamic> arguments,
    required String rationale,
  }) async =>
      approveAll;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late TuiHostApi api;

  setUp(() {
    api = TuiHostApi();
  });

  // =========================================================================
  // 1. DataFrame handle management
  // =========================================================================

  group('registerDataFrame / getDataFrame', () {
    test('returns incrementing handles', () {
      final h1 = api.registerDataFrame({
        'a': [1, 2],
      });
      final h2 = api.registerDataFrame({
        'b': [3, 4],
      });

      expect(h1, 1);
      expect(h2, 2);
    });

    test('getDataFrame retrieves registered frame', () {
      final columns = {
        'name': <Object?>['Alice', 'Bob'],
        'age': <Object?>[30, 25],
      };
      final handle = api.registerDataFrame(columns);

      final result = api.getDataFrame(handle);
      expect(result, isNotNull);
      expect(result!['name'], ['Alice', 'Bob']);
      expect(result['age'], [30, 25]);
    });

    test('getDataFrame returns null for unknown handle', () {
      expect(api.getDataFrame(999), isNull);
    });

    test('stored frame is unmodifiable', () {
      final handle = api.registerDataFrame({
        'x': [1],
      });
      final frame = api.getDataFrame(handle)!;

      expect(() => frame['y'] = [2], throwsA(isA<UnsupportedError>()));
    });
  });

  // =========================================================================
  // 2. Chart handle management
  // =========================================================================

  group('registerChart / updateChart', () {
    test('returns incrementing handles', () {
      final h1 = api.registerChart({'type': 'bar'});
      final h2 = api.registerChart({'type': 'line'});

      expect(h1, 1);
      expect(h2, 2);
    });

    test('updateChart replaces config', () {
      final handle = api.registerChart({'type': 'bar'});

      final updated = api.updateChart(handle, {'type': 'line'});
      expect(updated, isTrue);
    });

    test('updateChart returns false for unknown handle', () {
      expect(api.updateChart(999, {'type': 'bar'}), isFalse);
    });
  });

  // =========================================================================
  // 3. Handle counter is shared between DataFrames and charts
  // =========================================================================

  test('DataFrame and chart handles share counter', () {
    final dfHandle = api.registerDataFrame({
      'a': [1],
    });
    final chartHandle = api.registerChart({'type': 'bar'});

    expect(dfHandle, 1);
    expect(chartHandle, 2);
  });

  // =========================================================================
  // 4. SessionExtension lifecycle
  // =========================================================================

  group('SessionExtension lifecycle', () {
    test('tools returns empty list', () {
      expect(api.tools, isEmpty);
    });

    test('onAttach stores session', () async {
      final session = _MockAgentSession();
      await api.onAttach(session);

      // Verify session is attached by invoking a known operation —
      // it should call requestApproval (not throw StateError).
      await expectLater(
        api.invoke('native.file_read', {'path': '/tmp/nonexistent'}),
        throwsA(isA<FileSystemException>()),
      );
    });

    test('onDispose clears session', () async {
      final session = _MockAgentSession();
      await api.onAttach(session);

      api.onDispose();

      // After dispose, invoke should throw StateError (no session).
      await expectLater(
        api.invoke('native.clipboard', {}),
        throwsA(isA<StateError>()),
      );
    });
  });

  // =========================================================================
  // 5. invoke dispatch
  // =========================================================================

  group('invoke', () {
    test('unknown operation throws UnimplementedError', () async {
      await expectLater(
        api.invoke('native.unknown', {}),
        throwsA(
          isA<UnimplementedError>().having(
            (e) => e.message,
            'message',
            contains('unsupported operation "native.unknown"'),
          ),
        ),
      );
    });

    test('no session attached throws StateError', () async {
      await expectLater(
        api.invoke('native.clipboard', {}),
        throwsA(isA<StateError>()),
      );
    });
  });

  // =========================================================================
  // 6. Approval gating
  // =========================================================================

  group('approval gating', () {
    test('denied approval throws', () async {
      final session = _MockAgentSession(approveAll: false);
      await api.onAttach(session);

      await expectLater(
        api.invoke('native.clipboard', {'action': 'read'}),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('User denied'),
          ),
        ),
      );
    });
  });

  // =========================================================================
  // 7. Argument validation
  // =========================================================================

  group('argument validation', () {
    late _MockAgentSession session;

    setUp(() async {
      session = _MockAgentSession();
      await api.onAttach(session);
    });

    tearDown(() {
      api.onDispose();
    });

    test('native.shell with missing command throws ArgumentError', () async {
      await expectLater(
        api.invoke('native.shell', {}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('native.shell with empty command throws ArgumentError', () async {
      await expectLater(
        api.invoke('native.shell', {'command': ''}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('native.file_write with missing path throws ArgumentError', () async {
      await expectLater(
        api.invoke('native.file_write', {'content': 'hello'}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test(
      'native.file_write with missing content throws ArgumentError',
      () async {
        await expectLater(
          api.invoke('native.file_write', {'path': '/tmp/test.txt'}),
          throwsA(isA<ArgumentError>()),
        );
      },
    );

    test('native.file_read with missing path throws ArgumentError', () async {
      await expectLater(
        api.invoke('native.file_read', {}),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  // =========================================================================
  // 8. native.file_read with nonexistent file
  // =========================================================================

  test(
    'native.file_read with nonexistent file throws FileSystemException',
    () async {
      final session = _MockAgentSession();
      await api.onAttach(session);

      await expectLater(
        api.invoke('native.file_read', {'path': '/tmp/__no_such_file__'}),
        throwsA(isA<FileSystemException>()),
      );
    },
  );

  // =========================================================================
  // 9. native.shell round-trip (real Process.run)
  // =========================================================================

  test('native.shell executes command and returns output', () async {
    final session = _MockAgentSession();
    await api.onAttach(session);

    final result = await api.invoke('native.shell', {
      'command': 'echo hello_from_test',
    });

    expect(result, isA<String>());
    expect(result! as String, contains('hello_from_test'));
  });

  // =========================================================================
  // 10. native.file_write + native.file_read round-trip
  // =========================================================================

  test('native.file_write + file_read round-trip', () async {
    final session = _MockAgentSession();
    await api.onAttach(session);

    final tmpPath =
        '/tmp/tui_host_api_test_${pid}_${DateTime.now().millisecondsSinceEpoch}.txt';

    addTearDown(() {
      try {
        File(tmpPath).deleteSync();
      } on FileSystemException {
        // ignore
      }
    });

    final writeResult = await api.invoke('native.file_write', {
      'path': tmpPath,
      'content': 'test content',
    });
    expect(writeResult, isA<String>());
    expect(writeResult! as String, contains('12 chars'));

    final readResult = await api.invoke('native.file_read', {'path': tmpPath});
    expect(readResult, 'test content');
  });

  // =========================================================================
  // 11. native.clipboard read (macOS only — skipped on other platforms)
  // =========================================================================

  test(
    'native.clipboard read returns a string',
    () async {
      final session = _MockAgentSession();
      await api.onAttach(session);

      final result = await api.invoke('native.clipboard', {'action': 'read'});
      expect(result, isA<String>());
    },
    skip: !Platform.isMacOS ? 'clipboard tests only run on macOS' : null,
  );
}
