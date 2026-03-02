import 'package:mocktail/mocktail.dart';
import 'package:soliplex_agent/soliplex_agent.dart';
import 'package:test/test.dart';

import '../helpers/test_helpers.dart';

void main() {
  group('listRooms', () {
    late MockSoliplexApi mockApi;

    setUp(() {
      mockApi = MockSoliplexApi();
    });

    test('prints room id and name for each room', () async {
      when(() => mockApi.getRooms()).thenAnswer(
        (_) async => [
          const Room(id: 'echo', name: 'Echo Test'),
          const Room(id: 'plain', name: 'Plain Chat'),
        ],
      );

      final rooms = await mockApi.getRooms();
      final output = StringBuffer();
      for (final room in rooms) {
        output.writeln('${room.id}\t${room.name}');
      }

      expect(output.toString(), contains('echo\tEcho Test'));
      expect(output.toString(), contains('plain\tPlain Chat'));
    });
  });
}
