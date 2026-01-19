import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:soliplex_frontend/core/auth/auth_provider.dart';
import 'package:soliplex_frontend/core/auth/auth_state.dart';
import 'package:soliplex_frontend/core/providers/backend_version_provider.dart';
import 'package:soliplex_frontend/core/providers/config_provider.dart';
import 'package:soliplex_frontend/core/providers/package_info_provider.dart';

/// Settings screen for app configuration.
///
/// Returns body content only; AppShell wrapper is provided by the router.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(configProvider);
    final packageInfo = ref.watch(packageInfoProvider);
    final authState = ref.watch(authProvider);
    final backendVersion = ref.watch(backendVersionInfoProvider);

    return ListView(
      children: [
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text('App Version'),
          subtitle: Text('${packageInfo.version}+${packageInfo.buildNumber}'),
        ),
        ListTile(
          leading: const Icon(Icons.dns),
          title: const Text('Backend URL'),
          subtitle: Text(config.baseUrl),
        ),
        ListTile(
          leading: const Icon(Icons.cloud_outlined),
          title: const Text('Backend Version'),
          subtitle: backendVersion.when(
            data: (info) => Text(info.soliplexVersion),
            loading: () => const Text('Loading...'),
            error: (error, stack) {
              debugPrint('Failed to load backend version: $error');
              debugPrint('$stack');
              return const Text('Unavailable');
            },
          ),
          trailing: TextButton(
            onPressed: () => context.push('/settings/backend-versions'),
            child: const Text('View All'),
          ),
        ),
        const Divider(),
        _AuthSection(authState: authState),
      ],
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
              leading: const Icon(Icons.logout),
              title: const Text('Sign Out'),
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
              leading: const Icon(Icons.link_off),
              title: const Text('Disconnect'),
              onTap: () => _disconnect(context, ref),
            ),
          ],
        ),
    };
  }

  void _disconnect(BuildContext context, WidgetRef ref) {
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
      await ref.read(authProvider.notifier).signOut();
    }
  }
}
