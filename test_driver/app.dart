import 'package:flutter_driver/driver_extension.dart';
import 'package:soliplex_frontend/soliplex_frontend.dart';

/// Driver-enabled entry point for interactive testing via dart-tools MCP.
///
/// Launch with:
///   mcp__dart-tools__launch_app(target: "test_driver/app.dart")
///
/// Then connect to the DTD and use flutter_driver commands to interact.
Future<void> main() async {
  enableFlutterDriverExtension();
  await runSoliplexApp(
    config: const SoliplexConfig(
      logo: LogoConfig.soliplex,
      oauthRedirectScheme: 'ai.soliplex.client',
    ),
  );
}
