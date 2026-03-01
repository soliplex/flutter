import 'dart:io';

import 'package:soliplex_logging/soliplex_logging.dart';

/// Log sink that appends records to a file on disk.
class FileSink implements LogSink {
  FileSink({required String filePath})
      : _sink = File(filePath).openWrite(mode: FileMode.append);

  final IOSink _sink;

  @override
  void write(LogRecord record) {
    _sink.writeln(record);
  }

  @override
  Future<void> flush() => _sink.flush();

  @override
  Future<void> close() => _sink.close();
}
