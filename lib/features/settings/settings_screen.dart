import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:soliplex_frontend/core/auth/auth_provider.dart';
import 'package:soliplex_frontend/core/auth/auth_state.dart';
import 'package:soliplex_frontend/core/logging/loggers.dart';
import 'package:soliplex_frontend/core/logging/logging_provider.dart';
import 'package:soliplex_frontend/core/providers/backend_version_provider.dart';
import 'package:soliplex_frontend/core/providers/config_provider.dart';
import 'package:soliplex_frontend/core/providers/http_log_provider.dart';
import 'package:soliplex_frontend/design/color/color_scheme_extensions.dart';
import 'package:soliplex_frontend/design/design.dart';
import 'package:soliplex_frontend/version.dart';
import 'package:soliplex_logging/soliplex_logging.dart';

/// Settings screen for app configuration.
///
/// Returns body content only; AppShell wrapper is provided by the router.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(configProvider);
    final authState = ref.watch(authProvider);
    final backendVersion = ref.watch(backendVersionInfoProvider);

    return ListView(
      children: [
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text('Frontend Version'),
          subtitle: const SelectableText(soliplexVersion),
          trailing: IconButton(
            icon: const Icon(Icons.copy),
            onPressed: () => Clipboard.setData(
              const ClipboardData(text: soliplexVersion),
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.dns),
          title: const Text('Backend URL'),
          subtitle: SelectableText(config.baseUrl),
          trailing: IconButton(
            icon: const Icon(Icons.copy),
            onPressed: () =>
                Clipboard.setData(ClipboardData(text: config.baseUrl)),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.cloud_outlined),
          title: const Text('Backend Version'),
          subtitle: backendVersion.when(
            data: (info) => SelectableText(info.soliplexVersion),
            loading: () => const Text('Loading...'),
            error: (error, stack) {
              Loggers.config.error(
                'Failed to load backend version',
                error: error,
                stackTrace: stack,
              );
              return const Text('Unavailable');
            },
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            spacing: SoliplexSpacing.s2,
            children: [
              TextButton(
                onPressed: () => context.push('/settings/backend-versions'),
                child: const Text('View All'),
              ),
              IconButton(
                icon: const Icon(Icons.copy),
                onPressed: () => Clipboard.setData(
                  ClipboardData(
                    text: backendVersion.maybeWhen(
                      data: (info) => info.soliplexVersion,
                      orElse: () => 'Unavailable',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(),
        const _NetworkRequestsTile(),
        const _LogViewerTile(),
        const _TelemetryTile(),
        const Divider(),
        // --- TEMPORARY: Debug agent screen — remove after F1 validation ---
        ListTile(
          leading: const Icon(Icons.bug_report),
          title: const Text('Debug Agent Run'),
          subtitle: const Text('TEMPORARY — F1 validation'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.go('/debug/agent'),
        ),
        // --- END TEMPORARY ---
        const Divider(),
        _AuthSection(authState: authState),
      ],
    );
  }
}

class _NetworkRequestsTile extends ConsumerWidget {
  const _NetworkRequestsTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(httpLogProvider);
    final count = events.length;

    return ListTile(
      leading: const Icon(Icons.http),
      title: const Text('Network Requests'),
      subtitle: Text('$count ${count == 1 ? 'request' : 'requests'} captured'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/settings/network'),
    );
  }
}

class _LogViewerTile extends ConsumerWidget {
  const _LogViewerTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sink = ref.watch(memorySinkProvider);

    return StreamBuilder<LogRecord>(
      stream: sink.onRecord,
      builder: (context, _) {
        final count = sink.length;
        return ListTile(
          leading: const Icon(Icons.article_outlined),
          title: const Text('View Logs'),
          subtitle:
              Text('$count ${count == 1 ? 'entry' : 'entries'} in buffer'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/settings/logs'),
        );
      },
    );
  }
}

class _TelemetryTile extends ConsumerWidget {
  const _TelemetryTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(logConfigProvider);

    return ListTile(
      leading: const Icon(Icons.cloud_upload_outlined),
      title: const Text('Telemetry'),
      subtitle: Text(config.backendLoggingEnabled ? 'Enabled' : 'Disabled'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/settings/telemetry'),
    );
  }
}

class _AuthSection extends ConsumerWidget {
  const _AuthSection({required this.authState});

  final AuthState authState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (authState) {
      Authenticated(:final issuerId) => Column(
          children: [
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Signed In'),
              subtitle: Text('via $issuerId'),
            ),
            ListTile(
              leading: Icon(
                Icons.logout,
                color: Theme.of(context).colorScheme.danger,
              ),
              title: Text(
                'Sign Out',
                style: TextStyle(color: Theme.of(context).colorScheme.danger),
              ),
              onTap: () => _confirmSignOut(context, ref),
            ),
          ],
        ),
      AuthLoading() => const ListTile(
          leading: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          title: Text('Loading...'),
        ),
      Unauthenticated() => const ListTile(
          leading: Icon(Icons.login),
          title: Text('Authentication'),
          subtitle: Text('Not signed in'),
          enabled: false,
        ),
      NoAuthRequired() => Column(
          children: [
            const ListTile(
              leading: Icon(Icons.no_accounts),
              title: Text('No Authentication'),
              subtitle: Text('Backend does not require login'),
            ),
            ListTile(
              leading: Icon(
                Icons.link_off,
                color: Theme.of(context).colorScheme.danger,
              ),
              title: Text(
                'Disconnect',
                style: TextStyle(color: Theme.of(context).colorScheme.danger),
              ),
              onTap: () => _disconnect(context, ref),
            ),
          ],
        ),
    };
  }

  void _disconnect(BuildContext context, WidgetRef ref) {
    Loggers.config.info('Disconnect initiated (no-auth mode)');
    ref.read(authProvider.notifier).exitNoAuthMode();
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if ((confirmed ?? false) && context.mounted) {
      Loggers.config.info('Sign out initiated');
      await ref.read(authProvider.notifier).signOut();
    }
  }
}
