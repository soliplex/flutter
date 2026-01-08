import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:soliplex_frontend/core/auth/auth_state.dart';
import 'package:soliplex_frontend/core/auth/auth_storage.dart';
import 'package:soliplex_frontend/core/auth/auth_storage_native.dart';

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late MockFlutterSecureStorage mockStorage;
  late AuthStorage authStorage;

  setUp(() {
    mockStorage = MockFlutterSecureStorage();
    authStorage = NativeAuthStorage(storage: mockStorage);
  });

  group('saveTokens', () {
    test('writes all token fields to storage', () async {
      when(
        () => mockStorage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) async {});

      final expiresAt = DateTime(2025, 12, 31, 12);

      await authStorage.saveTokens(
        Authenticated(
          accessToken: 'access-token',
          refreshToken: 'refresh-token',
          expiresAt: expiresAt,
          issuerId: 'issuer-1',
          issuerDiscoveryUrl: 'https://idp.example.com/.well-known',
          clientId: 'client-app',
          idToken: 'id-token',
        ),
      );

      verify(
        () => mockStorage.write(
          key: AuthStorageKeys.accessToken,
          value: 'access-token',
        ),
      ).called(1);
      verify(
        () => mockStorage.write(
          key: AuthStorageKeys.refreshToken,
          value: 'refresh-token',
        ),
      ).called(1);
      verify(
        () => mockStorage.write(
          key: AuthStorageKeys.expiresAt,
          value: expiresAt.toIso8601String(),
        ),
      ).called(1);
      verify(
        () =>
            mockStorage.write(key: AuthStorageKeys.issuerId, value: 'issuer-1'),
      ).called(1);
      verify(
        () => mockStorage.write(
          key: AuthStorageKeys.issuerDiscoveryUrl,
          value: 'https://idp.example.com/.well-known',
        ),
      ).called(1);
      verify(
        () => mockStorage.write(
          key: AuthStorageKeys.clientId,
          value: 'client-app',
        ),
      ).called(1);
      verify(
        () =>
            mockStorage.write(key: AuthStorageKeys.idToken, value: 'id-token'),
      ).called(1);
    });

    test('does not write endSessionEndpoint (native uses discoveryUrl)',
        () async {
      when(
        () => mockStorage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) async {});

      await authStorage.saveTokens(
        Authenticated(
          accessToken: 'access-token',
          refreshToken: 'refresh-token',
          expiresAt: DateTime(2025, 12, 31, 12),
          issuerId: 'issuer-1',
          issuerDiscoveryUrl: 'https://idp.example.com/.well-known',
          clientId: 'client-app',
          idToken: 'id-token',
          endSessionEndpoint: 'https://idp.example.com/logout',
        ),
      );

      // Native doesn't persist endSessionEndpoint - flutter_appauth
      // fetches it from discoveryUrl at logout time.
      verifyNever(
        () => mockStorage.write(
          key: AuthStorageKeys.endSessionEndpoint,
          value: any(named: 'value'),
        ),
      );
    });
  });

  void setupAllRequiredReads({
    String accessToken = 'access-token',
    String refreshToken = 'refresh-token',
    String expiresAt = '2025-12-31T12:00:00.000',
    String issuerId = 'issuer-1',
    String issuerDiscoveryUrl = 'https://idp.example.com/.well-known',
    String clientId = 'client-app',
    String idToken = 'id-token',
  }) {
    when(
      () => mockStorage.read(key: AuthStorageKeys.accessToken),
    ).thenAnswer((_) async => accessToken);
    when(
      () => mockStorage.read(key: AuthStorageKeys.refreshToken),
    ).thenAnswer((_) async => refreshToken);
    when(
      () => mockStorage.read(key: AuthStorageKeys.expiresAt),
    ).thenAnswer((_) async => expiresAt);
    when(
      () => mockStorage.read(key: AuthStorageKeys.issuerId),
    ).thenAnswer((_) async => issuerId);
    when(
      () => mockStorage.read(key: AuthStorageKeys.issuerDiscoveryUrl),
    ).thenAnswer((_) async => issuerDiscoveryUrl);
    when(
      () => mockStorage.read(key: AuthStorageKeys.clientId),
    ).thenAnswer((_) async => clientId);
    when(
      () => mockStorage.read(key: AuthStorageKeys.idToken),
    ).thenAnswer((_) async => idToken);
  }

  group('loadTokens', () {
    test('returns Authenticated when all required fields exist', () async {
      final expiresAt = DateTime(2025, 12, 31, 12);

      when(
        () => mockStorage.read(key: AuthStorageKeys.accessToken),
      ).thenAnswer((_) async => 'access-token');
      when(
        () => mockStorage.read(key: AuthStorageKeys.refreshToken),
      ).thenAnswer((_) async => 'refresh-token');
      when(
        () => mockStorage.read(key: AuthStorageKeys.expiresAt),
      ).thenAnswer((_) async => expiresAt.toIso8601String());
      when(
        () => mockStorage.read(key: AuthStorageKeys.issuerId),
      ).thenAnswer((_) async => 'issuer-1');
      when(
        () => mockStorage.read(key: AuthStorageKeys.issuerDiscoveryUrl),
      ).thenAnswer((_) async => 'https://idp.example.com/.well-known');
      when(
        () => mockStorage.read(key: AuthStorageKeys.clientId),
      ).thenAnswer((_) async => 'client-app');
      when(
        () => mockStorage.read(key: AuthStorageKeys.idToken),
      ).thenAnswer((_) async => 'id-token');

      final tokens = await authStorage.loadTokens();

      expect(tokens, isNotNull);
      expect(tokens!.accessToken, 'access-token');
      expect(tokens.refreshToken, 'refresh-token');
      expect(tokens.expiresAt, expiresAt);
      expect(tokens.issuerId, 'issuer-1');
      expect(tokens.issuerDiscoveryUrl, 'https://idp.example.com/.well-known');
      expect(tokens.clientId, 'client-app');
      expect(tokens.idToken, 'id-token');
      // Native doesn't persist endSessionEndpoint - always null
      expect(tokens.endSessionEndpoint, isNull);
    });

    test('returns null when accessToken is missing', () async {
      setupAllRequiredReads();
      when(
        () => mockStorage.read(key: AuthStorageKeys.accessToken),
      ).thenAnswer((_) async => null);

      final tokens = await authStorage.loadTokens();

      expect(tokens, isNull);
    });

    test('returns null when refreshToken is missing', () async {
      setupAllRequiredReads();
      when(
        () => mockStorage.read(key: AuthStorageKeys.refreshToken),
      ).thenAnswer((_) async => null);

      final tokens = await authStorage.loadTokens();

      expect(tokens, isNull);
    });

    test('returns null when expiresAt is missing', () async {
      setupAllRequiredReads();
      when(
        () => mockStorage.read(key: AuthStorageKeys.expiresAt),
      ).thenAnswer((_) async => null);

      final tokens = await authStorage.loadTokens();

      expect(tokens, isNull);
    });

    test('returns null when expiresAt is malformed', () async {
      setupAllRequiredReads();
      when(
        () => mockStorage.read(key: AuthStorageKeys.expiresAt),
      ).thenAnswer((_) async => 'not-a-date');

      final tokens = await authStorage.loadTokens();

      expect(tokens, isNull);
    });

    test('returns null when issuerId is missing', () async {
      setupAllRequiredReads();
      when(
        () => mockStorage.read(key: AuthStorageKeys.issuerId),
      ).thenAnswer((_) async => null);

      final tokens = await authStorage.loadTokens();

      expect(tokens, isNull);
    });

    test('returns null when issuerDiscoveryUrl is missing', () async {
      setupAllRequiredReads();
      when(
        () => mockStorage.read(key: AuthStorageKeys.issuerDiscoveryUrl),
      ).thenAnswer((_) async => null);

      final tokens = await authStorage.loadTokens();

      expect(tokens, isNull);
    });

    test('returns null when clientId is missing', () async {
      setupAllRequiredReads();
      when(
        () => mockStorage.read(key: AuthStorageKeys.clientId),
      ).thenAnswer((_) async => null);

      final tokens = await authStorage.loadTokens();

      expect(tokens, isNull);
    });

    test('returns null when idToken is missing', () async {
      setupAllRequiredReads();
      when(
        () => mockStorage.read(key: AuthStorageKeys.idToken),
      ).thenAnswer((_) async => null);

      final tokens = await authStorage.loadTokens();

      expect(tokens, isNull);
    });
  });

  group('clearTokens', () {
    test('deletes all token keys from storage', () async {
      when(
        () => mockStorage.delete(key: any(named: 'key')),
      ).thenAnswer((_) async {});

      await authStorage.clearTokens();

      verify(
        () => mockStorage.delete(key: AuthStorageKeys.accessToken),
      ).called(1);
      verify(
        () => mockStorage.delete(key: AuthStorageKeys.refreshToken),
      ).called(1);
      verify(() => mockStorage.delete(key: AuthStorageKeys.idToken)).called(1);
      verify(
        () => mockStorage.delete(key: AuthStorageKeys.expiresAt),
      ).called(1);
      verify(() => mockStorage.delete(key: AuthStorageKeys.issuerId)).called(1);
      verify(
        () => mockStorage.delete(key: AuthStorageKeys.issuerDiscoveryUrl),
      ).called(1);
      verify(() => mockStorage.delete(key: AuthStorageKeys.clientId)).called(1);
      // Native doesn't persist endSessionEndpoint - no delete expected.
    });
  });

  group('PreAuthState', () {
    test('stores all constructor parameters', () {
      final createdAt = DateTime(2025, 6, 15, 10, 30);
      final state = PreAuthState(
        issuerId: 'google',
        discoveryUrl:
            'https://accounts.google.com/.well-known/openid-configuration',
        clientId: 'client-123',
        createdAt: createdAt,
      );

      expect(state.issuerId, 'google');
      expect(
        state.discoveryUrl,
        'https://accounts.google.com/.well-known/openid-configuration',
      );
      expect(state.clientId, 'client-123');
      expect(state.createdAt, createdAt);
    });

    test('isExpired returns false for recent state', () {
      final state = PreAuthState(
        issuerId: 'google',
        discoveryUrl: 'https://example.com',
        clientId: 'client-123',
        createdAt: DateTime.now(),
      );

      expect(state.isExpired, isFalse);
    });

    test('isExpired returns true for old state', () {
      final state = PreAuthState(
        issuerId: 'google',
        discoveryUrl: 'https://example.com',
        clientId: 'client-123',
        createdAt: DateTime.now().subtract(const Duration(minutes: 6)),
      );

      expect(state.isExpired, isTrue);
    });

    test('equality based on all fields', () {
      final createdAt = DateTime(2025, 6, 15, 10, 30);
      final state1 = PreAuthState(
        issuerId: 'google',
        discoveryUrl: 'https://example.com',
        clientId: 'client-123',
        createdAt: createdAt,
      );
      final state2 = PreAuthState(
        issuerId: 'google',
        discoveryUrl: 'https://example.com',
        clientId: 'client-123',
        createdAt: createdAt,
      );
      final state3 = PreAuthState(
        issuerId: 'microsoft',
        discoveryUrl: 'https://example.com',
        clientId: 'client-123',
        createdAt: createdAt,
      );

      expect(state1, equals(state2));
      expect(state1, isNot(equals(state3)));
    });

    test('hashCode is consistent with equality', () {
      final createdAt = DateTime(2025, 6, 15, 10, 30);
      final state1 = PreAuthState(
        issuerId: 'google',
        discoveryUrl: 'https://example.com',
        clientId: 'client-123',
        createdAt: createdAt,
      );
      final state2 = PreAuthState(
        issuerId: 'google',
        discoveryUrl: 'https://example.com',
        clientId: 'client-123',
        createdAt: createdAt,
      );

      expect(state1.hashCode, equals(state2.hashCode));
    });

    test('toString shows issuerId and createdAt', () {
      final createdAt = DateTime(2025, 6, 15, 10, 30);
      final state = PreAuthState(
        issuerId: 'google',
        discoveryUrl: 'https://example.com',
        clientId: 'client-123',
        createdAt: createdAt,
      );

      expect(state.toString(), contains('issuerId: google'));
      expect(state.toString(), contains('createdAt:'));
    });
  });
}
