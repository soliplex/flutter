import 'dart:convert';

import 'package:soliplex_client/soliplex_client.dart';
import 'package:test/test.dart';

void main() {
  group('patrolRunTool definition', () {
    test('has correct name', () {
      expect(patrolRunTool.name, equals('patrol_run'));
    });

    test('has description mentioning Patrol', () {
      expect(patrolRunTool.description, isNotEmpty);
      expect(
        patrolRunTool.description.toLowerCase(),
        contains('patrol'),
      );
    });

    test('has parameters schema with target', () {
      expect(patrolRunTool.parameters, isA<Map<String, dynamic>>());
      final params = patrolRunTool.parameters as Map<String, dynamic>;
      expect(params['type'], equals('object'));

      final properties = params['properties'] as Map<String, dynamic>;
      expect(properties, contains('target'));
      expect(properties, contains('backend_url'));
    });

    test('requires target parameter', () {
      final params = patrolRunTool.parameters as Map<String, dynamic>;
      final required = params['required'] as List<dynamic>;
      expect(required, contains('target'));
    });
  });

  group('patrolRunExecutor', () {
    test('returns error for missing target', () async {
      const call = ToolCallInfo(
        id: '1',
        name: 'patrol_run',
        arguments: '{}',
      );

      final result = await patrolRunExecutor(call);
      final json = jsonDecode(result) as Map<String, dynamic>;

      expect(json['error'], contains('Missing required argument'));
      expect(json['allowed_targets'], isList);
    });

    test('returns error for empty arguments', () async {
      const call = ToolCallInfo(id: '2', name: 'patrol_run');

      final result = await patrolRunExecutor(call);
      final json = jsonDecode(result) as Map<String, dynamic>;

      expect(json['error'], contains('Missing required argument'));
    });

    test('returns error for invalid JSON arguments', () async {
      const call = ToolCallInfo(
        id: '3',
        name: 'patrol_run',
        arguments: 'not json',
      );

      final result = await patrolRunExecutor(call);
      final json = jsonDecode(result) as Map<String, dynamic>;

      expect(json['error'], contains('Missing required argument'));
    });

    test('rejects target not in allowlist', () async {
      const call = ToolCallInfo(
        id: '4',
        name: 'patrol_run',
        arguments: '{"target": "malicious_test.dart"}',
      );

      final result = await patrolRunExecutor(call);
      final json = jsonDecode(result) as Map<String, dynamic>;

      expect(json['error'], contains('not in allowlist'));
      expect(json['error'], contains('malicious_test.dart'));
      expect(json['allowed_targets'], isList);
    });

    test('rejects empty target string', () async {
      const call = ToolCallInfo(
        id: '5',
        name: 'patrol_run',
        arguments: '{"target": ""}',
      );

      final result = await patrolRunExecutor(call);
      final json = jsonDecode(result) as Map<String, dynamic>;

      expect(json['error'], contains('Missing required argument'));
    });

    test('rejects path traversal attempt', () async {
      const call = ToolCallInfo(
        id: '6',
        name: 'patrol_run',
        arguments: '{"target": "../../../etc/passwd"}',
      );

      final result = await patrolRunExecutor(call);
      final json = jsonDecode(result) as Map<String, dynamic>;

      expect(json['error'], contains('not in allowlist'));
    });
  });

  group('allowedPatrolTargets', () {
    test('contains expected targets', () {
      expect(allowedPatrolTargets, contains('smoke_test.dart'));
      expect(allowedPatrolTargets, contains('live_chat_test.dart'));
      expect(allowedPatrolTargets, contains('settings_test.dart'));
      expect(allowedPatrolTargets, contains('oidc_test.dart'));
    });

    test('has exactly 4 entries', () {
      expect(allowedPatrolTargets, hasLength(4));
    });
  });

  group('maxOutputChars', () {
    test('is 2000', () {
      expect(maxOutputChars, equals(2000));
    });
  });
}
