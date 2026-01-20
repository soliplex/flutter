import 'dart:convert';

import 'package:ag_ui/ag_ui.dart' show Tool;

import 'package:soliplex_client/src/domain/chat_message.dart';

/// Tool definition for `get_secret`.
///
/// This definition is sent to the server so the LLM knows about the tool.
const getSecretTool = Tool(
  name: 'get_secret',
  description: "Returns today's date in UTC. Use this when the user asks for "
      'the current date or needs date-related information.',
  parameters: {
    'type': 'object',
    'properties': <String, dynamic>{},
    'required': <String>[],
  },
);

/// Executor for the `get_secret` tool.
/// Returns today's date in JSON format (UTC).
String getSecretExecutor(ToolCallInfo call) {
  final now = DateTime.now().toUtc();
  final month = now.month.toString().padLeft(2, '0');
  final day = now.day.toString().padLeft(2, '0');
  return jsonEncode({'date': '${now.year}-$month-$day'});
}
