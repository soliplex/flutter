// TEMPORARY: Debug DataFrame REPL — remove after validation.
// Cleanup: delete this file when no longer needed.

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soliplex_agent/soliplex_agent.dart' show HostApi;
import 'package:soliplex_client/soliplex_client.dart' show ToolCallInfo;
import 'package:soliplex_dataframe/soliplex_dataframe.dart';
import 'package:soliplex_frontend/core/providers/api_provider.dart';
import 'package:soliplex_frontend/core/providers/flutter_host_api.dart';
import 'package:soliplex_frontend/features/debug/debug_chart_config.dart';
import 'package:soliplex_frontend/features/debug/debug_chart_renderer.dart';
import 'package:soliplex_scripting/soliplex_scripting.dart';

/// REPL-style debug screen for testing DataFrame operations directly.
///
/// Executes df_* host functions backed by a shared [DfRegistry], and
/// supports `py <code>` for full Monty bridge execution.
class DebugDataFrameScreen extends ConsumerStatefulWidget {
  const DebugDataFrameScreen({super.key});

  @override
  ConsumerState<DebugDataFrameScreen> createState() =>
      _DebugDataFrameScreenState();
}

class _DebugDataFrameScreenState extends ConsumerState<DebugDataFrameScreen> {
  final _inputController = TextEditingController();
  final _outputLines = <_OutputLine>[];
  final _scrollController = ScrollController();
  final _charts = <DebugChartConfig>[];
  int _currentChartIndex = 0;

  static const _threadKey = (
    serverId: 'local',
    roomId: 'debug',
    threadId: 'repl',
  );

  late final DfRegistry _registry;
  late final HostApi _hostApi;
  late final MontyToolExecutor _executor;
  late final Map<String, _DfCommand> _commands;

