import 'dart:convert';

import 'package:dart_monty_platform_interface/dart_monty_platform_interface.dart';
import 'package:dart_monty_platform_interface/dart_monty_testing.dart';
import 'package:soliplex_interpreter_monty/soliplex_interpreter_monty.dart';
import 'package:test/test.dart';

import 'room_fixture.dart';

void main() {
  group('Layer 1 — Client-Side Tool Calls', () {
    group('Room: clock', () {
      late MockMontyPlatform mock;
      late DefaultMontyBridge bridge;

      setUp(() {
        mock = MockMontyPlatform();
        bridge = DefaultMontyBridge(platform: mock);
      });

      tearDown(() => bridge.dispose());

      test('single host function dispatch and result flow', () async {
        bridge.register(
          HostFunction(
            schema: const HostFunctionSchema(
              name: 'get_current_time',
              description: 'Returns current time as a string.',
            ),
            handler: (args) async => '2026-02-28T10:30:00Z',
          ),
        );

        mock
          ..enqueueProgress(
            const MontyPending(
              functionName: 'get_current_time',
              arguments: [],
              callId: 1,
            ),
          )
          ..enqueueProgress(
            const MontyPending(
              functionName: '__console_write__',
              arguments: ['The time is 2026-02-28T10:30:00Z\n'],
            ),
          )
          ..enqueueProgress(
            const MontyComplete(result: MontyResult(usage: stubUsage)),
          );

        final events = await bridge
            .execute(
              't = get_current_time()\nprint(f"The time is {t}")',
            )
            .toList();

        // Tool call sequence
        final toolResult = findToolCallResult(events, 'get_current_time');
        expect(toolResult, isNotNull);
        expect(toolResult!.result, '2026-02-28T10:30:00Z');

        // Print output flushed at end
        final textContent = events.whereType<BridgeTextContent>().toList();
        expect(textContent, hasLength(1));
        expect(textContent.first.delta, contains('The time is'));

        // Verify resume was called with the handler return value
        // (not lastResumeReturnValue — console_write resumes with null after)
        expect(mock.resumeReturnValues, contains('2026-02-28T10:30:00Z'));

        // Terminal events
        expect(events.first, isA<BridgeRunStarted>());
        expect(events.last, isA<BridgeRunFinished>());
      });
    });

    group('Room: weather', () {
      late MockMontyPlatform mock;
      late DefaultMontyBridge bridge;

      setUp(() {
        mock = MockMontyPlatform();
        bridge = DefaultMontyBridge(platform: mock);
      });

      tearDown(() => bridge.dispose());

      test('multiple sequential tool calls with typed params', () async {
        bridge
          ..register(
            HostFunction(
              schema: const HostFunctionSchema(
                name: 'get_temperature',
                description: 'Get temperature for a city.',
                params: [
                  HostParam(name: 'city', type: HostParamType.string),
                ],
              ),
              handler: (args) async => 72,
            ),
          )
          ..register(
            HostFunction(
              schema: const HostFunctionSchema(
                name: 'get_forecast',
                description: 'Get forecast for a city.',
                params: [
                  HostParam(name: 'city', type: HostParamType.string),
                  HostParam(name: 'days', type: HostParamType.integer),
                ],
              ),
              handler: (args) async => 'Sunny for 3 days',
            ),
          );

        mock
          ..enqueueProgress(
            const MontyPending(
              functionName: 'get_temperature',
              arguments: ['NYC'],
              callId: 1,
            ),
          )
          ..enqueueProgress(
            const MontyPending(
              functionName: 'get_forecast',
              arguments: ['NYC', 3],
              callId: 2,
            ),
          )
          ..enqueueProgress(
            const MontyPending(
              functionName: '__console_write__',
              arguments: ['NYC: 72°F — Sunny for 3 days\n'],
            ),
          )
          ..enqueueProgress(
            const MontyComplete(result: MontyResult(usage: stubUsage)),
          );

        final events = await bridge
            .execute(
              'temp = get_temperature("NYC")\n'
              'forecast = get_forecast("NYC", 3)\n'
              'print(f"NYC: {temp}°F — {forecast}")',
            )
            .toList();

        // Two tool call result events
        final results = events.whereType<BridgeToolCallResult>().toList();
        expect(results, hasLength(2));
        expect(results.first.result, '72');
        expect(results[1].result, 'Sunny for 3 days');

        // Verify args for get_forecast (string + integer)
        final argsEvents = events.whereType<BridgeToolCallArgs>().toList();
        expect(argsEvents, hasLength(2));
        final forecastArgs =
            jsonDecode(argsEvents[1].delta) as Map<String, Object?>;
        expect(forecastArgs['city'], 'NYC');
        expect(forecastArgs['days'], 3);

        expect(events.last, isA<BridgeRunFinished>());
      });
    });

    group('Room: converter', () {
      late MockMontyPlatform mock;
      late DefaultMontyBridge bridge;

      setUp(() {
        mock = MockMontyPlatform();
        bridge = DefaultMontyBridge(platform: mock);
      });

      tearDown(() => bridge.dispose());

      test('number return type used in Python arithmetic', () async {
        bridge.register(
          HostFunction(
            schema: const HostFunctionSchema(
              name: 'get_exchange_rate',
              description: 'Get exchange rate between currencies.',
              params: [
                HostParam(
                  name: 'from_currency',
                  type: HostParamType.string,
                ),
                HostParam(name: 'to_currency', type: HostParamType.string),
              ],
            ),
            handler: (args) async => 0.92,
          ),
        );

        mock
          ..enqueueProgress(
            const MontyPending(
              functionName: 'get_exchange_rate',
              arguments: ['USD', 'EUR'],
              callId: 1,
            ),
          )
          ..enqueueProgress(
            const MontyPending(
              functionName: '__console_write__',
              arguments: ['\$1000 = €920.00\n'],
            ),
          )
          ..enqueueProgress(
            const MontyComplete(result: MontyResult(usage: stubUsage)),
          );

        final events = await bridge
            .execute(
              'rate = get_exchange_rate("USD", "EUR")\n'
              'converted = 1000 * rate\n'
              r'print(f"$1000 = €{converted:.2f}")',
            )
            .toList();

        final toolResult = findToolCallResult(events, 'get_exchange_rate');
        expect(toolResult, isNotNull);
        expect(toolResult!.result, '0.92');

        // Verify resume was called with the number value
        expect(mock.resumeReturnValues, contains(0.92));

        expect(events.last, isA<BridgeRunFinished>());
      });
    });

    group('Room: multi_tool', () {
      late MockMontyPlatform mock;
      late DefaultMontyBridge bridge;

      setUp(() {
        mock = MockMontyPlatform();
        bridge = DefaultMontyBridge(platform: mock);
      });

      tearDown(() => bridge.dispose());

      test('chained tool calls — second depends on first result', () async {
        bridge
          ..register(
            HostFunction(
              schema: const HostFunctionSchema(
                name: 'add',
                description: 'Add two integers.',
                params: [
                  HostParam(name: 'a', type: HostParamType.integer),
                  HostParam(name: 'b', type: HostParamType.integer),
                ],
              ),
              handler: (args) async =>
                  (args['a']! as int) + (args['b']! as int),
            ),
          )
          ..register(
            HostFunction(
              schema: const HostFunctionSchema(
                name: 'multiply',
                description: 'Multiply two integers.',
                params: [
                  HostParam(name: 'a', type: HostParamType.integer),
                  HostParam(name: 'b', type: HostParamType.integer),
                ],
              ),
              handler: (args) async =>
                  (args['a']! as int) * (args['b']! as int),
            ),
          );

        mock
          ..enqueueProgress(
            const MontyPending(
              functionName: 'add',
              arguments: [3, 4],
              callId: 1,
            ),
          )
          ..enqueueProgress(
            const MontyPending(
              functionName: 'multiply',
              arguments: [7, 10],
              callId: 2,
            ),
          )
          ..enqueueProgress(
            const MontyComplete(
              result: MontyResult(value: 70, usage: stubUsage),
            ),
          );

        final events = await bridge
            .execute('s = add(3, 4)\nresult = multiply(s, 10)')
            .toList();

        final results = events.whereType<BridgeToolCallResult>().toList();
        expect(results, hasLength(2));
        expect(results.first.result, '7'); // add(3, 4)
        expect(results[1].result, '70'); // multiply(7, 10)

        expect(events.first, isA<BridgeRunStarted>());
        expect(events.last, isA<BridgeRunFinished>());
      });
    });

    group('Room: error_handling', () {
      late MockMontyPlatform mock;
      late DefaultMontyBridge bridge;

      setUp(() {
        mock = MockMontyPlatform();
        bridge = DefaultMontyBridge(platform: mock);
      });

      tearDown(() => bridge.dispose());

      test('handler exception → resumeWithError', () async {
        bridge.register(
          HostFunction(
            schema: const HostFunctionSchema(
              name: 'risky_call',
              description: 'A function whose handler throws.',
            ),
            handler: (args) async => throw Exception('service unavailable'),
          ),
        );

        mock
          ..enqueueProgress(
            const MontyPending(
              functionName: 'risky_call',
              arguments: [],
              callId: 1,
            ),
          )
          ..enqueueProgress(
            const MontyComplete(result: MontyResult(usage: stubUsage)),
          );

        final events = await bridge.execute('result = risky_call()').toList();

        // ToolCallResult should contain the error
        final result = events.whereType<BridgeToolCallResult>().single;
        expect(result.result, contains('service unavailable'));

        // Bridge should have called resumeWithError
        expect(mock.resumeErrorMessages, hasLength(1));
        expect(
          mock.resumeErrorMessages.first,
          contains('service unavailable'),
        );

        // Execution still completes (Python sees the error)
        expect(events.last, isA<BridgeRunFinished>());
      });
    });

    group('Room: invalid_args', () {
      late MockMontyPlatform mock;
      late DefaultMontyBridge bridge;

      setUp(() {
        mock = MockMontyPlatform();
        bridge = DefaultMontyBridge(platform: mock);
      });

      tearDown(() => bridge.dispose());

      test('missing required arg → resumeWithError, no crash', () async {
        bridge.register(
          HostFunction(
            schema: const HostFunctionSchema(
              name: 'search',
              description: 'Search for information.',
              params: [
                HostParam(name: 'query', type: HostParamType.string),
              ],
            ),
            handler: (args) async => 'result',
          ),
        );

        // Python calls search() with no arguments
        mock
          ..enqueueProgress(
            const MontyPending(
              functionName: 'search',
              arguments: [],
              callId: 1,
            ),
          )
          ..enqueueProgress(
            const MontyComplete(result: MontyResult(usage: stubUsage)),
          );

        final events = await bridge.execute('result = search()').toList();

        // ToolCallResult should contain the validation error
        final result = events.whereType<BridgeToolCallResult>().single;
        expect(result.result, contains('Error:'));
        expect(result.result, contains('query'));

        // Bridge called resumeWithError (not crash)
        expect(mock.resumeErrorMessages, hasLength(1));

        // Execution completes normally
        expect(events.last, isA<BridgeRunFinished>());
      });
    });

    group('Room: unknown_function', () {
      late MockMontyPlatform mock;
      late DefaultMontyBridge bridge;

      setUp(() {
        mock = MockMontyPlatform();
        bridge = DefaultMontyBridge(platform: mock);
      });

      tearDown(() => bridge.dispose());

      test('unregistered function → resumeWithError, no crash', () async {
        bridge.register(
          HostFunction(
            schema: const HostFunctionSchema(
              name: 'known_fn',
              description: 'A registered function.',
            ),
            handler: (args) async => 'ok',
          ),
        );

        // Python calls unknown_fn which is NOT registered
        mock
          ..enqueueProgress(
            const MontyPending(
              functionName: 'unknown_fn',
              arguments: [],
              callId: 1,
            ),
          )
          ..enqueueProgress(
            const MontyComplete(
              result: MontyResult(
                error: MontyException(
                  message: 'NameError: unknown_fn is not defined',
                ),
                usage: stubUsage,
              ),
            ),
          );

        final events = await bridge.execute('unknown_fn()').toList();

        // Bridge called resumeWithError for the unknown function
        expect(mock.resumeErrorMessages, hasLength(1));
        expect(
          mock.resumeErrorMessages.first,
          contains('Unknown function'),
        );

        // No tool call events emitted for unknown function
        expect(events.whereType<BridgeToolCallStart>(), isEmpty);

        // Ends with BridgeRunError (Python raised the error)
        expect(events.last, isA<BridgeRunError>());
      });
    });
  });
}
