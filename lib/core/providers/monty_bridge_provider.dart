import 'dart:convert';

import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_monty/soliplex_monty.dart';

/// Creates an `execute_python` [ClientTool] backed by the given [bridge].
///
/// The tool accepts a JSON body with a `code` field, executes it via the
/// bridge, and collects text output. Returns the output string or an error
/// message prefixed with "Error: ".
ClientTool createExecutePythonTool(MontyBridge bridge) {
  return ClientTool(
    definition: PythonExecutorTool.definition,
    executor: (toolCall) async {
      final args = jsonDecode(toolCall.arguments) as Map<String, dynamic>;
      final code = args['code'] as String? ?? '';
      if (code.isEmpty) return 'Error: No code provided';

      final output = StringBuffer();
      await for (final event in bridge.execute(code)) {
        if (event is TextMessageContentEvent) output.write(event.delta);
        if (event is RunErrorEvent) return 'Error: ${event.message}';
      }
      return output.isEmpty ? '(no output)' : output.toString();
    },
  );
}
