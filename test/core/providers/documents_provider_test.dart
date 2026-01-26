import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_frontend/core/providers/api_provider.dart';
import 'package:soliplex_frontend/core/providers/documents_provider.dart';

import '../../helpers/test_helpers.dart';

/// Zero delays for fast test execution.
const _testDelays = [Duration.zero, Duration.zero, Duration.zero];

/// Waits for the documents provider to complete loading.
/// Returns the documents on success, throws on error.
Future<List<RagDocument>> waitForDocuments(
  ProviderContainer container,
  String roomId,
) async {
  final completer = Completer<List<RagDocument>>();
  final sub = container.listen<AsyncValue<List<RagDocument>>>(
    documentsProvider(roomId),
    (prev, next) {
      if (!completer.isCompleted) {
        if (next.hasValue) {
          completer.complete(next.value);
        } else if (next.hasError) {
          completer.completeError(next.error!, next.stackTrace);
        }
      }
    },
    fireImmediately: true,
  );
  try {
    return await completer.future;
  } finally {
    sub.close();
  }
}

void main() {
  group('shouldRetryDocumentsFetch', () {
    test('returns true for NetworkException', () {
      const error = NetworkException(message: 'Connection failed');
      expect(shouldRetryDocumentsFetch(error), isTrue);
    });

    test('returns true for ApiException with 5xx status', () {
      const error500 = ApiException(statusCode: 500, message: 'Server error');
      const error503 = ApiException(statusCode: 503, message: 'Unavailable');
      const error599 = ApiException(statusCode: 599, message: 'Server error');

      expect(shouldRetryDocumentsFetch(error500), isTrue);
      expect(shouldRetryDocumentsFetch(error503), isTrue);
      expect(shouldRetryDocumentsFetch(error599), isTrue);
    });

    test('returns true for ApiException with 408 Request Timeout', () {
      const error = ApiException(statusCode: 408, message: 'Request Timeout');
      expect(shouldRetryDocumentsFetch(error), isTrue);
    });

    test('returns true for ApiException with 429 Too Many Requests', () {
      const error = ApiException(statusCode: 429, message: 'Too Many Requests');
      expect(shouldRetryDocumentsFetch(error), isTrue);
    });

    test('returns false for NotFoundException', () {
      const error = NotFoundException(message: 'Not found');
      expect(shouldRetryDocumentsFetch(error), isFalse);
    });

    test('returns false for AuthException', () {
      const error401 = AuthException(statusCode: 401, message: 'Unauthorized');
      const error403 = AuthException(statusCode: 403, message: 'Forbidden');

      expect(shouldRetryDocumentsFetch(error401), isFalse);
      expect(shouldRetryDocumentsFetch(error403), isFalse);
    });

    test('returns false for CancelledException', () {
      const error = CancelledException();
      expect(shouldRetryDocumentsFetch(error), isFalse);
    });

    test('returns false for ApiException with 4xx client errors', () {
      const error400 = ApiException(statusCode: 400, message: 'Bad Request');
      const error422 = ApiException(statusCode: 422, message: 'Unprocessable');

      expect(shouldRetryDocumentsFetch(error400), isFalse);
      expect(shouldRetryDocumentsFetch(error422), isFalse);
    });
  });

  group('documentsProvider', () {
    late MockSoliplexApi mockApi;
    late ProviderContainer container;

    setUp(() {
      mockApi = MockSoliplexApi();
    });

    tearDown(() {
      container.dispose();
    });

    ProviderContainer createContainer() {
      return ProviderContainer(
        overrides: [
          apiProvider.overrideWithValue(mockApi),
          documentsRetryDelaysProvider.overrideWithValue(_testDelays),
        ],
      );
    }

    test('returns documents on success', () async {
      // Arrange
      final documents = [
        TestData.createDocument(id: 'doc-1', title: 'Document 1.pdf'),
        TestData.createDocument(id: 'doc-2', title: 'Document 2.pdf'),
      ];
      when(
        () => mockApi.getDocuments('room-1'),
      ).thenAnswer((_) async => documents);
      container = createContainer();

      // Act
      final result = await waitForDocuments(container, 'room-1');

      // Assert
      expect(result, equals(documents));
      verify(() => mockApi.getDocuments('room-1')).called(1);
    });

    group('retry logic', () {
      test('retries on 503 and succeeds on third attempt', () async {
        // Arrange
        final documents = [
          TestData.createDocument(id: 'doc-1', title: 'Document 1.pdf'),
        ];
        var callCount = 0;
        when(() => mockApi.getDocuments('room-1')).thenAnswer((_) async {
          callCount++;
          if (callCount < 3) {
            throw const ApiException(
              statusCode: 503,
              message: 'Service Unavailable',
            );
          }
          return documents;
        });
        container = createContainer();

        // Act
        final result = await waitForDocuments(container, 'room-1');

        // Assert
        expect(result, equals(documents));
        expect(callCount, equals(3));
      });

      test('retries on 500 and succeeds on second attempt', () async {
        // Arrange
        final documents = [
          TestData.createDocument(id: 'doc-1', title: 'Document 1.pdf'),
        ];
        var callCount = 0;
        when(() => mockApi.getDocuments('room-1')).thenAnswer((_) async {
          callCount++;
          if (callCount < 2) {
            throw const ApiException(
              statusCode: 500,
              message: 'Internal Server Error',
            );
          }
          return documents;
        });
        container = createContainer();

        // Act
        final result = await waitForDocuments(container, 'room-1');

        // Assert
        expect(result, equals(documents));
        expect(callCount, equals(2));
      });

      test('retries on 408 Request Timeout and succeeds', () async {
        // Arrange
        final documents = [
          TestData.createDocument(id: 'doc-1', title: 'Document 1.pdf'),
        ];
        var callCount = 0;
        when(() => mockApi.getDocuments('room-1')).thenAnswer((_) async {
          callCount++;
          if (callCount < 2) {
            throw const ApiException(
              statusCode: 408,
              message: 'Request Timeout',
            );
          }
          return documents;
        });
        container = createContainer();

        // Act
        final result = await waitForDocuments(container, 'room-1');

        // Assert
        expect(result, equals(documents));
        expect(callCount, equals(2));
      });

      test('retries on 429 Too Many Requests and succeeds', () async {
        // Arrange
        final documents = [
          TestData.createDocument(id: 'doc-1', title: 'Document 1.pdf'),
        ];
        var callCount = 0;
        when(() => mockApi.getDocuments('room-1')).thenAnswer((_) async {
          callCount++;
          if (callCount < 2) {
            throw const ApiException(
              statusCode: 429,
              message: 'Too Many Requests',
            );
          }
          return documents;
        });
        container = createContainer();

        // Act
        final result = await waitForDocuments(container, 'room-1');

        // Assert
        expect(result, equals(documents));
        expect(callCount, equals(2));
      });

      test('retries on NetworkException and succeeds', () async {
        // Arrange
        final documents = [
          TestData.createDocument(id: 'doc-1', title: 'Document 1.pdf'),
        ];
        var callCount = 0;
        when(() => mockApi.getDocuments('room-1')).thenAnswer((_) async {
          callCount++;
          if (callCount < 2) {
            throw const NetworkException(message: 'Connection failed');
          }
          return documents;
        });
        container = createContainer();

        // Act
        final result = await waitForDocuments(container, 'room-1');

        // Assert
        expect(result, equals(documents));
        expect(callCount, equals(2));
      });

      test('does not retry on 404 Not Found', () async {
        // Arrange - mock returns 404 first, then documents
        // If retry happened, we'd get documents. If not, we'd get error.
        final documents = [
          TestData.createDocument(id: 'doc-1', title: 'Document 1.pdf'),
        ];
        var callCount = 0;
        when(() => mockApi.getDocuments('room-1')).thenAnswer((_) async {
          callCount++;
          if (callCount == 1) {
            throw const NotFoundException(message: 'Room not found');
          }
          return documents;
        });
        container = createContainer();

        // Act - trigger the provider and wait for error
        Object? caughtError;
        try {
          await waitForDocuments(container, 'room-1');
        } catch (e) {
          caughtError = e;
        }

        // Assert - only called once (no retry) and error was thrown
        expect(callCount, equals(1));
        expect(caughtError, isA<NotFoundException>());
      });

      test('does not retry on 401 Unauthorized', () async {
        // Arrange
        final documents = [
          TestData.createDocument(id: 'doc-1', title: 'Document 1.pdf'),
        ];
        var callCount = 0;
        when(() => mockApi.getDocuments('room-1')).thenAnswer((_) async {
          callCount++;
          if (callCount == 1) {
            throw const AuthException(
              statusCode: 401,
              message: 'Unauthorized',
            );
          }
          return documents;
        });
        container = createContainer();

        // Act - trigger the provider and wait for error
        Object? caughtError;
        try {
          await waitForDocuments(container, 'room-1');
        } catch (e) {
          caughtError = e;
        }

        // Assert - only called once (no retry)
        expect(callCount, equals(1));
        expect(caughtError, isA<AuthException>());
      });

      test('does not retry on 400 Bad Request', () async {
        // Arrange
        final documents = [
          TestData.createDocument(id: 'doc-1', title: 'Document 1.pdf'),
        ];
        var callCount = 0;
        when(() => mockApi.getDocuments('room-1')).thenAnswer((_) async {
          callCount++;
          if (callCount == 1) {
            throw const ApiException(statusCode: 400, message: 'Bad Request');
          }
          return documents;
        });
        container = createContainer();

        // Act - trigger the provider and wait for error
        Object? caughtError;
        try {
          await waitForDocuments(container, 'room-1');
        } catch (e) {
          caughtError = e;
        }

        // Assert - only called once (no retry)
        expect(callCount, equals(1));
        expect(caughtError, isA<ApiException>());
      });
    });
  });
}
