import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:soliplex_frontend/core/auth/auth_provider.dart';
import 'package:soliplex_frontend/core/auth/auth_state.dart';

import '../../helpers/test_helpers.dart';

void main() {
  late MockAuthStorage mockStorage;
  late MockTokenRefreshService mockRefreshService;

  setUpAll(() {
    registerFallbackValue(TestData.createAuthenticated());
  });

  setUp(() {
    mockStorage = MockAuthStorage();
    mockRefreshService = MockTokenRefreshService();
  });

  ProviderContainer createContainer() {
    return ProviderContainer(
      overrides: [
        authStorageProvider.overrideWithValue(mockStorage),
        tokenRefreshServiceProvider.overrideWithValue(mockRefreshService),
      ],
    );
  }

  group('hasAppAccessProvider', () {
    test('returns true when Authenticated', () async {
      final validTokens = TestData.createAuthenticated();
      when(() => mockStorage.loadTokens()).thenAnswer((_) async => validTokens);

      final container = createContainer();
      addTearDown(container.dispose);

      container.read(authProvider);
      await waitForAuthRestore(container);

      expect(container.read(hasAppAccessProvider), isTrue);
    });

    test('returns true when NoAuthRequired', () async {
      when(() => mockStorage.loadTokens()).thenAnswer((_) async => null);

      final container = createContainer();
      addTearDown(container.dispose);

      container.read(authProvider);
      await waitForAuthRestore(container);

      await container.read(authProvider.notifier).enterNoAuthMode();

      expect(container.read(hasAppAccessProvider), isTrue);
    });

    test('returns false when Unauthenticated', () async {
      when(() => mockStorage.loadTokens()).thenAnswer((_) async => null);

      final container = createContainer();
      addTearDown(container.dispose);

      container.read(authProvider);
      await waitForAuthRestore(container);

      expect(container.read(hasAppAccessProvider), isFalse);
    });

    test('returns false when AuthLoading', () {
      // Don't await restore - catch it in loading state
      when(() => mockStorage.loadTokens()).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(seconds: 5));
        return null;
      });

      final container = createContainer();
      addTearDown(container.dispose);

      container.read(authProvider);

      expect(container.read(authProvider), isA<AuthLoading>());
      expect(container.read(hasAppAccessProvider), isFalse);
    });
  });

  group('accessTokenProvider', () {
    test('returns token when Authenticated', () async {
      final validTokens = TestData.createAuthenticated(
        accessToken: 'test-access-token-123',
      );
      when(() => mockStorage.loadTokens()).thenAnswer((_) async => validTokens);

      final container = createContainer();
      addTearDown(container.dispose);

      container.read(authProvider);
      await waitForAuthRestore(container);

      expect(container.read(accessTokenProvider), 'test-access-token-123');
    });

    test('returns null when NoAuthRequired', () async {
      when(() => mockStorage.loadTokens()).thenAnswer((_) async => null);

      final container = createContainer();
      addTearDown(container.dispose);

      container.read(authProvider);
      await waitForAuthRestore(container);

      await container.read(authProvider.notifier).enterNoAuthMode();

      expect(container.read(accessTokenProvider), isNull);
    });

    test('returns null when Unauthenticated', () async {
      when(() => mockStorage.loadTokens()).thenAnswer((_) async => null);

      final container = createContainer();
      addTearDown(container.dispose);

      container.read(authProvider);
      await waitForAuthRestore(container);

      expect(container.read(accessTokenProvider), isNull);
    });
  });

  group('authStatusListenableProvider', () {
    test('notifies on Unauthenticated -> NoAuthRequired transition', () async {
      when(() => mockStorage.loadTokens()).thenAnswer((_) async => null);

      final container = createContainer();
      addTearDown(container.dispose);

      container.read(authProvider);
      await waitForAuthRestore(container);

      final listenable = container.read(authStatusListenableProvider);

      var notificationCount = 0;
      void listener() {
        notificationCount++;
      }

      listenable.addListener(listener);

      await container.read(authProvider.notifier).enterNoAuthMode();

      expect(notificationCount, 1);

      listenable.removeListener(listener);
    });

    test('notifies on NoAuthRequired -> Unauthenticated transition', () async {
      when(() => mockStorage.loadTokens()).thenAnswer((_) async => null);

      final container = createContainer();
      addTearDown(container.dispose);

      container.read(authProvider);
      await waitForAuthRestore(container);

      await container.read(authProvider.notifier).enterNoAuthMode();

      final listenable = container.read(authStatusListenableProvider);

      var notificationCount = 0;
      void listener() {
        notificationCount++;
      }

      listenable.addListener(listener);

      container.read(authProvider.notifier).exitNoAuthMode();

      expect(notificationCount, 1);

      listenable.removeListener(listener);
    });

    test('notifies on access gained', () async {
      when(() => mockStorage.loadTokens()).thenAnswer((_) async => null);

      final container = createContainer();
      addTearDown(container.dispose);

      container.read(authProvider);
      await waitForAuthRestore(container);

      final listenable = container.read(authStatusListenableProvider);

      var notificationCount = 0;
      void listener() {
        notificationCount++;
      }

      listenable.addListener(listener);

      await container.read(authProvider.notifier).enterNoAuthMode();

      expect(notificationCount, 1);

      listenable.removeListener(listener);
    });

    test('does not notify when access status unchanged', () async {
      final validTokens = TestData.createAuthenticated();
      when(() => mockStorage.loadTokens()).thenAnswer((_) async => validTokens);

      final container = createContainer();
      addTearDown(container.dispose);

      container.read(authProvider);
      await waitForAuthRestore(container);

      final listenable = container.read(authStatusListenableProvider);

      var notificationCount = 0;
      void listener() {
        notificationCount++;
      }

      listenable.addListener(listener);

      expect(notificationCount, 0);

      listenable.removeListener(listener);
    });
  });
}
