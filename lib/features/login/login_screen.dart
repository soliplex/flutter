import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:soliplex_frontend/core/auth/auth_flow.dart';
import 'package:soliplex_frontend/core/auth/auth_provider.dart';
import 'package:soliplex_frontend/core/auth/oidc_issuer.dart';
import 'package:soliplex_frontend/core/models/consent_notice.dart';
import 'package:soliplex_frontend/core/providers/shell_config_provider.dart';
import 'package:soliplex_frontend/design/theme/theme_extensions.dart';
import 'package:soliplex_frontend/design/tokens/breakpoints.dart';
import 'package:soliplex_frontend/design/tokens/spacing.dart';
import 'package:soliplex_frontend/shared/widgets/markdown/flutter_markdown_plus_renderer.dart';
import 'package:soliplex_frontend/shared/widgets/platform_adaptive_progress_indicator.dart';

/// Login screen with OIDC provider selection.
///
/// Displays available identity providers and handles authentication flow.
/// On successful login, navigates to home screen.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _consentGiven = false;
  bool _isAuthenticating = false;
  String? _errorMessage;

  Future<void> _signIn(OidcIssuer issuer) async {
    setState(() {
      _isAuthenticating = true;
      _errorMessage = null;
    });

    try {
      await ref.read(authProvider.notifier).signIn(issuer);
      // Native: sign in complete - navigate to landing route
      if (mounted) {
        final landingRoute =
            ref.read(shellConfigProvider).routes.authenticatedLandingRoute;
        context.go(landingRoute);
      }
    } on AuthRedirectInitiated {
      // Web: browser is redirecting to IdP, page will unload.
      // Auth completes via callback URL → AuthCallbackScreen.
      return;
    } on AuthException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(shellConfigProvider);
    final consentNotice = config.consentNotice;

    if (consentNotice != null && !_consentGiven) {
      return Scaffold(body: _buildInterstitial(consentNotice));
    }

    final soliplexTheme = SoliplexTheme.of(context);
    final issuersAsync = ref.watch(oidcIssuersProvider);
    // Note: auth redirect handled by router (app_router.dart)

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(SoliplexSpacing.s6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  ref.watch(shellConfigProvider).appName,
                  style: Theme.of(context).textTheme.headlineLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Sign in to continue',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                issuersAsync.when(
                  data: _buildIssuerList,
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => _buildError(error.toString()),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(
                        soliplexTheme.radii.sm,
                      ),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInterstitial(ConsentNotice notice) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final maxContentWidth = width >= SoliplexBreakpoints.desktop
            ? width * 2 / 3
            : width - SoliplexSpacing.s4 * 2;

        return SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxContentWidth),
              child: Padding(
                padding: const EdgeInsets.all(SoliplexSpacing.s6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      notice.title,
                      style: Theme.of(context).textTheme.headlineLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 48),
                    Flexible(
                      child: SingleChildScrollView(
                        child: FlutterMarkdownPlusRenderer(
                          data: notice.body,
                        ),
                      ),
                    ),
                    const SizedBox(height: 48),
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: FilledButton(
                          onPressed: () => setState(() => _consentGiven = true),
                          child: Padding(
                            padding: const EdgeInsetsGeometry.all(
                              SoliplexSpacing.s2,
                            ),
                            child: Text(notice.acknowledgmentLabel),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildIssuerList(List<OidcIssuer> issuers) {
    final showHomeRoute = ref.watch(shellConfigProvider).routes.showHomeRoute;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (issuers.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 24),
            child: Text(
              'No identity providers configured.',
              textAlign: TextAlign.center,
            ),
          )
        else ...[
          for (final issuer in issuers) ...[
            FilledButton.icon(
              onPressed: _isAuthenticating ? null : () => _signIn(issuer),
              icon: const Icon(Icons.login),
              label: Text('Sign in with ${issuer.title}'),
            ),
            const SizedBox(height: 12),
          ],
          if (_isAuthenticating)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: PlatformAdaptiveProgressIndicator(),
            ),
          const SizedBox(height: 24),
        ],
        if (showHomeRoute)
          TextButton(
            onPressed: () => context.go('/'),
            child: Text(
              'Change server',
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ),
      ],
    );
  }

  Widget _buildError(String message) {
    return Column(
      children: [
        Icon(
          Icons.error_outline,
          size: 48,
          color: Theme.of(context).colorScheme.error,
        ),
        const SizedBox(height: 16),
        Text(
          'Failed to load identity providers',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          message,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => ref.invalidate(oidcIssuersProvider),
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      ],
    );
  }
}
