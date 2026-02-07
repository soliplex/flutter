import 'package:soliplex_logging/soliplex_logging.dart';
import 'package:test/test.dart';

void main() {
  late MemorySink memorySink;

  setUp(() {
    LogManager.instance
      ..reset()
      ..addSink(memorySink = MemorySink());
  });

  tearDown(LogManager.instance.reset);

  group('Attributes through sink pipeline', () {
    test('attributes survive Logger → LogManager → MemorySink', () {
      final attributes = {
        'user_id': 'u-42',
        'http_status': 200,
        'view_name': 'chat',
      };

      LogManager.instance.getLogger('Integration').info(
            'User opened chat',
            attributes: attributes,
          );

      expect(memorySink.records, hasLength(1));

      final captured = memorySink.records.first;
      expect(captured.message, 'User opened chat');
      expect(captured.loggerName, 'Integration');
      expect(captured.level, LogLevel.info);
      expect(captured.attributes, attributes);
      expect(captured.attributes['user_id'], 'u-42');
      expect(captured.attributes['http_status'], 200);
      expect(captured.attributes['view_name'], 'chat');
    });

    test('empty attributes survive pipeline', () {
      LogManager.instance.getLogger('Integration').info('No attributes');

      expect(memorySink.records, hasLength(1));
      expect(memorySink.records.first.attributes, isEmpty);
    });

    test('attributes from multiple log levels survive pipeline', () {
      LogManager.instance.getLogger('Multi')
        ..info('Info msg', attributes: const {'level': 'info'})
        ..warning('Warn msg', attributes: const {'level': 'warning'})
        ..error('Error msg', attributes: const {'level': 'error'});

      expect(memorySink.records, hasLength(3));
      expect(memorySink.records[0].attributes, {'level': 'info'});
      expect(memorySink.records[1].attributes, {'level': 'warning'});
      expect(memorySink.records[2].attributes, {'level': 'error'});
    });
  });
}
