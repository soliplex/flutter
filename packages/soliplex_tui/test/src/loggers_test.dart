import 'package:soliplex_logging/soliplex_logging.dart';
import 'package:soliplex_tui/src/loggers.dart';
import 'package:test/test.dart';

void main() {
  group('Loggers', () {
    tearDown(LogManager.instance.reset);

    test('app logger has correct name', () {
      expect(Loggers.app.name, 'App');
    });

    test('chat logger has correct name', () {
      expect(Loggers.chat.name, 'Chat');
    });

    test('agui logger has correct name', () {
      expect(Loggers.agui.name, 'AgUi');
    });

    test('tool logger has correct name', () {
      expect(Loggers.tool.name, 'Tool');
    });
  });
}
