import 'dart:convert';
import 'dart:typed_data';

import 'package:mocktail/mocktail.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:test/test.dart';

class MockSoliplexHttpClient extends Mock implements SoliplexHttpClient {}

void main() {
  const discoveryUrl =
      'https://idp.example.com/.well-known/openid-configuration';
  final discoveryUri = Uri.parse(discoveryUrl);

  HttpResponse jsonResponse(
    Map<String, dynamic> body, {
    int statusCode = 200,
  }) {
    return HttpResponse(
      statusCode: statusCode,
      bodyBytes: Uint8List.fromList(utf8.encode(jsonEncode(body))),
    );
  }

  group('OidcDiscoveryDocument', () {
    group('fromJson', () {
      test('returns document with both endpoints when present', () {
        final json = {
          'token_endpoint': 'https://idp.example.com/oauth2/token',
          'end_session_endpoint': 'https://idp.example.com/oauth2/logout',
        };

        final doc = OidcDiscoveryDocument.fromJson(json, discoveryUri);

        expect(
          doc.tokenEndpoint.toString(),
          'https://idp.example.com/oauth2/token',
        );
        expect(
          doc.endSessionEndpoint?.toString(),
          'https://idp.example.com/oauth2/logout',
        );
      });

      test('returns document with null endSessionEndpoint when not present',
          () {
        final json = {
          'token_endpoint': 'https://idp.example.com/oauth2/token',
        };

        final doc = OidcDiscoveryDocument.fromJson(json, discoveryUri);

        expect(
          doc.tokenEndpoint.toString(),
          'https://idp.example.com/oauth2/token',
        );
        expect(doc.endSessionEndpoint, isNull);
      });

      test('throws FormatException when token_endpoint is missing', () {
        final json = {
          'end_session_endpoint': 'https://idp.example.com/oauth2/logout',
        };

        expect(
          () => OidcDiscoveryDocument.fromJson(json, discoveryUri),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('token_endpoint'),
            ),
          ),
        );
      });

      test('throws FormatException on scheme mismatch for token_endpoint', () {
        final json = {
          // http not https
          'token_endpoint': 'http://idp.example.com/oauth2/token',
        };

        expect(
          () => OidcDiscoveryDocument.fromJson(json, discoveryUri),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('origin mismatch'),
            ),
          ),
        );
      });

      test('throws FormatException on host mismatch for token_endpoint', () {
        final json = {
          'token_endpoint': 'https://evil.example.com/oauth2/token',
        };

        expect(
          () => OidcDiscoveryDocument.fromJson(json, discoveryUri),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('origin mismatch'),
            ),
          ),
        );
      });

      test('throws FormatException on port mismatch for token_endpoint', () {
        final json = {
          'token_endpoint': 'https://idp.example.com:8443/oauth2/token',
        };

        expect(
          () => OidcDiscoveryDocument.fromJson(json, discoveryUri),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('origin mismatch'),
            ),
          ),
        );
      });

      test(
        'throws FormatException on origin mismatch for end_session_endpoint',
        () {
          final json = {
            'token_endpoint': 'https://idp.example.com/oauth2/token',
            'end_session_endpoint': 'https://evil.example.com/logout',
          };

          expect(
            () => OidcDiscoveryDocument.fromJson(json, discoveryUri),
            throwsA(
              isA<FormatException>().having(
                (e) => e.message,
                'message',
                contains('end_session_endpoint'),
              ),
            ),
          );
        },
      );
    });
  });

  group('fetchOidcDiscoveryDocument', () {
    late MockSoliplexHttpClient mockClient;

    setUpAll(() {
      registerFallbackValue(Uri.parse('https://example.com'));
    });

    setUp(() {
      mockClient = MockSoliplexHttpClient();
    });

    tearDown(() {
      reset(mockClient);
    });

    test('returns document on successful fetch', () async {
      when(
        () => mockClient.request(
          'GET',
          discoveryUri,
          timeout: any(named: 'timeout'),
        ),
      ).thenAnswer(
        (_) async => jsonResponse({
          'token_endpoint': 'https://idp.example.com/oauth2/token',
          'end_session_endpoint': 'https://idp.example.com/oauth2/logout',
        }),
      );

      final doc = await fetchOidcDiscoveryDocument(discoveryUri, mockClient);

      expect(
        doc.tokenEndpoint.toString(),
        'https://idp.example.com/oauth2/token',
      );
      expect(
        doc.endSessionEndpoint?.toString(),
        'https://idp.example.com/oauth2/logout',
      );
    });

    test('throws NetworkException on HTTP error', () async {
      when(
        () => mockClient.request(
          'GET',
          discoveryUri,
          timeout: any(named: 'timeout'),
        ),
      ).thenThrow(Exception('Connection refused'));

      expect(
        () => fetchOidcDiscoveryDocument(discoveryUri, mockClient),
        throwsA(isA<NetworkException>()),
      );
    });

    test('throws FormatException on non-200 status', () async {
      when(
        () => mockClient.request(
          'GET',
          discoveryUri,
          timeout: any(named: 'timeout'),
        ),
      ).thenAnswer((_) async => jsonResponse({}, statusCode: 404));

      expect(
        () => fetchOidcDiscoveryDocument(discoveryUri, mockClient),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('404'),
          ),
        ),
      );
    });

    test('throws FormatException on invalid JSON', () async {
      when(
        () => mockClient.request(
          'GET',
          discoveryUri,
          timeout: any(named: 'timeout'),
        ),
      ).thenAnswer(
        (_) async => HttpResponse(
          statusCode: 200,
          bodyBytes: Uint8List.fromList(utf8.encode('not json')),
        ),
      );

      expect(
        () => fetchOidcDiscoveryDocument(discoveryUri, mockClient),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException when token_endpoint missing', () async {
      when(
        () => mockClient.request(
          'GET',
          discoveryUri,
          timeout: any(named: 'timeout'),
        ),
      ).thenAnswer(
        (_) async => jsonResponse({
          'end_session_endpoint': 'https://idp.example.com/logout',
        }),
      );

      expect(
        () => fetchOidcDiscoveryDocument(discoveryUri, mockClient),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('token_endpoint'),
          ),
        ),
      );
    });
  });
}
