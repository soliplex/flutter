import 'package:soliplex_logging/soliplex_logging.dart';
import 'package:test/test.dart';

void main() {
  late LogSanitizer sanitizer;

  setUp(() {
    sanitizer = LogSanitizer();
  });

  LogRecord makeRecord({
    String message = 'Test message',
    Map<String, Object> attributes = const {},
    StackTrace? stackTrace,
  }) {
    return LogRecord(
      level: LogLevel.info,
      message: message,
      timestamp: DateTime(2024),
      loggerName: 'Test',
      attributes: attributes,
      stackTrace: stackTrace,
    );
  }

  group('LogSanitizer', () {
    group('key redaction', () {
      test('redacts password key', () {
        final record = makeRecord(
          attributes: const {'password': 'secret123', 'name': 'Alice'},
        );
        final result = sanitizer.sanitize(record);
        expect(result.attributes['password'], '[REDACTED]');
        expect(result.attributes['name'], 'Alice');
      });

      test('redacts token key', () {
        final record = makeRecord(
          attributes: const {'token': 'abc-def'},
        );
        final result = sanitizer.sanitize(record);
        expect(result.attributes['token'], '[REDACTED]');
      });

      test('redacts auth key', () {
        final record = makeRecord(
          attributes: const {'auth': 'bearer xyz'},
        );
        final result = sanitizer.sanitize(record);
        expect(result.attributes['auth'], '[REDACTED]');
      });

      test('redacts authorization key', () {
        final record = makeRecord(
          attributes: const {'Authorization': 'Bearer xyz'},
        );
        final result = sanitizer.sanitize(record);
        expect(result.attributes['Authorization'], '[REDACTED]');
      });

      test('redacts secret key', () {
        final record = makeRecord(
          attributes: const {'secret': 'mysecret'},
        );
        final result = sanitizer.sanitize(record);
        expect(result.attributes['secret'], '[REDACTED]');
      });

      test('redacts ssn key', () {
        final record = makeRecord(
          attributes: const {'ssn': '123-45-6789'},
        );
        final result = sanitizer.sanitize(record);
        expect(result.attributes['ssn'], '[REDACTED]');
      });

      test('redacts credential key', () {
        final record = makeRecord(
          attributes: const {'credential': 'cred-value'},
        );
        final result = sanitizer.sanitize(record);
        expect(result.attributes['credential'], '[REDACTED]');
      });

      test('key matching is case-insensitive', () {
        final record = makeRecord(
          attributes: const {'PASSWORD': 'secret', 'Token': 'abc'},
        );
        final result = sanitizer.sanitize(record);
        expect(result.attributes['PASSWORD'], '[REDACTED]');
        expect(result.attributes['Token'], '[REDACTED]');
      });
    });

    group('pattern scrubbing', () {
      test('scrubs email addresses', () {
        final record = makeRecord(message: 'Contact: user@example.com');
        final result = sanitizer.sanitize(record);
        expect(result.message, 'Contact: [REDACTED]');
      });

      test('scrubs SSN patterns', () {
        final record = makeRecord(message: 'SSN is 123-45-6789');
        final result = sanitizer.sanitize(record);
        expect(result.message, 'SSN is [REDACTED]');
      });

      test('scrubs bearer tokens', () {
        final record = makeRecord(
          message: 'Auth header: Bearer eyJhbGciOiJSUzI1NiJ9',
        );
        final result = sanitizer.sanitize(record);
        expect(result.message, contains('[REDACTED]'));
        expect(result.message, isNot(contains('eyJ')));
      });

      test('scrubs IPv4 addresses', () {
        final record = makeRecord(message: 'Connecting to 192.168.1.100');
        final result = sanitizer.sanitize(record);
        expect(result.message, 'Connecting to [REDACTED]');
      });

      test('scrubs multiple patterns in one message', () {
        final record = makeRecord(
          message: 'User user@test.com from 10.0.0.1',
        );
        final result = sanitizer.sanitize(record);
        expect(result.message, 'User [REDACTED] from [REDACTED]');
      });
    });

    group('stack trace trimming', () {
      test('strips absolute paths to relative', () {
        final stack = StackTrace.fromString(
          '#0 main (/home/user/project/lib/main.dart:10:5)\n'
          '#1 run (/home/user/project/test/main_test.dart:20:3)',
        );
        final record = makeRecord(stackTrace: stack);
        final result = sanitizer.sanitize(record);
        final stackStr = result.stackTrace.toString();
        expect(stackStr, contains('lib/main.dart:10:5'));
        expect(stackStr, contains('test/main_test.dart:20:3'));
        expect(stackStr, isNot(contains('/home/user/project/')));
      });
    });

    group('custom configuration', () {
      test('additional keys are redacted', () {
        final custom = LogSanitizer(additionalKeys: {'api_key'});
        final record = makeRecord(
          attributes: const {'api_key': 'my-key', 'name': 'Bob'},
        );
        final result = custom.sanitize(record);
        expect(result.attributes['api_key'], '[REDACTED]');
        expect(result.attributes['name'], 'Bob');
      });

      test('additional patterns are scrubbed', () {
        final custom = LogSanitizer(
          additionalPatterns: [RegExp(r'CLASSIFIED-\w+')],
        );
        final record = makeRecord(
          message: 'Ref: CLASSIFIED-ALPHA123',
        );
        final result = custom.sanitize(record);
        expect(result.message, 'Ref: [REDACTED]');
      });
    });

    group('safe records', () {
      test('does not modify records without sensitive data', () {
        final record = makeRecord(
          message: 'Normal log message',
          attributes: const {'view_name': 'home', 'count': 5},
        );
        final result = sanitizer.sanitize(record);
        expect(result.message, 'Normal log message');
        expect(result.attributes['view_name'], 'home');
        expect(result.attributes['count'], 5);
      });

      test('returns new record (immutability)', () {
        final record = makeRecord(
          message: 'Original',
          attributes: const {'password': 'secret'},
        );
        final result = sanitizer.sanitize(record);
        expect(result, isNot(same(record)));
        expect(record.attributes['password'], 'secret');
        expect(result.attributes['password'], '[REDACTED]');
      });
    });
  });
}
