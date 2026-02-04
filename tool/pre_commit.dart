#!/usr/bin/env dart

/// Pre-commit hook script using dart_pre_commit.
///
/// To install:
///   dart run tool/setup_hooks.dart
///
/// Configuration is in pubspec.yaml under `dart_pre_commit` key.
library;

import 'dart:io';

import 'package:dart_pre_commit/dart_pre_commit.dart';

Future<void> main() async {
  final result = await DartPreCommit.run();
  exit(result.isSuccess ? 0 : 1);
}
