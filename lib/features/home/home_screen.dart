import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_frontend/core/auth/auth_provider.dart';
import 'package:soliplex_frontend/core/providers/api_provider.dart';
import 'package:soliplex_frontend/core/providers/config_provider.dart';
import 'package:soliplex_frontend/core/providers/shell_config_provider.dart';
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
  static const _logoSize = 64.0;

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

  void _setError(String detail, {String? serverDetail}) {
    if (!mounted) return;
    setState(() {
      _error =
          serverDetail != null ? '$detail\n\nDetails: $serverDetail' : detail;
    });
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

      // Fetch auth providers to validate the URL is reachable
      final transport = ref.read(httpTransportProvider);
      final providers = await fetchAuthProviders(
        transport: transport,
        baseUrl: Uri.parse(url),
      );

      // Only persist URL after successful connection
      try {
        await ref.read(configProvider.notifier).setBaseUrl(url);
        debugPrint(
          'HomeScreen: URL saved, config.baseUrl is now: '
          '${ref.read(configProvider).baseUrl}',
        );
      } on Exception catch (e) {
        debugPrint('HomeScreen: Failed to persist URL: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Connected, but couldn't save URL for next time."),
            ),
          );
        }
        // Continue to navigation - don't block user over persistence failure
      }

      if (!mounted) return;

      // Determine and execute post-connect navigation.
      final result = determinePostConnectResult(
        hasProviders: providers.isNotEmpty,
        currentAuthState: ref.read(authProvider),
      );
      final landingRoute =
          ref.read(shellConfigProvider).routes.authenticatedLandingRoute;
      switch (result) {
        case EnterNoAuthModeResult():
          await ref.read(authProvider.notifier).enterNoAuthMode();
          if (!mounted) return;
          context.go(landingRoute);
        case AlreadyAuthenticatedResult():
          context.go(landingRoute);
        case RequireLoginResult(:final shouldExitNoAuthMode):
          if (shouldExitNoAuthMode) {
            ref.read(authProvider.notifier).exitNoAuthMode();
          }
          ref.invalidate(oidcIssuersProvider);
          context.go('/login');
      }
    } on AuthException catch (e) {
      debugPrint('HomeScreen: Auth error: ${e.message}');
      final detail = e.statusCode == 401
          ? 'Authentication required. This server requires login credentials. '
              '(${e.statusCode})'
          : 'Access denied by server. The server may require additional '
              'configuration or may be blocking this connection. '
              '(${e.statusCode})';
      _setError(detail, serverDetail: e.serverMessage);
    } on NotFoundException catch (e) {
      debugPrint('HomeScreen: Not found: ${e.message}');
      const detail = 'Server reached, but the expected API endpoint was not '
          'found. The server version may be incompatible. (404)';
      _setError(detail, serverDetail: e.serverMessage);
    } on CancelledException catch (e) {
      debugPrint('HomeScreen: Request cancelled');
      final detail = e.reason != null
          ? 'Request cancelled: ${e.reason}'
          : 'Request cancelled.';
      _setError(detail);
    } on NetworkException catch (e) {
      debugPrint('HomeScreen: Network error: ${e.message}');
      final detail = e.isTimeout
          ? 'Connection timed out. The server may be slow or unreachable.'
          : 'Cannot reach server. Check the URL and your network connection.';
      _setError(detail, serverDetail: e.isTimeout ? null : e.message);
    } on ApiException catch (e) {
      debugPrint('HomeScreen: API error: ${e.statusCode} - ${e.message}');
      final detail = e.statusCode >= 500
          ? 'Server error. Please try again later. (${e.statusCode})'
          : 'Unexpected response from server. (${e.statusCode})';
      _setError(detail, serverDetail: e.serverMessage);
    } on Exception catch (e) {
      debugPrint('HomeScreen: Unexpected exception: ${e.runtimeType} - $e');
      _setError('Connection failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isConnecting = false);
      }
    }
  }

  Widget _buildLogo(ThemeData theme) {
    final config = ref.watch(shellConfigProvider);
    return Image.asset(
      config.logo.assetPath,
      package: config.logo.package,
      width: _logoSize,
      height: _logoSize,
      semanticLabel: '${config.appName} logo',
      errorBuilder: (context, error, stack) => Icon(
        Icons.dns_outlined,
        size: _logoSize,
        color: theme.colorScheme.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final soliplexTheme = SoliplexTheme.of(context);

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
              _buildLogo(theme),
              const SizedBox(height: 16),
              Text(
                ref.watch(shellConfigProvider).appName,
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
                    borderRadius: BorderRadius.circular(soliplexTheme.radii.sm),
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
