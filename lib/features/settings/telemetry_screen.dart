import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soliplex_frontend/core/logging/loggers.dart';
import 'package:soliplex_frontend/core/logging/logging_provider.dart';

/// Telemetry settings screen for enabling/disabling backend log shipping.
class TelemetryScreen extends ConsumerWidget {
  const TelemetryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(logConfigProvider);
    final connectivity = ref.watch(connectivityProvider);

    return ListView(
      children: [
        SwitchListTile(
          secondary: const Icon(Icons.cloud_upload_outlined),
          title: const Text('Backend Logging'),
          subtitle: const Text('Ship logs to the backend for analysis'),
          value: config.backendLoggingEnabled,
          onChanged: (value) => ref
              .read(logConfigProvider.notifier)
              .setBackendLoggingEnabled(enabled: value),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.link),
          title: const Text('Endpoint'),
          subtitle: SelectableText(config.backendEndpoint),
          trailing: kReleaseMode
              ? null
              : IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () =>
                      _showEndpointDialog(context, ref, config.backendEndpoint),
                ),
        ),
        ListTile(
          leading: Icon(
            _connectivityIcon(connectivity),
            color: _connectivityColor(context, connectivity),
          ),
          title: const Text('Connection Status'),
          subtitle: Text(_connectivityLabel(connectivity)),
        ),
        if (!kReleaseMode) ...[
          const Divider(),
          ListTile(
            leading: const Icon(Icons.bug_report, color: Colors.orange),
            title: const Text('Test Exception'),
            subtitle: const Text('Log an error with stack trace'),
            trailing: FilledButton.tonal(
              onPressed: () => _fireTestException(context),
              child: const Text('Fire'),
            ),
          ),
        ],
      ],
    );
  }

  IconData _connectivityIcon(AsyncValue<List<ConnectivityResult>> state) {
    return state.when(
      data: (results) => results.contains(ConnectivityResult.none)
          ? Icons.cloud_off
          : Icons.cloud_done,
      loading: () => Icons.cloud_queue,
      error: (_, __) => Icons.cloud_off,
    );
  }

  Color _connectivityColor(
    BuildContext context,
    AsyncValue<List<ConnectivityResult>> state,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return state.when(
      data: (results) => results.contains(ConnectivityResult.none)
          ? colorScheme.error
          : colorScheme.primary,
      loading: () => colorScheme.outline,
      error: (_, __) => colorScheme.error,
    );
  }

  String _connectivityLabel(AsyncValue<List<ConnectivityResult>> state) {
    return state.when(
      data: (results) {
        if (results.contains(ConnectivityResult.none)) return 'No connection';
        return results.map((r) => r.name).join(', ');
      },
      loading: () => 'Checking...',
      error: (_, __) => 'Unknown',
    );
  }

  void _fireTestException(BuildContext context) {
    try {
      throw Exception('Test exception from Telemetry screen');
    } on Exception catch (e, s) {
      Loggers.telemetry.error(
        'Test exception fired',
        error: e,
        stackTrace: s,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error logged — check Logfire')),
      );
    }
  }

  Future<void> _showEndpointDialog(
    BuildContext context,
    WidgetRef ref,
    String currentEndpoint,
  ) async {
    final controller = TextEditingController(text: currentEndpoint);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Backend Endpoint'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Endpoint path',
            hintText: '/api/v1/logs',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && context.mounted) {
      await ref.read(logConfigProvider.notifier).setBackendEndpoint(result);
    }
  }
}
