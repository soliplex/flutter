import 'package:ag_ui/ag_ui.dart';
import 'package:dart_monty_platform_interface/dart_monty_platform_interface.dart';
import 'package:test/test.dart';

import 'room_fixture.dart';

void main() {
  group('Layer 0 — Pure Python Execution', () {
    group('Room: calculator', () {
      test('executes arithmetic and returns RunStarted → RunFinished',
          () async {
        const room = RoomFixture(
          name: 'calculator',
          layer: 0,
          functions: [],
          progressQueue: [
            MontyComplete(
              result: MontyResult(value: 5050, usage: stubUsage),
            ),
          ],
          pythonCode: 'result = sum(range(1, 101))',
          expectedEventTypes: [RunStartedEvent, RunFinishedEvent],
        );

        final events = await runRoom(room);

        assertEventSequence(events, room.expectedEventTypes);
      });

      test('produces no text message events (no print)', () async {
        const room = RoomFixture(
          name: 'calculator',
          layer: 0,
          functions: [],
          progressQueue: [
            MontyComplete(
              result: MontyResult(value: 5050, usage: stubUsage),
            ),
          ],
          pythonCode: 'result = sum(range(1, 101))',
          expectedEventTypes: [RunStartedEvent, RunFinishedEvent],
        );

        final events = await runRoom(room);

        expect(events.whereType<TextMessageStartEvent>(), isEmpty);
        expect(events.whereType<TextMessageContentEvent>(), isEmpty);
      });
    });

    group('Room: formatter', () {
      test('captures print output as TextMessage events', () async {
        const room = RoomFixture(
          name: 'formatter',
          layer: 0,
          functions: [],
          progressQueue: [
            MontyPending(
              functionName: '__console_write__',
              arguments: ['Total: \$45.36\n'],
            ),
            MontyComplete(
              result: MontyResult(usage: stubUsage),
            ),
          ],
          pythonCode: r'print(f"Total: ${42 * 1.08:.2f}")',
          expectedEventTypes: [
            RunStartedEvent,
            TextMessageStartEvent,
            TextMessageContentEvent,
            TextMessageEndEvent,
            RunFinishedEvent,
          ],
        );

        final events = await runRoom(room);

        assertEventSequence(events, room.expectedEventTypes);

        final content = events.whereType<TextMessageContentEvent>().single;
        expect(content.delta, contains(r'Total: $45.36'));
      });
    });

    group('Room: error_room', () {
      test('propagates Python exception as RunErrorEvent', () async {
        const room = RoomFixture(
          name: 'error_room',
          layer: 0,
          functions: [],
          progressQueue: [
            MontyComplete(
              result: MontyResult(
                error: MontyException(message: 'ValueError: invalid input'),
                usage: stubUsage,
              ),
            ),
          ],
          pythonCode: 'raise ValueError("invalid input")',
          expectedEventTypes: [RunStartedEvent, RunErrorEvent],
        );

        final events = await runRoom(room);

        assertEventSequence(events, room.expectedEventTypes);

        final error = events.whereType<RunErrorEvent>().single;
        expect(error.message, 'ValueError: invalid input');
      });
    });
  });
}
