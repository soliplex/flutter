import 'package:mocktail/mocktail.dart';
import 'package:soliplex_agent/soliplex_agent.dart';
import 'package:test/test.dart';

class MockSoliplexApi extends Mock implements SoliplexApi {}

class MockAgUiClient extends Mock implements AgUiClient {}

void main() {
  group('ServerConnection', () {
    late MockSoliplexApi api;
    late MockAgUiClient agUiClient;

    setUp(() {
      api = MockSoliplexApi();
      agUiClient = MockAgUiClient();
    });

    test('construction exposes all fields', () {
      final conn = ServerConnection(
        serverId: 'prod',
        api: api,
        agUiClient: agUiClient,
      );

      expect(conn.serverId, 'prod');
      expect(conn.api, same(api));
      expect(conn.agUiClient, same(agUiClient));
    });

    test('equality by serverId only', () {
      final conn1 = ServerConnection(
        serverId: 'prod',
        api: api,
        agUiClient: agUiClient,
      );
      final conn2 = ServerConnection(
        serverId: 'prod',
        api: MockSoliplexApi(),
        agUiClient: MockAgUiClient(),
      );

      expect(conn1, equals(conn2));
    });

    test('inequality on different serverId', () {
      final conn1 = ServerConnection(
        serverId: 'prod',
        api: api,
        agUiClient: agUiClient,
      );
      final conn2 = ServerConnection(
        serverId: 'staging',
        api: api,
        agUiClient: agUiClient,
      );

      expect(conn1, isNot(equals(conn2)));
    });

    test('hashCode consistent with equality', () {
      final conn1 = ServerConnection(
        serverId: 'prod',
        api: api,
        agUiClient: agUiClient,
      );
      final conn2 = ServerConnection(
        serverId: 'prod',
        api: MockSoliplexApi(),
        agUiClient: MockAgUiClient(),
      );

      expect(conn1.hashCode, equals(conn2.hashCode));
    });

    test('toString contains serverId', () {
      final conn = ServerConnection(
        serverId: 'prod',
        api: api,
        agUiClient: agUiClient,
      );

      expect(conn.toString(), contains('prod'));
    });
  });
}
