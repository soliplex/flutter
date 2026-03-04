import 'package:mocktail/mocktail.dart';
import 'package:soliplex_agent/soliplex_agent.dart';
import 'package:soliplex_client/soliplex_client.dart'
    show AgUiClient, SoliplexApi, SoliplexHttpClient;
import 'package:test/test.dart';

class MockSoliplexApi extends Mock implements SoliplexApi {}

class MockAgUiClient extends Mock implements AgUiClient {}

class MockSoliplexHttpClient extends Mock implements SoliplexHttpClient {}

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

    group('.create()', () {
      test('wires SoliplexApi and AgUiClient from server URL', () {
        final httpClient = MockSoliplexHttpClient();
        final conn = ServerConnection.create(
          serverId: 'test-server',
          serverUrl: 'http://localhost:8000',
          httpClient: httpClient,
        );

        expect(conn.serverId, 'test-server');
        expect(conn.api, isA<SoliplexApi>());
        expect(conn.agUiClient, isA<AgUiClient>());
      });

      test('asserts on URL with /api/v1 suffix', () {
        final httpClient = MockSoliplexHttpClient();
        expect(
          () => ServerConnection.create(
            serverId: 'bad',
            serverUrl: 'http://localhost:8000/api/v1',
            httpClient: httpClient,
          ),
          throwsA(isA<AssertionError>()),
        );
      });

      test('equality still based on serverId', () {
        final http1 = MockSoliplexHttpClient();
        final http2 = MockSoliplexHttpClient();
        final conn1 = ServerConnection.create(
          serverId: 'same',
          serverUrl: 'http://a.com',
          httpClient: http1,
        );
        final conn2 = ServerConnection.create(
          serverId: 'same',
          serverUrl: 'http://b.com',
          httpClient: http2,
        );

        expect(conn1, equals(conn2));
      });
    });
  });
}
