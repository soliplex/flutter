import 'dart:convert';
import 'dart:io';

import 'package:ag_ui/ag_ui.dart' show Tool;

import 'package:soliplex_client/src/domain/chat_message.dart';

/// Allowed test targets for the patrol_run tool.
///
/// Only files in this list can be executed to prevent arbitrary
/// command execution through the tool.
const allowedPatrolTargets = <String>{
  'smoke_test.dart',
  'live_chat_test.dart',
  'settings_test.dart',
  'oidc_test.dart',
};

/// Maximum characters of process output returned to the LLM.
///
/// Keeps the tool result within a reasonable context window budget.
const maxOutputChars = 2000;

/// Tool definition for `patrol_run`.
///
/// Sent to the server so the LLM can trigger local Patrol E2E tests.
const patrolRunTool = Tool(
  name: 'patrol_run',
  description: 'Run a Patrol E2E integration test on the local machine.',
  parameters: {
    'type': 'object',
    'properties': {
      'target': {
        'type': 'string',
        'description': 'Test file name (e.g. smoke_test.dart). '
            'Allowed: smoke_test.dart, live_chat_test.dart, '
            'settings_test.dart, oidc_test.dart',
      },
      'backend_url': {
        'type': 'string',
        'description': 'Backend URL (default: http://localhost:8000)',
      },
    },
    'required': <String>['target'],
  },
);

/// Executes the `patrol_run` tool locally via `patrol test`.
///
/// Parses [call].arguments for `target` (required) and `backend_url`
/// (optional, defaults to `http://localhost:8000`). Validates the target
/// against [allowedPatrolTargets] and runs the patrol CLI.
///
/// Returns a JSON string with `exit_code`, `passed` flag, and truncated
/// `output` (last [maxOutputChars] characters of combined stdout/stderr).
Future<String> patrolRunExecutor(ToolCallInfo call) async {
  final args = _parseArguments(call.arguments);
  final target = args['target'] as String?;

  if (target == null || target.isEmpty) {
    return jsonEncode({
      'error': 'Missing required argument: target',
      'allowed_targets': allowedPatrolTargets.toList(),
    });
  }

  if (!allowedPatrolTargets.contains(target)) {
    return jsonEncode({
      'error': 'Target not in allowlist: $target',
      'allowed_targets': allowedPatrolTargets.toList(),
    });
  }

  final backendUrl = args['backend_url'] as String? ?? 'http://localhost:8000';

  final targetPath = 'integration_test/$target';

  final result = await Process.run(
    'patrol',
    ['test', '--target', targetPath],
    environment: {'BACKEND_URL': backendUrl},
    workingDirectory: Directory.current.path,
  );

  final combined = '${result.stdout}\n${result.stderr}'.trim();
  final truncated = combined.length > maxOutputChars
      ? combined.substring(combined.length - maxOutputChars)
      : combined;

  return jsonEncode({
    'exit_code': result.exitCode,
    'passed': result.exitCode == 0,
    'output': truncated,
  });
}

Map<String, dynamic> _parseArguments(String arguments) {
  if (arguments.isEmpty) return <String, dynamic>{};
  try {
    return jsonDecode(arguments) as Map<String, dynamic>;
  } on FormatException {
    return <String, dynamic>{};
  }
}
