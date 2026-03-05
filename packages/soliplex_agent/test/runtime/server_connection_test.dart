import 'package:mocktail/mocktail.dart';
import 'package:soliplex_agent/soliplex_agent.dart';
import 'package:soliplex_client/soliplex_client.dart'
    show AgUiClient, SoliplexApi, SoliplexHttpClient;
import 'package:test/test.dart';

class MockSoliplexApi extends Mock implements SoliplexApi {}

class MockAgUiClient extends Mock implements AgUiClient {
  @override
  Future<void> close() async {}
}

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

    test('uses identity equality (not serverId)', () {
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

      expect(conn1, isNot(equals(conn2)));
      expect(conn1, equals(conn1));
    });

    test('toString contains serverId', () {
      final conn = ServerConnection(
        serverId: 'prod',
        api: api,
        agUiClient: agUiClient,
      );

      expect(conn.toString(), contains('prod'));
    });

    group('close()', () {
      test('invokes onClose callback', () async {
        var callbackInvoked = false;

        final conn = ServerConnection(
          serverId: 'test',
          api: api,
          agUiClient: agUiClient,
          onClose: () async {
            callbackInvoked = true;
          },
        );

        await conn.close();

        expect(callbackInvoked, isTrue);
      });

      test('works without onClose', () async {
        final conn = ServerConnection(
          serverId: 'test',
          api: api,
          agUiClient: agUiClient,
        );

        // Should not throw.
        await conn.close();
      });
    });

    group('.fromUrl()', () {
      test('wires SoliplexApi and AgUiClient from server URL', () {
        final conn = ServerConnection.fromUrl(
          serverUrl: 'http://localhost:8000',
        );

        expect(conn.serverId, 'default');
        expect(conn.api, isA<SoliplexApi>());
        expect(conn.agUiClient, isA<AgUiClient>());
      });

      test('accepts custom serverId', () {
        final conn = ServerConnection.fromUrl(
          serverUrl: 'http://localhost:8000',
          serverId: 'custom',
        );

        expect(conn.serverId, 'custom');
      });

      test('asserts on URL with /api/v1 suffix', () {
        expect(
          () => ServerConnection.fromUrl(
            serverUrl: 'http://localhost:8000/api/v1',
          ),
          throwsA(isA<AssertionError>()),
        );
      });
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

      test('passes onClose through', () async {
        final httpClient = MockSoliplexHttpClient();
        var callbackInvoked = false;
        final conn = ServerConnection.create(
          serverId: 'test',
          serverUrl: 'http://localhost:8000',
          httpClient: httpClient,
          onClose: () async {
            callbackInvoked = true;
          },
        );

        await conn.close();

        expect(callbackInvoked, isTrue);
      });
    });
  });
}
