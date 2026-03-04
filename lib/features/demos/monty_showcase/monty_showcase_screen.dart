import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soliplex_agent/soliplex_agent.dart'
    show AgentRuntime, FormApi, RuntimeAgentApi;
import 'package:soliplex_client/soliplex_client.dart' show ToolCallInfo;
import 'package:soliplex_dataframe/soliplex_dataframe.dart';
import 'package:soliplex_frontend/core/providers/api_provider.dart';
import 'package:soliplex_frontend/core/providers/flutter_host_api.dart';
import 'package:soliplex_frontend/features/debug/debug_chart_config.dart';
import 'package:soliplex_frontend/features/debug/debug_chart_renderer.dart';
import 'package:soliplex_logging/soliplex_logging.dart';
import 'package:soliplex_scripting/soliplex_scripting.dart';
import 'package:soliplex_showcase/soliplex_showcase.dart';

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class MontyShowcaseScreen extends ConsumerStatefulWidget {
  const MontyShowcaseScreen({super.key});

  @override
  ConsumerState<MontyShowcaseScreen> createState() =>
      _MontyShowcaseScreenState();
}

class _MontyShowcaseScreenState extends ConsumerState<MontyShowcaseScreen> {
  static const _threadKey = (
    serverId: 'local',
    roomId: 'showcase',
    threadId: 'demo',
  );

  late final BridgeCache _bridgeCache;
  late final MontyToolExecutor _executor;
  late final DfRegistry _dfRegistry;
  late final StreamRegistry _streamRegistry;
  final _charts = <int, DebugChartConfig>{};
  final _log = <_LogEntry>[];
  int _selectedDemo = 0;
  int _currentStep = 0;
  bool _isRunning = false;
  bool _autoPlay = false;

  // Drawing canvas state (Demo 10)
  final _drawingGrid = DrawingGrid();
  StreamController<Object?>? _drawingController;

  // Form state (Demo 11)
  final _formApi = _ShowcaseFormApi();
  StreamController<Object?>? _formController;

  // Tic-Tac-Toe state (Demo 12)
  final _tttGrid = TicTacToeGrid();
  StreamController<Object?>? _tttController;

  @override
  void initState() {
    super.initState();
    _bridgeCache = BridgeCache(
      limit: ref.read(platformConstraintsProvider).maxConcurrentBridges,
      defaultLimits: MontyLimitsDefaults.showcase,
    );
    _streamRegistry = StreamRegistry();
    _initExecutor();
  }

  void _initExecutor() {
    final (:hostApi, :dfRegistry) = createFlutterHostBundle(
      onChartCreated: (id, config) {
        setState(() => _charts[id] = config);
      },
      onChartUpdated: (id, config) {
        setState(() => _charts[id] = config);
      },
    );
    _dfRegistry = dfRegistry;

    // Register stream factories.
    _streamRegistry
      ..registerFactory('radar_metrics', radarMetricsStream)
      ..registerFactory('market_share', marketShareStream)
      ..registerFactory('server_metrics', serverMetricsStream);
    _registerUserInputStreams();

    // Create AgentRuntime for ask_llm support.
    final runtime = AgentRuntime(
      bundle: (
        api: ref.read(apiProvider),
        agUiClient: ref.read(agUiClientProvider),
        close: () async {},
      ),
      toolRegistryResolver: (roomId) async => ref.read(toolRegistryProvider),
      platform: ref.read(platformConstraintsProvider),
      logger: LogManager.instance.getLogger('MontyShowcase'),
    );

    _executor = MontyToolExecutor(
      threadKey: _threadKey,
      bridgeCache: _bridgeCache,
      executionTimeout: const Duration(seconds: 60),
      hostWiring: HostFunctionWiring(
        hostApi: hostApi,
        dfRegistry: dfRegistry,
        streamRegistry: _streamRegistry,
        formApi: _formApi,
        agentApi: RuntimeAgentApi(runtime: runtime),
        agentTimeout: const Duration(seconds: 60),
        extraFunctions: [
          HostFunction(
            schema: const HostFunctionSchema(
              name: 'ttt_move',
              description: 'Place a mark on the tic-tac-toe grid.',
              params: [
                HostParam(
                  name: 'cell',
                  type: HostParamType.integer,
                  description: 'Cell index (0-8).',
                ),
                HostParam(
                  name: 'player',
                  type: HostParamType.string,
                  description: 'Player mark: "X" or "O".',
                ),
              ],
            ),
            handler: (args) async {
              final cell = (args['cell']! as num).toInt();
              final player = args['player']! as String;
              _tttGrid.play(cell, player);
              setState(() {});
              return null;
            },
          ),
        ],
      ),
    );
  }

