import 'package:soliplex_cli/src/client_factory.dart';
import 'package:soliplex_client/soliplex_client.dart'
    show AgUiStreamClient, DartHttpClient, SoliplexApi;
import 'package:test/test.dart';

void main() {
  group('ServerConnection.create', () {
    test('returns non-null api and agUiStreamClient', () async {
      final conn = ServerConnection.create(
        serverId: 'default',
        serverUrl: 'http://localhost:8000',
        httpClient: DartHttpClient(),
      );

      expect(conn.api, isA<SoliplexApi>());
      expect(conn.agUiStreamClient, isA<AgUiStreamClient>());

      await conn.close();
    });

    test('close can be called multiple times', () async {
      final conn = ServerConnection.create(
        serverId: 'default',
        serverUrl: 'http://localhost:8000',
        httpClient: DartHttpClient(),
      );

      await conn.close();
      await conn.close();
    });

    test('rejects serverUrl with /api/v1 suffix', () {
      expect(
        () => ServerConnection.create(
          serverId: 'default',
          serverUrl: 'http://localhost:8000/api/v1',
          httpClient: DartHttpClient(),
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('createVerboseConnection', () {
    test('returns non-null api and agUiStreamClient', () async {
      final conn = createVerboseConnection('http://localhost:8000');

      expect(conn.api, isA<SoliplexApi>());
      expect(conn.agUiStreamClient, isA<AgUiStreamClient>());

      await conn.close();
    });

    test('close can be called multiple times', () async {
      final conn = createVerboseConnection('http://localhost:8000');

      await conn.close();
      await conn.close();
    });
  });
}
