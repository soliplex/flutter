import 'dart:convert';

import 'package:ag_ui/ag_ui.dart';
import 'package:dart_monty_platform_interface/dart_monty_platform_interface.dart';
import 'package:dart_monty_platform_interface/dart_monty_testing.dart';
import 'package:soliplex_interpreter_monty/soliplex_interpreter_monty.dart';
import 'package:test/test.dart';

import 'room_fixture.dart';

void main() {
  group('Layer 1 — Introspection', () {
    group('Room: introspection', () {
      late MockMontyPlatform mock;
      late DefaultMontyBridge bridge;
      setUp(() {
        mock = MockMontyPlatform();
        bridge = DefaultMontyBridge(platform: mock);
        (HostFunctionRegistry()
              ..addCategory('finance', [
                HostFunction(
                  schema: const HostFunctionSchema(
                    name: 'get_price',
                    description: 'Get stock price by symbol.',
                    params: [
                      HostParam(name: 'symbol', type: HostParamType.string),
                    ],
                  ),
                  handler: (args) async => 42.5,
                ),
              ]))
            .registerAllOnto(bridge);
      });

      tearDown(() => bridge.dispose());

      test('list_functions returns all registered functions', () async {
        // list_functions() is called by Python
        mock
          ..enqueueProgress(
            const MontyPending(
              functionName: 'list_functions',
              arguments: [],
              callId: 1,
            ),
          )
          ..enqueueProgress(
            const MontyComplete(result: MontyResult(usage: stubUsage)),
          );

        final events =
            await bridge.execute('funcs = list_functions()').toList();

        final result = findToolCallResult(events, 'list_functions');
        expect(result, isNotNull);

        // Parse the JSON response
        final json = jsonDecode(result!.content) as Map<String, Object?>;
        final tools = json['tools']! as Map<String, Object?>;

        // Should have finance + introspection categories
        expect(tools.keys, containsAll(['finance', 'introspection']));

        // Finance category should contain get_price
        final financeFns = tools['finance']! as List<Object?>;
        final names =
            financeFns.map((f) => (f! as Map)['name'] as String).toList();
        expect(names, contains('get_price'));

        // Introspection category should contain list_functions and help
        final introFns = tools['introspection']! as List<Object?>;
        final introNames =
            introFns.map((f) => (f! as Map)['name'] as String).toList();
        expect(introNames, containsAll(['list_functions', 'help']));

        expect(events.last, isA<RunFinishedEvent>());
      });

      test('help returns schema detail for a registered function', () async {
        mock
          ..enqueueProgress(
            const MontyPending(
              functionName: 'help',
              arguments: ['get_price'],
              callId: 1,
            ),
          )
          ..enqueueProgress(
            const MontyComplete(result: MontyResult(usage: stubUsage)),
          );

        final events =
            await bridge.execute('info = help("get_price")').toList();

        final result = findToolCallResult(events, 'help');
        expect(result, isNotNull);

        final json = jsonDecode(result!.content) as Map<String, Object?>;
        expect(json['name'], 'get_price');
        expect(json['description'], 'Get stock price by symbol.');

        final params = json['params']! as List<Object?>;
        expect(params, hasLength(1));
        final param = params.first! as Map<String, Object?>;
        expect(param['name'], 'symbol');
        expect(param['type'], 'string');
      });

      test('list_functions then help — full introspection pipeline', () async {
        mock
          ..enqueueProgress(
            const MontyPending(
              functionName: 'list_functions',
              arguments: [],
              callId: 1,
            ),
          )
          ..enqueueProgress(
            const MontyPending(
              functionName: 'help',
              arguments: ['get_price'],
              callId: 2,
            ),
          )
          ..enqueueProgress(
            const MontyComplete(result: MontyResult(usage: stubUsage)),
          );

        final events = await bridge
            .execute(
              'funcs = list_functions()\ninfo = help("get_price")',
            )
            .toList();

        // Two tool call sequences
        final results = events.whereType<ToolCallResultEvent>().toList();
        expect(results, hasLength(2));

        expect(events.first, isA<RunStartedEvent>());
        expect(events.last, isA<RunFinishedEvent>());
      });
    });
  });
}
