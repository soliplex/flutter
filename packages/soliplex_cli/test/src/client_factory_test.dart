import 'package:soliplex_cli/src/client_factory.dart';
import 'package:soliplex_client/soliplex_client.dart'
    show AgUiClient, SoliplexApi;
import 'package:test/test.dart';

void main() {
  group('ServerConnection.fromUrl', () {
    test('returns non-null api and agUiClient', () async {
      final conn = ServerConnection.fromUrl(
        serverUrl: 'http://localhost:8000',
      );

      expect(conn.api, isA<SoliplexApi>());
      expect(conn.agUiClient, isA<AgUiClient>());

      await conn.close();
    });

    test('close can be called multiple times', () async {
      final conn = ServerConnection.fromUrl(
        serverUrl: 'http://localhost:8000',
      );

      await conn.close();
      await conn.close();
    });

    test('rejects serverUrl with /api/v1 suffix', () {
      expect(
        () => ServerConnection.fromUrl(
          serverUrl: 'http://localhost:8000/api/v1',
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('createVerboseConnection', () {
    test('returns non-null api and agUiClient', () async {
      final conn = createVerboseConnection('http://localhost:8000');

      expect(conn.api, isA<SoliplexApi>());
      expect(conn.agUiClient, isA<AgUiClient>());

      await conn.close();
    });

    test('close can be called multiple times', () async {
      final conn = createVerboseConnection('http://localhost:8000');

      await conn.close();
      await conn.close();
    });
  });
}
