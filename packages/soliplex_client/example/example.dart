/// Minimal example showing how to create a `SoliplexApi` client and
/// interact with the backend.
///
/// ```bash
/// dart run example/example.dart
/// ```
///
/// Requires a running Soliplex backend at http://localhost:8000.
library;

import 'dart:io';

import 'package:soliplex_client/soliplex_client.dart';

Future<void> main() async {
  // 1. Create the HTTP transport.
  final httpClient = DartHttpClient();
  final transport = HttpTransport(client: httpClient);
  final urlBuilder = UrlBuilder('http://localhost:8000');

  // 2. Create the API client.
  final api = SoliplexApi(transport: transport, urlBuilder: urlBuilder);

  try {
    // 3. List rooms.
    final rooms = await api.getRooms();
    for (final room in rooms) {
      stdout.writeln('Room: ${room.id} -- ${room.name}');
    }

    // 4. Create a thread in the first room.
    if (rooms.isNotEmpty) {
      final (threadInfo, _) = await api.createThread(rooms.first.id);
      stdout.writeln('Created thread: ${threadInfo.id}');

      // 5. Start a run.
      final run = await api.createRun(rooms.first.id, threadInfo.id);
      stdout.writeln('Started run: ${run.id}');
    }
  } finally {
    api.close();
  }
}