  @override
  void initState() {
    super.initState();
    final (:hostApi, :dfRegistry) = createFlutterHostBundle(
      onChartCreated: (id, config) {
        setState(() {
          _charts.add(config);
          _currentChartIndex = _charts.length - 1;
        });
      },
    );
    _hostApi = hostApi;
    _registry = dfRegistry;
    _executor = MontyToolExecutor(
      threadKey: _threadKey,
      bridgeCache: ref.read(bridgeCacheProvider),
      hostWiring: HostFunctionWiring(
        hostApi: hostApi,
        dfRegistry: dfRegistry,
      ),
    );
    _commands = _buildCommands();
    _addOutput(
      'DataFrame REPL ready. Type "help" for commands, '
      '"py <code>" for Python.',
      _Kind.info,
    );
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _registry.disposeAll();
    ref.read(bridgeCacheProvider).evict(_threadKey);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          color: Colors.amber.shade100,
          child: const Text(
            '\u26A0 TEMPORARY SCAFFOLDING '
            '\u2014 remove after validation',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        if (_charts.isNotEmpty) _buildChartPanel(),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(8),
            itemCount: _outputLines.length,
            itemBuilder: (_, i) => _buildLine(_outputLines[i]),
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              const Text(
                '\u276F ',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _inputController,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'df_create, chart_line, py <code>, help ...',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  ),
                  onSubmitted: (_) => _execute(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: _execute,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Clear output',
                onPressed: () => setState(_outputLines.clear),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChartPanel() {
    final chart = _charts[_currentChartIndex];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 250,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: DebugChartRenderer(config: chart),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _currentChartIndex > 0
                    ? () => setState(() => _currentChartIndex--)
                    : null,
              ),
              Text(
                '${chart.title}  '
                '(${_currentChartIndex + 1}/${_charts.length})',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _currentChartIndex < _charts.length - 1
                    ? () => setState(() => _currentChartIndex++)
                    : null,
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                tooltip: 'Clear charts',
                onPressed: () => setState(() {
                  _charts.clear();
                  _currentChartIndex = 0;
                }),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }

  Widget _buildLine(_OutputLine line) {
    final (color, prefix) = switch (line.kind) {
      _Kind.input => (Colors.blue.shade700, '\u276F '),
      _Kind.result => (Colors.green.shade800, '  '),
      _Kind.error => (Colors.red.shade700, '! '),
      _Kind.info => (Colors.grey.shade600, '# '),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: SelectableText(
        '$prefix${line.text}',
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          color: color,
        ),
      ),
    );
  }

  void _addOutput(String text, _Kind kind) {
    setState(() => _outputLines.add(_OutputLine(text, kind)));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _execute() async {
    final input = _inputController.text.trim();
    if (input.isEmpty) return;
    _inputController.clear();
    _addOutput(input, _Kind.input);

    if (input == 'help') {
      _showHelp();
      return;
    }

    // py <code> — execute Python via Monty bridge
    if (input.startsWith('py ')) {
      final code = input.substring(3).trim();
      if (code.isEmpty) {
        _addOutput('Usage: py <python code>', _Kind.error);
        return;
      }
      try {
        final result = await _executePython(code);
        if (result.isNotEmpty) _addOutput(result, _Kind.result);
      } on Object catch (e) {
        _addOutput('$e', _Kind.error);
      }
      return;
    }

    // Parse: command_name arg1 arg2 ...  OR  command_name(json_args)
    final parenMatch = RegExp(r'^(\w+)\((.+)\)$').firstMatch(input);
    final spaceMatch = RegExp(r'^(\w+)\s*(.*)$').firstMatch(input);

    final String name;
    final String rawArgs;
    if (parenMatch != null) {
      name = parenMatch.group(1)!;
      rawArgs = parenMatch.group(2)!;
    } else if (spaceMatch != null) {
      name = spaceMatch.group(1)!;
      rawArgs = spaceMatch.group(2)!;
    } else {
      _addOutput('Could not parse command. Type "help".', _Kind.error);
      return;
    }

    final cmd = _commands[name];
    if (cmd == null) {
      _addOutput('Unknown command: $name. Type "help".', _Kind.error);
      return;
    }

    try {
      final result = await cmd.execute(rawArgs);
      _addOutput(result, _Kind.result);
    } on Object catch (e) {
      _addOutput('$e', _Kind.error);
    }
  }

  /// Executes Python code via `MontyToolExecutor`.
  ///
  /// Uses the per-session `_hostApi` and `_registry` so DataFrame handles
  /// persist across `py` commands.
  Future<String> _executePython(String code) async {
    final toolCall = ToolCallInfo(
      id: 'repl-${DateTime.now().millisecondsSinceEpoch}',
      name: PythonExecutorTool.toolName,
      arguments: jsonEncode({'code': code}),
    );
    return _executor.execute(toolCall);
  }

  void _showHelp() {
    final buf = StringBuffer('Available commands:\n');
    for (final entry in _commands.entries) {
      buf.writeln('  ${entry.key.padRight(20)} ${entry.value.help}');
    }
    buf
      ..writeln('\nChart commands:')
      ..writeln('  chart_line(handle, x_col, y_col)')
      ..writeln('  chart_bar(handle, label_col, value_col)')
      ..writeln('  chart_scatter(handle, x_col, y_col)')
      ..writeln('\nPython execution:')
      ..writeln('  py <python code>');
    _writeExamples(buf);
    _addOutput(buf.toString(), _Kind.info);
  }

  void _writeExamples(StringBuffer buf) {
    const lineData = '  df_create([{"x":1,"y":2},'
        ' {"x":2,"y":4},{"x":3,"y":1},{"x":4,"y":5}])';
    const barData = '  df_create([{"fruit":"apple","count":12},'
        ' {"fruit":"banana","count":7},'
        ' {"fruit":"cherry","count":19}])';
    const scatterData = '  df_create([{"temp":20,"sales":100},'
        ' {"temp":25,"sales":130},'
        ' {"temp":30,"sales":180},'
        ' {"temp":35,"sales":160}])';
    const createData = '  df_create([{"name":"Alice","age":30},'
        ' {"name":"Bob","age":25}])';
    const filterData = '  df_filter({"handle":1,'
        ' "column":"age","op":">","value":28})';

    buf
      ..writeln('\nQuick start — line chart:')
      ..writeln(lineData)
      ..writeln('  chart_line(1, x, y)')
      ..writeln('\nQuick start — bar chart:')
      ..writeln(barData)
      ..writeln('  chart_bar(2, fruit, count)')
      ..writeln('\nQuick start — scatter chart:')
      ..writeln(scatterData)
      ..writeln('  chart_scatter(3, temp, sales)')
      ..writeln('\nDataFrame examples:')
      ..writeln(createData)
      ..writeln('  df_head 1')
      ..writeln('  df_shape 1')
      ..writeln('  df_columns 1')
      ..writeln(filterData)
      ..writeln(r'  df_from_csv name,age\nAlice,30\nBob,25')
      ..writeln('\nPython example:')
      ..writeln('  py h = df_create([{"a":1},{"a":2}])');
  }

  Map<String, _DfCommand> _buildCommands() {
    final fns = buildDfFunctions(_registry);
    final byName = {for (final f in fns) f.schema.name: f};
    final cmds = <String, _DfCommand>{};

    for (final entry in byName.entries) {
      final schema = entry.value.schema;
      final handler = entry.value.handler;
      final paramDesc = schema.params.map((p) => p.name).join(', ');
      cmds[entry.key] = _DfCommand(
        help: '($paramDesc) ${schema.description}',
        execute: (rawArgs) async {
          // Try JSON object parse first
          Map<String, Object?> args;
          if (rawArgs.startsWith('{')) {
            args = Map<String, Object?>.from(
              jsonDecode(rawArgs) as Map,
            );
          } else if (rawArgs.isEmpty) {
            args = {};
          } else {
            // Single-arg shorthand: first param gets the parsed value
            if (schema.params.isEmpty) {
              args = {};
            } else {
              final firstParam = schema.params.first;
              args = {firstParam.name: _parseSimpleArg(rawArgs)};
            }
          }

          final result = await handler(args);
          return _formatResult(result);
        },
      );
    }

    // Chart commands — go through HostApi so callback fires
    cmds['chart_line'] = _DfCommand(
      help: '(handle, x_col, y_col) Render a line chart',
      execute: (rawArgs) async => _executeChartCommand(rawArgs, 'line'),
    );
    cmds['chart_bar'] = _DfCommand(
      help: '(handle, label_col, value_col) Render a bar chart',
      execute: (rawArgs) async => _executeChartCommand(rawArgs, 'bar'),
    );
    cmds['chart_scatter'] = _DfCommand(
      help: '(handle, x_col, y_col) Render a scatter chart',
      execute: (rawArgs) async => _executeChartCommand(rawArgs, 'scatter'),
    );

    return cmds;
  }

  /// Builds a chart config map and registers it through `_hostApi` so the
  /// `onChartCreated` callback fires (same path as Python `chart_create`).
  String _executeChartCommand(String rawArgs, String type) {
    final parts = rawArgs.split(',').map((s) => s.trim()).toList();
    if (parts.length < 3) {
      throw ArgumentError('Expected: handle, column1, column2');
    }

    final handle = int.parse(parts[0]);
    final col1 = parts[1];
    final col2 = parts[2];

    final df = _registry.get(handle);
    final col1Values = df.columnValues(col1);
    final col2Values = df.columnValues(col2);

    final Map<String, Object?> config;
    switch (type) {
      case 'line' || 'scatter':
        config = {
          'type': type,
          'title': '${type[0].toUpperCase()}${type.substring(1)}: '
              '$col1 vs $col2',
          'x_label': col1,
          'y_label': col2,
          'points': _extractPointsList(col1Values, col2Values),
        };
      case 'bar':
        config = {
          'type': 'bar',
          'title': 'Bar: $col1 vs $col2',
          'x_label': col1,
          'y_label': col2,
          'labels': col1Values.map((v) => '$v').toList(),
          'values':
              col2Values.map((v) => v is num ? v.toDouble() : 0.0).toList(),
        };
      default:
        throw ArgumentError('Unknown chart type: $type');
    }

    final id = _hostApi.registerChart(config);
    return 'Chart #$id added ($type)';
  }

  List<List<double>> _extractPointsList(
    List<Object?> xValues,
    List<Object?> yValues,
  ) {
    final points = <List<double>>[];
    for (var i = 0; i < math.min(xValues.length, yValues.length); i++) {
      final x = _toDouble(xValues[i]);
      final y = _toDouble(yValues[i]);
      if (x != null && y != null) points.add([x, y]);
    }
    return points;
  }

  double? _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  Object? _parseSimpleArg(String raw) {
    final trimmed = raw.trim();
    final asInt = int.tryParse(trimmed);
    if (asInt != null) return asInt;
    final asDouble = double.tryParse(trimmed);
    if (asDouble != null) return asDouble;
    if (trimmed == 'true') return true;
    if (trimmed == 'false') return false;
    if (trimmed == 'null') return null;
    // Try JSON parse
    try {
      return jsonDecode(trimmed);
    } on FormatException {
      return trimmed;
    }
  }

  String _formatResult(Object? result) {
    if (result == null) return '(null)';
    if (result is List) {
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(result);
    }
    if (result is Map) {
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(result);
    }
    return '$result';
  }
}

enum _Kind { input, result, error, info }

class _OutputLine {
  const _OutputLine(this.text, this.kind);
  final String text;
  final _Kind kind;
}

class _DfCommand {
  const _DfCommand({required this.help, required this.execute});
  final String help;
  final Future<String> Function(String rawArgs) execute;
}
