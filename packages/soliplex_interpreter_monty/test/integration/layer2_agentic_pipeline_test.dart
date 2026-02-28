import 'dart:convert';

import 'package:ag_ui/ag_ui.dart';
import 'package:dart_monty_platform_interface/dart_monty_platform_interface.dart';
import 'package:dart_monty_platform_interface/dart_monty_testing.dart';
import 'package:soliplex_interpreter_monty/soliplex_interpreter_monty.dart';
import 'package:test/test.dart';

import 'room_fixture.dart';

void main() {
  group('Layer 2 — Agentic Orchestration (Simulated)', () {
    group('Room: research_assistant', () {
      late MockMontyPlatform mock;
      late DefaultMontyBridge bridge;

      setUp(() {
        mock = MockMontyPlatform();
        bridge = DefaultMontyBridge(platform: mock);

        (HostFunctionRegistry()
              ..addCategory('research', [
                HostFunction(
                  schema: const HostFunctionSchema(
                    name: 'search',
                    description: 'Search for information.',
                    params: [
                      HostParam(name: 'query', type: HostParamType.string),
                    ],
                  ),
                  handler: (args) async =>
                      'Quantum computing made major breakthroughs in 2026 '
                      'with error correction achieving 99.9% fidelity.',
                ),
                HostFunction(
                  schema: const HostFunctionSchema(
                    name: 'summarize',
                    description: 'Summarize text to max_words.',
                    params: [
                      HostParam(name: 'text', type: HostParamType.string),
                      HostParam(name: 'max_words', type: HostParamType.integer),
                    ],
                  ),
                  handler: (args) async => 'Quantum computing: 99.9% fidelity.',
                ),
              ]))
            .registerAllOnto(bridge);
      });

      tearDown(() => bridge.dispose());

      test('multi-step search + summarize pipeline', () async {
        mock
          ..enqueueProgress(
            const MontyPending(
              functionName: 'search',
              arguments: ['quantum computing breakthroughs 2026'],
              callId: 1,
            ),
          )
          ..enqueueProgress(
            const MontyPending(
              functionName: 'summarize',
              arguments: [
                'Quantum computing achieved 99.9% fidelity.',
                50,
              ],
              callId: 2,
            ),
          )
          ..enqueueProgress(
            const MontyPending(
              functionName: '__console_write__',
              arguments: [
                'Quantum computing achieved 99.9% error correction in 2026.\n',
              ],
            ),
          )
          ..enqueueProgress(
            const MontyComplete(result: MontyResult(usage: stubUsage)),
          );

        final events = await bridge
            .execute(
              'raw = search("quantum computing breakthroughs 2026")\n'
              'summary = summarize(raw, 50)\n'
              'print(summary)',
            )
            .toList();

        // Two tool call results
        final results = events.whereType<ToolCallResultEvent>().toList();
        expect(results, hasLength(2));

        // search result
        final searchResult = findToolCallResult(events, 'search');
        expect(searchResult, isNotNull);
        expect(searchResult!.content, contains('Quantum computing'));

        // summarize result
        final summarizeResult = findToolCallResult(events, 'summarize');
        expect(summarizeResult, isNotNull);
        expect(summarizeResult!.content, contains('99.9%'));

        // Verify summarize args include integer max_words
        final argsEvents = events.whereType<ToolCallArgsEvent>().toList();
        final summarizeArgs =
            jsonDecode(argsEvents[1].delta) as Map<String, Object?>;
        expect(summarizeArgs['max_words'], 50);

        // Print output at end
        final textContent =
            events.whereType<TextMessageContentEvent>().toList();
        expect(textContent, hasLength(1));
        expect(textContent.first.delta, contains('99.9%'));

        expect(events.first, isA<RunStartedEvent>());
        expect(events.last, isA<RunFinishedEvent>());
      });
    });

    group('Room: data_analysis', () {
      late MockMontyPlatform mock;
      late DefaultMontyBridge bridge;

      setUp(() {
        mock = MockMontyPlatform();
        bridge = DefaultMontyBridge(platform: mock);

        (HostFunctionRegistry()
              ..addCategory('data', [
                HostFunction(
                  schema: const HostFunctionSchema(
                    name: 'fetch_sales',
                    description: 'Fetch sales data for a region.',
                    params: [
                      HostParam(name: 'region', type: HostParamType.string),
                    ],
                  ),
                  handler: (args) async => [
                    {'month': 'Jan', 'amount': 1200},
                    {'month': 'Jan', 'amount': 800},
                    {'month': 'Feb', 'amount': 1500},
                  ],
                ),
                HostFunction(
                  schema: const HostFunctionSchema(
                    name: 'chart_bar',
                    description: 'Render a bar chart.',
                    params: [
                      HostParam(name: 'title', type: HostParamType.string),
                      HostParam(name: 'data', type: HostParamType.list),
                    ],
                  ),
                  handler: (args) async => {
                    'chart_id': 'chart_001',
                    'type': 'bar',
                    'title': args['title'],
                  },
                ),
              ]))
            .registerAllOnto(bridge);
      });

      tearDown(() => bridge.dispose());

      test('fetch data, process in Python, render chart', () async {
        mock
          ..enqueueProgress(
            const MontyPending(
              functionName: 'fetch_sales',
              arguments: ['northeast'],
              callId: 1,
            ),
          )
          ..enqueueProgress(
            const MontyPending(
              functionName: 'chart_bar',
              arguments: [
                'NE Sales by Month',
                [
                  ['Jan', 2000],
                  ['Feb', 1500],
                ],
              ],
              callId: 2,
            ),
          )
          ..enqueueProgress(
            const MontyComplete(result: MontyResult(usage: stubUsage)),
          );

        final events = await bridge
            .execute(
              'sales = fetch_sales("northeast")\n'
              'totals = {}\n'
              'for entry in sales:\n'
              '    totals[entry["month"]] = '
              'totals.get(entry["month"], 0) + entry["amount"]\n'
              'chart_bar("NE Sales by Month", list(totals.items()))',
            )
            .toList();

        // Two tool call results
        final results = events.whereType<ToolCallResultEvent>().toList();
        expect(results, hasLength(2));

        // fetch_sales returns a list (serialized as string)
        final fetchResult = findToolCallResult(events, 'fetch_sales');
        expect(fetchResult, isNotNull);

        // chart_bar returns a map (serialized as string)
        final chartResult = findToolCallResult(events, 'chart_bar');
        expect(chartResult, isNotNull);
        expect(chartResult!.content, contains('chart_001'));

        // Verify chart_bar received list arg
        final argsEvents = events.whereType<ToolCallArgsEvent>().toList();
        final chartArgs =
            jsonDecode(argsEvents[1].delta) as Map<String, Object?>;
        expect(chartArgs['title'], 'NE Sales by Month');
        expect(chartArgs['data'], isList);

        expect(events.first, isA<RunStartedEvent>());
        expect(events.last, isA<RunFinishedEvent>());
      });
    });

    group('Room: multi_step_with_print', () {
      late MockMontyPlatform mock;
      late DefaultMontyBridge bridge;

      setUp(() {
        mock = MockMontyPlatform();
        bridge = DefaultMontyBridge(platform: mock);

        (HostFunctionRegistry()
              ..addCategory('storage', [
                HostFunction(
                  schema: const HostFunctionSchema(
                    name: 'get_data',
                    description: 'Fetch data by key.',
                    params: [
                      HostParam(name: 'key', type: HostParamType.string),
                    ],
                  ),
                  handler: (args) async => {'theme': 'dark', 'lang': 'en'},
                ),
                HostFunction(
                  schema: const HostFunctionSchema(
                    name: 'store_result',
                    description: 'Store a key-value result.',
                    params: [
                      HostParam(name: 'key', type: HostParamType.string),
                      HostParam(name: 'value', type: HostParamType.string),
                    ],
                  ),
                  handler: (args) async => true,
                ),
              ]))
            .registerAllOnto(bridge);
      });

      tearDown(() => bridge.dispose());

      test('tool calls interleaved with print buffer', () async {
        mock
          // print("Fetching data...")
          ..enqueueProgress(
            const MontyPending(
              functionName: '__console_write__',
              arguments: ['Fetching data...\n'],
            ),
          )
          // get_data("user_prefs")
          ..enqueueProgress(
            const MontyPending(
              functionName: 'get_data',
              arguments: ['user_prefs'],
              callId: 1,
            ),
          )
          // print(f"Got {len(data)} fields")
          ..enqueueProgress(
            const MontyPending(
              functionName: '__console_write__',
              arguments: ['Got 2 fields\n'],
            ),
          )
          // store_result("summary", "theme=dark, lang=en")
          ..enqueueProgress(
            const MontyPending(
              functionName: 'store_result',
              arguments: ['summary', 'theme=dark, lang=en'],
              callId: 2,
            ),
          )
          // print(f"Stored: {stored}")
          ..enqueueProgress(
            const MontyPending(
              functionName: '__console_write__',
              arguments: ['Stored: true\n'],
            ),
          )
          ..enqueueProgress(
            const MontyComplete(result: MontyResult(usage: stubUsage)),
          );

        final events = await bridge
            .execute(
              'print("Fetching data...")\n'
              'data = get_data("user_prefs")\n'
              'print(f"Got {len(data)} fields")\n'
              'result = ", ".join(f"{k}={v}" for k, v in data.items())\n'
              'stored = store_result("summary", result)\n'
              'print(f"Stored: {stored}")',
            )
            .toList();

        // Two tool call results
        final results = events.whereType<ToolCallResultEvent>().toList();
        expect(results, hasLength(2));

        // get_data returns a map
        final getData = findToolCallResult(events, 'get_data');
        expect(getData, isNotNull);

        // store_result returns boolean (as string "true")
        final storeResult = findToolCallResult(events, 'store_result');
        expect(storeResult, isNotNull);
        expect(storeResult!.content, 'true');

        // Prints are buffered and flushed at end as a single TextMessage
        final textContent =
            events.whereType<TextMessageContentEvent>().toList();
        expect(textContent, hasLength(1));

        // All three print calls are concatenated in the buffer
        final printOutput = textContent.first.delta;
        expect(printOutput, contains('Fetching data...'));
        expect(printOutput, contains('Got 2 fields'));
        expect(printOutput, contains('Stored: true'));

        // Only one TextMessageStart/End pair (single flush)
        expect(events.whereType<TextMessageStartEvent>(), hasLength(1));
        expect(events.whereType<TextMessageEndEvent>(), hasLength(1));

        expect(events.first, isA<RunStartedEvent>());
        expect(events.last, isA<RunFinishedEvent>());
      });
    });
  });
}