  void _registerUserInputStreams() {
    _drawingController?.close();
    _drawingController = StreamController<Object?>();
    _streamRegistry.registerFactory(
      'drawing_input',
      () => _drawingController!.stream,
    );

    _formController?.close();
    _formController = StreamController<Object?>();
    _streamRegistry.registerFactory(
      'form_submissions',
      () => _formController!.stream,
    );

    _tttController?.close();
    _tttController = StreamController<Object?>();
    _streamRegistry.registerFactory(
      'ttt_input',
      () => _tttController!.stream,
    );
  }

  @override
  void dispose() {
    _dfRegistry.disposeAll();
    _streamRegistry.dispose();
    _drawingController?.close();
    _formController?.close();
    _tttController?.close();
    _bridgeCache.disposeAll();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const demos = ShowcaseDemoRegistry.demos;
    final demo = demos[_selectedDemo];

    return Column(
      children: [
        // Demo selector bar
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          color: theme.colorScheme.surfaceContainerHighest,
          child: Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (var i = 0; i < demos.length; i++)
                      ChoiceChip(
                        label: Text(demos[i].name),
                        selected: i == _selectedDemo,
                        onSelected: _isRunning
                            ? null
                            : (selected) {
                                if (selected) _selectDemo(i);
                              },
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _isRunning ? null : _runAllSteps,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Run All'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _isRunning ? null : _reset,
                icon: const Icon(Icons.refresh),
                label: const Text('Reset'),
              ),
            ],
          ),
        ),
        // Description
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              demo.description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        const Divider(height: 1),
        // Main content
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: Steps + code + interactive widgets
              Expanded(
                flex: 3,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (var i = 0; i < demo.steps.length; i++) ...[
                      _buildStepCard(i, demo.steps[i]),
                      if (i < demo.steps.length - 1) const SizedBox(height: 12),
                    ],
                    // Drawing canvas for Demo 10
                    if (_isDrawingDemo) ...[
                      const SizedBox(height: 16),
                      _buildDrawingCanvas(theme),
                    ],
                    // Form for Demo 11
                    if (_isFormDemo) ...[
                      const SizedBox(height: 16),
                      _buildFormWidget(theme),
                    ],
                    // Tic-Tac-Toe grid for Demo 12
                    if (_isTttDemo) ...[
                      const SizedBox(height: 16),
                      _buildTicTacToeWidget(theme),
                    ],
                  ],
                ),
              ),
              const VerticalDivider(width: 1),
              // Right: Output + charts
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Charts
                    if (_charts.isNotEmpty) ...[
                      SizedBox(
                        height: 220,
                        child: PageView.builder(
                          itemCount: _charts.length,
                          itemBuilder: (_, i) {
                            final config = _charts.values.elementAt(i);
                            return Padding(
                              padding: const EdgeInsets.all(12),
                              child: DebugChartRenderer(
                                config: config,
                              ),
                            );
                          },
                        ),
                      ),
                      Center(
                        child: Text(
                          '${_charts.length} chart(s) — '
                          'swipe to browse',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      const Divider(height: 1),
                    ],
                    // Console output
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Text(
                        'Console Output',
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(
                          12,
                          0,
                          12,
                          12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E1E),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(12),
                          child: SelectableText.rich(
                            TextSpan(
                              children: [
                                for (final entry in _log) _buildLogSpan(entry),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Demo 10 = "Drawing Recognition" (index 9)
  bool get _isDrawingDemo => _selectedDemo == 9;

  // Demo 11 = "Form Validation" (index 10)
  bool get _isFormDemo => _selectedDemo == 10;

  // Demo 12 = "Tic-Tac-Toe" (index 11)
  bool get _isTttDemo => _selectedDemo == 11;

  Widget _buildDrawingCanvas(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Drawing Canvas (20x20)',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            AspectRatio(
              aspectRatio: 1,
              child: LayoutBuilder(
                builder: (context, constraints) => GestureDetector(
                  onPanUpdate: (details) {
                    final local = details.localPosition;
                    final col =
                        (local.dx / constraints.maxWidth * DrawingGrid.size)
                            .floor();
                    final row =
                        (local.dy / constraints.maxHeight * DrawingGrid.size)
                            .floor();
                    _drawingGrid.setCell(row, col);
                    setState(() {});
                  },
                  child: CustomPaint(
                    painter: _DrawingGridPainter(
                      grid: _drawingGrid,
                      color: theme.colorScheme.primary,
                    ),
                    size: Size.infinite,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                FilledButton(
                  onPressed: () {
                    _drawingController?.add(
                      _drawingGrid.toAscii(),
                    );
                  },
                  child: const Text('Submit Drawing'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () {
                    _drawingGrid.clear();
                    setState(() {});
                  },
                  child: const Text('Clear'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormWidget(ThemeData theme) {
    final fields = _formApi.currentFields;
    final errors = _formApi.currentErrors;
    if (fields.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Run the demo to create a form.',
            style: theme.textTheme.bodyMedium,
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dynamic Form',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            for (final field in fields) ...[
              TextField(
                decoration: InputDecoration(
                  labelText:
                      field['label'] as String? ?? field['name'] as String?,
                  errorText: errors[field['name'] as String?],
                ),
                onChanged: (value) {
                  final name = field['name'] as String?;
                  if (name != null) {
                    _formApi.formData[name] = value;
                  }
                },
              ),
              const SizedBox(height: 8),
            ],
            FilledButton(
              onPressed: () {
                _formController?.add(
                  Map<String, Object?>.from(_formApi.formData),
                );
              },
              child: const Text('Submit Form'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTicTacToeWidget(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tic-Tac-Toe (tap a cell to play X)',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 200,
              height: 200,
              child: GridView.count(
                crossAxisCount: 3,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (var i = 0; i < 9; i++)
                    InkWell(
                      onTap: () {
                        if (_tttGrid.getCell(i) == '') {
                          _tttGrid.play(i, 'X');
                          _tttController?.add(i);
                          setState(() {});
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _tttGrid.getCell(i),
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: _tttGrid.getCell(i) == 'X'
                                ? theme.colorScheme.primary
                                : theme.colorScheme.error,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () {
                _tttGrid.reset();
                _registerUserInputStreams();
                setState(() {});
              },
              child: const Text('New Game'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepCard(int index, ShowcaseDemoStep step) {
    final theme = Theme.of(context);
    final isDone = _stepResults.containsKey(index);
    final isActive = index == _currentStep && _isRunning;
    final result = _stepResults[index];

    return Card(
      elevation: isActive ? 4 : 1,
      color: isActive
          ? theme.colorScheme.primaryContainer
          : isDone
              ? ((result?.isError ?? false)
                  ? theme.colorScheme.errorContainer.withValues(alpha: 0.3)
                  : theme.colorScheme.surfaceContainerLow)
              : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (isActive)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                else if (isDone && !(result?.isError ?? false))
                  const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 18,
                  )
                else if (isDone && (result?.isError ?? false))
                  const Icon(
                    Icons.error,
                    color: Colors.orange,
                    size: 18,
                  )
                else
                  Icon(
                    Icons.circle_outlined,
                    color: theme.colorScheme.outline,
                    size: 18,
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    step.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (!_isRunning && !isDone)
                  TextButton(
                    onPressed: () => _runStep(index),
                    child: const Text('Run'),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              step.narration,
              style: theme.textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(6),
              ),
              child: SelectableText(
                step.code.trim(),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: Color(0xFFD4D4D4),
                  height: 1.4,
                ),
              ),
            ),
            if (!_isRunning && !isDone) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: () => _runStep(index),
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: const Text('Run'),
                ),
              ),
            ],
            if (result != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: result.isError
                      ? Colors.red.shade50
                      : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: result.isError
                        ? Colors.red.shade200
                        : Colors.green.shade200,
                  ),
                ),
                child: SelectableText(
                  result.isError ? 'Error: ${result.output}' : result.output,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: result.isError
                        ? Colors.red.shade900
                        : Colors.green.shade900,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  TextSpan _buildLogSpan(_LogEntry entry) {
    final color = switch (entry.kind) {
      _LogKind.narration => const Color(0xFF6A9955),
      _LogKind.code => const Color(0xFF569CD6),
      _LogKind.output => const Color(0xFFD4D4D4),
      _LogKind.error => const Color(0xFFF44747),
      _LogKind.system => const Color(0xFF808080),
    };
    final prefix = switch (entry.kind) {
      _LogKind.narration => '# ',
      _LogKind.code => '> ',
      _LogKind.output => '  ',
      _LogKind.error => '! ',
      _LogKind.system => '~ ',
    };

    return TextSpan(
      text: '$prefix${entry.text}\n',
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: 11,
        color: color,
        height: 1.4,
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Execution
  // -----------------------------------------------------------------------

  final _stepResults = <int, _StepResult>{};

  void _selectDemo(int index) {
    setState(() {
      _selectedDemo = index;
      _currentStep = 0;
      _stepResults.clear();
      _log.clear();
      _charts.clear();
      _formApi.reset();
      _drawingGrid.clear();
      _tttGrid.reset();
    });
    _dfRegistry.disposeAll();
    _registerUserInputStreams();
  }

  void _reset() {
    setState(() {
      _currentStep = 0;
      _stepResults.clear();
      _log.clear();
      _charts.clear();
      _formApi.reset();
      _drawingGrid.clear();
      _tttGrid.reset();
    });
    _dfRegistry.disposeAll();
    _registerUserInputStreams();
  }

  Future<void> _runAllSteps() async {
    _reset();
    setState(() {
      _autoPlay = true;
      _isRunning = true;
    });
    final steps = ShowcaseDemoRegistry.demos[_selectedDemo].steps;
    for (var i = 0; i < steps.length; i++) {
      if (!mounted) return;
      await _runStep(i);
      if (i < steps.length - 1) {
        await Future<void>.delayed(
          const Duration(milliseconds: 800),
        );
      }
    }
    setState(() {
      _isRunning = false;
      _autoPlay = false;
    });
  }

  Future<void> _runStep(int index) async {
    final steps = ShowcaseDemoRegistry.demos[_selectedDemo].steps;
    final step = steps[index];

    setState(() {
      _currentStep = index;
      if (!_autoPlay) _isRunning = true;
    });

    _addLog(step.narration, _LogKind.narration);
    _addLog('Executing Python...', _LogKind.system);

    try {
      final toolCall = ToolCallInfo(
        id: 'demo-${DateTime.now().millisecondsSinceEpoch}',
        name: PythonExecutorTool.toolName,
        arguments: jsonEncode({'code': step.code.trim()}),
      );
      final output = await _executor.execute(toolCall);

      if (step.expectsError) {
        _addLog(output, _LogKind.output);
        setState(() {
          _stepResults[index] = _StepResult(output);
        });
      } else {
        _addLog(
          output.isEmpty ? '(no output)' : output,
          _LogKind.output,
        );
        setState(() {
          _stepResults[index] = _StepResult(
            output.isEmpty ? '(completed successfully)' : output,
          );
        });
      }
    } on Object catch (e) {
      final msg = '$e';
      _addLog(msg, _LogKind.error);
      setState(() {
        _stepResults[index] = _StepResult(
          msg,
          isError: step.expectsError,
        );
      });
      if (step.expectsError) {
        _addLog(
          '(Expected error — the next step will fix it)',
          _LogKind.system,
        );
      }
    }

    if (!_autoPlay) {
      setState(() => _isRunning = false);
    }
  }

  void _addLog(String text, _LogKind kind) {
    setState(() => _log.add(_LogEntry(text, kind)));
  }
}

// ---------------------------------------------------------------------------
// Drawing grid painter
// ---------------------------------------------------------------------------

class _DrawingGridPainter extends CustomPainter {
  _DrawingGridPainter({required this.grid, required this.color});

  final DrawingGrid grid;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final cellW = size.width / DrawingGrid.size;
    final cellH = size.height / DrawingGrid.size;
    final fillPaint = Paint()..color = color;
    final gridPaint = Paint()
      ..color = color.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    for (var r = 0; r < DrawingGrid.size; r++) {
      for (var c = 0; c < DrawingGrid.size; c++) {
        final rect = Rect.fromLTWH(
          c * cellW,
          r * cellH,
          cellW,
          cellH,
        );
        canvas.drawRect(rect, gridPaint);
        if (grid.getCell(r, c)) {
          canvas.drawRect(rect, fillPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_DrawingGridPainter old) => true;
}

// ---------------------------------------------------------------------------
// Showcase FormApi implementation
// ---------------------------------------------------------------------------

class _ShowcaseFormApi implements FormApi {
  final forms = <int, List<Map<String, Object?>>>{};
  final errors = <int, Map<String, String>>{};
  final formData = <String, Object?>{};
  int _nextId = 1;

  List<Map<String, Object?>> get currentFields {
    if (forms.isEmpty) return [];
    return forms.values.last;
  }

  Map<String, String> get currentErrors {
    if (errors.isEmpty) return {};
    return errors.values.last;
  }

  void reset() {
    forms.clear();
    errors.clear();
    formData.clear();
    _nextId = 1;
  }

  @override
  int createForm(List<Map<String, Object?>> fields) {
    final id = _nextId++;
    forms[id] = fields;
    return id;
  }

  @override
  bool setFormErrors(int handle, Map<String, String> fieldErrors) {
    if (!forms.containsKey(handle)) return false;
    errors[handle] = fieldErrors;
    return true;
  }
}

// ---------------------------------------------------------------------------
// Data classes
// ---------------------------------------------------------------------------

class _StepResult {
  const _StepResult(this.output, {this.isError = false});
  final String output;
  final bool isError;
}

class _LogEntry {
  const _LogEntry(this.text, this.kind);
  final String text;
  final _LogKind kind;
}

enum _LogKind { narration, code, output, error, system }
