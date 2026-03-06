import 'package:mocktail/mocktail.dart';
import 'package:soliplex_agent/soliplex_agent.dart';
import 'package:soliplex_client/soliplex_client.dart'
    show AgUiStreamClient, SoliplexApi, SoliplexHttpClient;
import 'package:test/test.dart';

class MockSoliplexApi extends Mock implements SoliplexApi {}

class MockAgUiStreamClient extends Mock implements AgUiStreamClient {}

class MockSoliplexHttpClient extends Mock implements SoliplexHttpClient {}

void main() {
  group('ServerConnection', () {
    late MockSoliplexApi api;
    late MockAgUiStreamClient agUiStreamClient;

    setUp(() {
      api = MockSoliplexApi();
      agUiStreamClient = MockAgUiStreamClient();
    });

    test('construction exposes all fields', () {
      final conn = ServerConnection(
        serverId: 'prod',
        api: api,
        agUiStreamClient: agUiStreamClient,
      );

      expect(conn.serverId, 'prod');
      expect(conn.api, same(api));
      expect(conn.agUiStreamClient, same(agUiStreamClient));
    });

    test('uses identity equality (not serverId)', () {
      final conn1 = ServerConnection(
        serverId: 'prod',
        api: api,
        agUiStreamClient: agUiStreamClient,
      );
      final conn2 = ServerConnection(
        serverId: 'prod',
        api: MockSoliplexApi(),
        agUiStreamClient: MockAgUiStreamClient(),
      );

      expect(conn1, isNot(equals(conn2)));
      expect(conn1, equals(conn1));
    });

    test('toString contains serverId', () {
      final conn = ServerConnection(
        serverId: 'prod',
        api: api,
        agUiStreamClient: agUiStreamClient,
      );

      expect(conn.toString(), contains('prod'));
    });

    group('close()', () {
      test('invokes onClose callback', () async {
        var callbackInvoked = false;

        final conn = ServerConnection(
          serverId: 'test',
          api: api,
          agUiStreamClient: agUiStreamClient,
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
          agUiStreamClient: agUiStreamClient,
        );

        // Should not throw.
        await conn.close();
      });
    });

    group('.create()', () {
      test('wires SoliplexApi and AgUiStreamClient from server URL', () {
        final httpClient = MockSoliplexHttpClient();
        final conn = ServerConnection.create(
          serverId: 'test-server',
          serverUrl: 'http://localhost:8000',
          httpClient: httpClient,
        );

        expect(conn.serverId, 'test-server');
        expect(conn.api, isA<SoliplexApi>());
        expect(conn.agUiStreamClient, isA<AgUiStreamClient>());
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
