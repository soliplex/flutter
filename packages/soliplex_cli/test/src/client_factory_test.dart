import 'package:soliplex_cli/src/client_factory.dart';
import 'package:soliplex_client/soliplex_client.dart'
    show AgUiClient, SoliplexApi;
import 'package:test/test.dart';

void main() {
  group('createClientBundle', () {
    test('returns non-null api and agUiClient', () async {
      final bundle = createClientBundle('http://localhost:8000');

      expect(bundle.api, isA<SoliplexApi>());
      expect(bundle.agUiClient, isA<AgUiClient>());

      await bundle.close();
    });

    test('close can be called multiple times', () async {
      final bundle = createClientBundle('http://localhost:8000');

      await bundle.close();
      // Second call should not throw.
      await bundle.close();
    });

    test('rejects serverUrl with /api/v1 suffix', () {
      expect(
        () => createClientBundle('http://localhost:8000/api/v1'),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('createVerboseBundle', () {
    test('returns non-null api and agUiClient', () async {
      final bundle = createVerboseBundle('http://localhost:8000');

      expect(bundle.api, isA<SoliplexApi>());
      expect(bundle.agUiClient, isA<AgUiClient>());

      await bundle.close();
    });

    test('close can be called multiple times', () async {
      final bundle = createVerboseBundle('http://localhost:8000');

      await bundle.close();
      // Second call should not throw.
      await bundle.close();
    });
  });
}
