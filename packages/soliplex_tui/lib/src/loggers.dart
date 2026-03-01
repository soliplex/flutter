import 'package:soliplex_logging/soliplex_logging.dart';

/// Central logger accessors for the TUI application.
abstract final class Loggers {
  static final Logger app = LogManager.instance.getLogger('App');
  static final Logger chat = LogManager.instance.getLogger('Chat');
  static final Logger agui = LogManager.instance.getLogger('AgUi');
  static final Logger tool = LogManager.instance.getLogger('Tool');
}
