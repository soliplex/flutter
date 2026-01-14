import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soliplex_frontend/core/auth/auth_provider.dart';
import 'package:soliplex_frontend/core/auth/auth_state.dart';
import 'package:soliplex_frontend/core/providers/config_provider.dart';
import 'package:soliplex_frontend/core/providers/package_info_provider.dart';
import 'package:soliplex_frontend/shared/widgets/platform_adaptive_dialog.dart';

/// Settings screen for app configuration.
///
/// Returns body content only; AppShell wrapper is provided by the router.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _showUrlEditDialog(
    BuildContext context,
    WidgetRef ref,
    String currentUrl,
  ) async {
    final controller = TextEditingController(text: currentUrl);
    final formKey = GlobalKey<FormState>();

    final newUrl = await showPlatformAdaptiveDialog<String>(
      context: context,
      title: const Text('Backend URL'),
      content: Form(
        key: formKey,
        child: TextFormField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'URL',
            hintText: 'http://localhost:8000',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.url,
          autofocus: true,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter a URL';
            }
            final trimmed = value.trim();
            if (!trimmed.startsWith('http://') &&
                !trimmed.startsWith('https://')) {
              return 'URL must start with http:// or https://';
            }
            return null;
          },
        ),
      ),
      actions: [
        const AdaptiveDialogAction<String>(
          child: Text('Cancel'),
        ),
        AdaptiveDialogAction<String>(
          child: const Text('Save'),
          isDefault: true,
          onPressed: () {
            if (formKey.currentState!.validate()) {
              Navigator.of(context).pop(controller.text.trim());
            }
          },
        ),
      ],
    );

    controller.dispose();

    if (newUrl != null && newUrl != currentUrl) {
      await ref.read(configProvider.notifier).setBaseUrl(newUrl);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backend URL updated')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(configProvider);
    final packageInfo = ref.watch(packageInfoProvider);
    final authState = ref.watch(authProvider);

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
          trailing: const Icon(Icons.edit), // Added visual cue for editing
          onTap: () => _showUrlEditDialog(context, ref, config.baseUrl),
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
