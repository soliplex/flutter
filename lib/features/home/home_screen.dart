import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_frontend/core/auth/auth_provider.dart';
import 'package:soliplex_frontend/core/providers/api_provider.dart';
import 'package:soliplex_frontend/core/providers/config_provider.dart';

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
      debugPrint('HomeScreen: Connecting to $url');

      // Save the URL first
      await ref.read(configProvider.notifier).setBaseUrl(url);
      debugPrint('HomeScreen: URL saved, config.baseUrl is now: '
          '${ref.read(configProvider).baseUrl}');

      // Fetch auth providers from the new URL
      final transport = ref.read(httpTransportProvider);
      final providers = await fetchAuthProviders(
        transport: transport,
        baseUrl: Uri.parse(url),
      );

      if (!mounted) return;

      if (providers.isEmpty) {
        // No auth required - bypass and go to rooms
        noAuthMode = true;
        context.go('/rooms');
      } else {
        // Auth required - sign out (clears old tokens) and go to login
        noAuthMode = false;
        await ref.read(authProvider.notifier).signOut();
        if (!mounted) return;
        ref.invalidate(oidcIssuersProvider);
        context.go('/login');
      }
    } on Exception catch (e) {
      if (mounted) {
        setState(() {
          _error = _formatError(e);
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isConnecting = false);
      }
    }
  }

  String _formatError(Exception e) {
    if (e is ApiException) {
      return 'Server error: ${e.statusCode}';
    }
    final message = e.toString();
    // Extract just the error message without type prefix
    if (message.contains('SocketException')) {
      return 'Cannot reach server. Check the URL and try again.';
    }
    if (message.contains('Connection refused')) {
      return 'Connection refused. Is the server running?';
    }
    return message.split('\n').first;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = ref.watch(configProvider);

    // Update text field if config changes externally
    if (_urlController.text != config.baseUrl && !_isConnecting) {
      _urlController.text = config.baseUrl;
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
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
                    borderRadius: BorderRadius.circular(8),
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
