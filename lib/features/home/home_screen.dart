import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_frontend/core/auth/auth_provider.dart';
import 'package:soliplex_frontend/core/providers/api_provider.dart';
import 'package:soliplex_frontend/core/providers/config_provider.dart';
import 'package:soliplex_frontend/design/theme/theme_extensions.dart';
import 'package:soliplex_frontend/design/tokens/spacing.dart';
import 'package:soliplex_frontend/features/home/connection_flow.dart';

/// Home/welcome screen with backend URL configuration.
///
/// This is the first screen users see. Flow:
/// 1. User enters backend URL and clicks Connect
/// 2. App fetches auth providers from that URL
/// 3. If providers exist → redirect to login screen
/// 4. If no providers → bypass auth, go directly to rooms
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _urlController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isConnecting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Initialize with current URL after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final config = ref.read(configProvider);
      _urlController.text = config.baseUrl;
    });
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  String? _validateUrl(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter a server URL';
    }
    final trimmed = value.trim();
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      return 'URL must start with http:// or https://';
    }
    return null;
  }

  Future<void> _connect() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isConnecting = true;
      _error = null;
    });

    try {
      final url = _urlController.text.trim();
      final currentUrl = ref.read(configProvider).baseUrl;
      final isBackendChange = normalizeUrl(url) != normalizeUrl(currentUrl);

      debugPrint('HomeScreen: Connecting to $url');

      // Determine and execute pre-connect cleanup action.
      final preConnectAction = determinePreConnectAction(
        isBackendChange: isBackendChange,
        currentAuthState: ref.read(authProvider),
      );
      switch (preConnectAction) {
        case PreConnectAction.signOut:
          await ref.read(authProvider.notifier).signOut();
          if (!mounted) return;
        case PreConnectAction.exitNoAuthMode:
          ref.read(authProvider.notifier).exitNoAuthMode();
        case PreConnectAction.none:
          break;
      }

      // Save the URL
      await ref.read(configProvider.notifier).setBaseUrl(url);
      debugPrint(
        'HomeScreen: URL saved, config.baseUrl is now: '
        '${ref.read(configProvider).baseUrl}',
      );

      // Fetch auth providers from the new URL
      final transport = ref.read(httpTransportProvider);
      final providers = await fetchAuthProviders(
        transport: transport,
        baseUrl: Uri.parse(url),
      );

      if (!mounted) return;

      // Determine and execute post-connect navigation.
      final result = determinePostConnectResult(
        hasProviders: providers.isNotEmpty,
        currentAuthState: ref.read(authProvider),
      );
      switch (result) {
        case EnterNoAuthModeResult():
          await ref.read(authProvider.notifier).enterNoAuthMode();
          if (!mounted) return;
          context.go('/rooms');
        case AlreadyAuthenticatedResult():
          context.go('/rooms');
        case RequireLoginResult(:final shouldExitNoAuthMode):
          if (shouldExitNoAuthMode) {
            ref.read(authProvider.notifier).exitNoAuthMode();
          }
          ref.invalidate(oidcIssuersProvider);
          context.go('/login');
      }
    } on NetworkException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.isTimeout
              ? 'Request timed out. Please try again.'
              : 'Cannot reach server. Check the URL and try again.';
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _error = 'Server error: ${e.statusCode}');
      }
    } on Exception catch (e) {
      if (mounted) {
        setState(() => _error = 'Connection failed. Please try again.');
      }
      debugPrint('HomeScreen: Unexpected exception: ${e.runtimeType} - $e');
    } finally {
      if (mounted) {
        setState(() => _isConnecting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final soliplexTheme = SoliplexTheme.of(context);
    final config = ref.watch(configProvider);

    // Update text field if config changes externally
    if (_urlController.text != config.baseUrl && !_isConnecting) {
      _urlController.text = config.baseUrl;
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(SoliplexSpacing.s6),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Icon(
                Icons.dns_outlined,
                size: 64,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Soliplex',
                style: theme.textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Enter the URL of your backend server',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // URL Input
              Form(
                key: _formKey,
                child: TextFormField(
                  controller: _urlController,
                  validator: _validateUrl,
                  decoration: InputDecoration(
                    labelText: 'Backend URL',
                    hintText: 'http://localhost:8000',
                    prefixIcon: const Icon(Icons.link),
                    border: const OutlineInputBorder(),
                    suffixIcon: _isConnecting
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : null,
                  ),
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.go,
                  onFieldSubmitted: (_) => _connect(),
                  enabled: !_isConnecting,
                ),
              ),
              const SizedBox(height: 16),

              // Error message
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(
                      soliplexTheme.radii.sm,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: theme.colorScheme.onErrorContainer,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Connect button
              FilledButton.icon(
                onPressed: _isConnecting ? null : _connect,
                icon: const Icon(Icons.login),
                label: const Text('Connect'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
