import 'package:soliplex_agent/soliplex_agent.dart' show HostApi;
import 'package:soliplex_client/soliplex_client.dart' show SoliplexHttpClient;
import 'package:soliplex_interpreter_monty/soliplex_interpreter_monty.dart';
import 'package:soliplex_scripting/src/plugin_registry.dart';

/// Plugin exposing platform operations (invoke, sleep, fetch, log,
/// get_auth_token) to Monty scripts.
///
/// Uses [LegacyUnprefixedPlugin] because the function names predate the
/// `namespace_` prefix convention.
class PlatformPlugin extends MontyPlugin with LegacyUnprefixedPlugin {
  PlatformPlugin({
    required HostApi hostApi,
    SoliplexHttpClient? httpClient,
    String? Function()? getAuthToken,
  })  : _hostApi = hostApi,
        _httpClient = httpClient,
        _getAuthToken = getAuthToken;

  final HostApi _hostApi;
  final SoliplexHttpClient? _httpClient;
  final String? Function()? _getAuthToken;

  @override
  String get namespace => 'platform';

  @override
  Set<String> get legacyNames => const {
        'host_invoke',
        'sleep',
        'fetch',
        'log',
        'get_auth_token',
      };

  @override
  List<HostFunction> get functions => [
        HostFunction(
          schema: const HostFunctionSchema(
            name: 'host_invoke',
            description: 'Invoke a named host operation.',
            params: [
              HostParam(
                name: 'name',
                type: HostParamType.string,
                description: 'Namespaced operation name.',
              ),
              HostParam(
                name: 'args',
                type: HostParamType.map,
                description: 'Arguments for the operation.',
              ),
            ],
          ),
          handler: (args) async {
            final name = args['name'];
            if (name is! String) {
              throw ArgumentError.value(name, 'name', 'Expected a string.');
            }
            final rawArgs = args['args'];
            if (rawArgs is! Map) {
              throw ArgumentError.value(rawArgs, 'args', 'Expected a map.');
            }
            return _hostApi.invoke(name, Map<String, Object?>.from(rawArgs));
          },
        ),
        HostFunction(
          schema: const HostFunctionSchema(
            name: 'sleep',
            description: 'Pause execution for a number of milliseconds.',
            params: [
              HostParam(
                name: 'ms',
                type: HostParamType.integer,
                description: 'Duration in milliseconds.',
              ),
            ],
          ),
          handler: (args) async {
            final ms = (args['ms']! as num).toInt();
            await Future<void>.delayed(Duration(milliseconds: ms));
            return null;
          },
        ),
        HostFunction(
          schema: const HostFunctionSchema(
            name: 'fetch',
            description: 'Make an HTTP request and return the response. '
                'Returns a dict with status, body, and headers.',
            params: [
              HostParam(
                name: 'url',
                type: HostParamType.string,
                description: 'Request URL.',
              ),
              HostParam(
                name: 'method',
                type: HostParamType.string,
                isRequired: false,
                defaultValue: 'GET',
                description: 'HTTP method (GET, POST, PUT, DELETE).',
              ),
              HostParam(
                name: 'headers',
                type: HostParamType.map,
                isRequired: false,
                description: 'Request headers.',
              ),
              HostParam(
                name: 'body',
                type: HostParamType.string,
                isRequired: false,
                description: 'Request body (for POST/PUT).',
              ),
            ],
          ),
          handler: (args) async {
            final client = _httpClient;
            if (client == null) {
              throw StateError(
                'fetch() requires an httpClient. '
                'Pass SoliplexHttpClient to PlatformPlugin.',
              );
            }
            final url = Uri.parse(args['url']! as String);
            final method = (args['method']! as String).toUpperCase();
            final rawHeaders = args['headers'] as Map?;
            final headers = rawHeaders != null
                ? Map<String, String>.from(rawHeaders)
                : <String, String>{};
            final body = args['body'] as String?;

            final response = await client.request(
              method,
              url,
              headers: headers,
              body: body,
            );

            return <String, Object?>{
              'status': response.statusCode,
              'body': response.body,
              'headers': response.headers,
            };
          },
        ),
        HostFunction(
          schema: const HostFunctionSchema(
            name: 'log',
            description: 'Log a message at the specified level. '
                'Visible in host debug output.',
            params: [
              HostParam(
                name: 'message',
                type: HostParamType.string,
                description: 'Log message.',
              ),
              HostParam(
                name: 'level',
                type: HostParamType.string,
                isRequired: false,
                defaultValue: 'info',
                description:
                    "Log level: 'debug', 'info', 'warning', or 'error'.",
              ),
            ],
          ),
          handler: (args) async {
            final level = args['level']! as String;
            final message = args['message']! as String;
            await _hostApi.invoke('log', <String, Object?>{
              'level': level,
              'message': message,
            });
            return '[$level] $message';
          },
        ),
        HostFunction(
          schema: const HostFunctionSchema(
            name: 'get_auth_token',
            description: 'Get the current OIDC bearer token, '
                'or null if not authenticated. Use this to add '
                'Authorization headers to fetch() calls that need '
                'Soliplex backend authentication.',
          ),
          handler: (args) async {
            return _getAuthToken?.call();
          },
        ),
      ];
}
