#!/usr/bin/env dart

/// Sets up git pre-commit hooks for the project.
///
/// Run with: dart run tool/setup_hooks.dart
library;

import 'dart:io';

void main() {
  const hookScript = r'''
#!/bin/sh
# Pre-commit hook - runs dart_pre_commit
# Installed by: dart run tool/setup_hooks.dart

exec dart run tool/pre_commit.dart "$@"
''';

  final hookFile = File('.git/hooks/pre-commit');

  // Check we're in a git repo
  if (!Directory('.git').existsSync()) {
    stderr.writeln('Error: Not in a git repository root');
    exit(1);
  }

  // Write the hook
  hookFile.writeAsStringSync(hookScript);

  // Make executable
  Process.runSync('chmod', ['+x', hookFile.path]);

  stdout
    ..writeln('✓ Pre-commit hook installed at ${hookFile.path}')
    ..writeln()
    ..writeln('The hook will run on staged files:')
    ..writeln('  - dart format (auto-fixes and re-stages)')
    ..writeln('  - dart analyze (fails on errors/warnings)')
    ..writeln()
    ..writeln('To skip hooks temporarily: git commit --no-verify');
}
