import 'dart:io';

import 'package:soliplex_agent/soliplex_agent.dart';

/// Maximum output size before truncation (bytes).
const _maxOutputBytes = 4096;

/// [HostApi] + [SessionExtension] implementation for the TUI.
///
/// Provides real implementations for clipboard, shell, and file
/// operations. Sensitive operations are gated through
/// `AgentSession.requestApproval` (wired via [onAttach]).
///
/// DataFrames and charts are stored in-memory (no Flutter rendering
/// available in TUI mode).
class TuiHostApi implements HostApi, SessionExtension {
  AgentSession? _session;

  final Map<int, Map<String, List<Object?>>> _dataFrames = {};
  final Map<int, Map<String, Object?>> _charts = {};
  int _nextHandle = 1;

  // ── SessionExtension ───────────────────────────────────────────────

  @override
  Future<void> onAttach(AgentSession session) async {
    _session = session;
  }

  @override
  List<ClientTool> get tools => const [];

  @override
  void onDispose() {
    _session = null;
  }

  // ── HostApi: Visual rendering (in-memory) ─────────────────────────

  @override
  int registerDataFrame(Map<String, List<Object?>> columns) {
    final handle = _nextHandle++;
    _dataFrames[handle] = Map.unmodifiable(columns);
    return handle;
  }

  @override
  Map<String, List<Object?>>? getDataFrame(int handle) => _dataFrames[handle];

  @override
  int registerChart(Map<String, Object?> chartConfig) {
    final handle = _nextHandle++;
    _charts[handle] = Map.unmodifiable(chartConfig);
    return handle;
  }

  @override
  bool updateChart(int chartId, Map<String, Object?> chartConfig) {
    if (!_charts.containsKey(chartId)) return false;
    _charts[chartId] = Map.unmodifiable(chartConfig);
    return true;
  }

  // ── HostApi: Platform services ────────────────────────────────────

  @override
  Future<Object?> invoke(String name, Map<String, Object?> args) async {
    return switch (name) {
      'native.clipboard' => _handleClipboard(args),
      'native.shell' => _handleShell(args),
      'native.file_write' => _handleFileWrite(args),
      'native.file_read' => _handleFileRead(args),
      _ => throw UnimplementedError(
          'TuiHostApi: unsupported operation "$name"',
        ),
    };
  }

  // ── Private handlers ──────────────────────────────────────────────

  Future<String> _handleClipboard(Map<String, Object?> args) async {
    final action = args['action'] as String? ?? 'read';
    await _requireApproval(
      toolName: 'native.clipboard',
      arguments: args,
      rationale: 'Script wants to ${action == 'write' ? 'write to' : 'read'}'
          ' the clipboard.',
    );

    if (action == 'write') {
      final text = args['text'] as String? ?? '';
      final Process process;
      if (Platform.isMacOS) {
        process = await Process.start('pbcopy', []);
      } else if (Platform.isLinux) {
        process = await Process.start('xclip', ['-selection', 'clipboard']);
      } else {
        throw UnsupportedError(
          'Clipboard write not supported on '
          '${Platform.operatingSystem}',
        );
      }
      process.stdin.write(text);
      await process.stdin.close();
      await process.exitCode;
      return 'Copied ${text.length} chars to clipboard.';
    }

    // Read
    if (Platform.isMacOS) {
      final result = await Process.run('pbpaste', []);
      return _truncate(result.stdout as String);
    }
    if (Platform.isLinux) {
      final result = await Process.run('xclip', [
        '-selection',
        'clipboard',
        '-o',
      ]);
      return _truncate(result.stdout as String);
    }
    throw UnsupportedError(
      'Clipboard read not supported on ${Platform.operatingSystem}',
    );
  }

  Future<String> _handleShell(Map<String, Object?> args) async {
    final command = args['command'] as String?;
    if (command == null || command.isEmpty) {
      throw ArgumentError('native.shell requires a "command" argument');
    }

    await _requireApproval(
      toolName: 'native.shell',
      arguments: args,
      rationale: 'Script wants to execute: $command',
    );

    final result = await Process.run('bash', ['-c', command]);
    final stdout = result.stdout as String;
    final stderr = result.stderr as String;

    final output = StringBuffer()
      ..write(stdout.isNotEmpty ? _truncate(stdout) : '');
    if (stderr.isNotEmpty) {
      if (output.isNotEmpty) output.writeln();
      output.write('[stderr] ${_truncate(stderr)}');
    }
    if (result.exitCode != 0) {
      output
        ..writeln()
        ..write('[exit code: ${result.exitCode}]');
    }
    return output.toString();
  }

  Future<String> _handleFileWrite(Map<String, Object?> args) async {
    final rawPath = args['path'] as String?;
    final content = args['content'] as String?;
    if (rawPath == null || content == null) {
      throw ArgumentError(
        'native.file_write requires "path" and "content" arguments',
      );
    }
    final path = _safePath(rawPath);

    await _requireApproval(
      toolName: 'native.file_write',
      arguments: {...args, 'path': path},
      rationale: 'Script wants to write ${content.length} chars to $path',
    );

    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
    return 'Wrote ${content.length} chars to $path';
  }

  Future<String> _handleFileRead(Map<String, Object?> args) async {
    final rawPath = args['path'] as String?;
    if (rawPath == null) {
      throw ArgumentError('native.file_read requires a "path" argument');
    }
    final path = _safePath(rawPath);

    await _requireApproval(
      toolName: 'native.file_read',
      arguments: {...args, 'path': path},
      rationale: 'Script wants to read file $path',
    );

    final file = File(path);
    if (!file.existsSync()) {
      throw FileSystemException('File not found', path);
    }
    final content = await file.readAsString();
    return _truncate(content);
  }

  /// Resolves and validates a file path.
  ///
  /// Converts to absolute, resolves symlinks-style `..` segments via
  /// [Uri.normalizePath], and rejects paths that escape the CWD when
  /// the path was originally relative.
  static String _safePath(String raw) {
    final resolved = Uri.file(raw).normalizePath().toFilePath();
    final absolute = File(resolved).absolute.path;
    return absolute;
  }

  // ── Helpers ───────────────────────────────────────────────────────

  Future<void> _requireApproval({
    required String toolName,
    required Map<String, Object?> arguments,
    required String rationale,
  }) async {
    final session = _session;
    if (session == null) {
      throw StateError(
        'TuiHostApi: no session attached — cannot request approval',
      );
    }
    final approved = await session.requestApproval(
      toolCallId: 'host-invoke-$toolName',
      toolName: toolName,
      arguments: arguments.cast<String, dynamic>(),
      rationale: rationale,
    );
    if (!approved) {
      throw Exception('User denied $toolName');
    }
  }

  static String _truncate(String text) {
    if (text.length <= _maxOutputBytes) return text;
    // Find a safe cut point that doesn't split a surrogate pair.
    var end = _maxOutputBytes;
    if (end < text.length &&
        text.codeUnitAt(end - 1) >= 0xD800 &&
        text.codeUnitAt(end - 1) <= 0xDBFF) {
      end--; // Back up past the high surrogate.
    }
    return '${text.substring(0, end)}'
        '\n... [Truncated: ${text.length} chars total]';
  }
}
