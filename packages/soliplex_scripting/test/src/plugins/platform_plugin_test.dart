import 'dart:typed_data';

import 'package:soliplex_agent/soliplex_agent.dart' show HostApi;
import 'package:soliplex_client/soliplex_client.dart'
    show CancelToken, HttpResponse, SoliplexHttpClient, StreamedHttpResponse;
import 'package:soliplex_scripting/soliplex_scripting.dart';
import 'package:test/test.dart';

import '../helpers.dart';

void main() {
  group('PlatformPlugin', () {
    late _FakeHostApi hostApi;
    late PlatformPlugin plugin;

    setUp(() {
      hostApi = _FakeHostApi();
      plugin = PlatformPlugin(hostApi: hostApi);
    });

    test('namespace is platform', () {
      expect(plugin.namespace, 'platform');
    });

    test('provides 5 functions', () {
      expect(plugin.functions, hasLength(5));
      final names = plugin.functions.map((f) => f.schema.name).toSet();
      expect(
        names,
        containsAll([
          'host_invoke',
          'sleep',
          'fetch',
          'log',
          'get_auth_token',
        ]),
      );
    });

    test('is a LegacyUnprefixedPlugin', () {
      expect(plugin, isA<LegacyUnprefixedPlugin>());
      expect(
        plugin.legacyNames,
        containsAll([
          'host_invoke',
          'sleep',
          'fetch',
          'log',
          'get_auth_token',
        ]),
      );
    });

    test('registers onto bridge via PluginRegistry', () async {
      final bridge = RecordingBridge();
      final registry = PluginRegistry()..register(plugin);
      await registry.attachTo(bridge);

      final names = bridge.registered.map((f) => f.schema.name).toSet();
      expect(names, contains('host_invoke'));
      expect(names, contains('sleep'));
    });

    group('handlers', () {
      late Map<String, HostFunction> byName;

      setUp(() {
        byName = {for (final f in plugin.functions) f.schema.name: f};
      });

      test('host_invoke delegates to HostApi.invoke', () async {
        final result = await byName['host_invoke']!.handler({
          'name': 'native.clipboard',
          'args': <String, Object?>{'action': 'read'},
        });

        expect(result, 'invoked');
        expect(hostApi.calls['invoke'], [
          'native.clipboard',
          {'action': 'read'},
        ]);
      });

      test('log delegates to HostApi.invoke', () async {
        final result = await byName['log']!.handler({
          'message': 'hello world',
          'level': 'info',
        });

        expect(result, '[info] hello world');
        expect(hostApi.calls['invoke']![0], 'log');
      });

      test('log schema defaults level to info', () {
        final schema = byName['log']!.schema;
        expect(schema.params[1].defaultValue, 'info');
      });

      test('fetch throws StateError when httpClient is null', () async {
        await expectLater(
          byName['fetch']!.handler({
            'url': 'https://example.com',
            'method': 'GET',
          }),
          throwsA(isA<StateError>()),
        );
      });

      test('get_auth_token returns null when callback not set', () async {
        final result = await byName['get_auth_token']!.handler({});
        expect(result, isNull);
      });

      test('get_auth_token returns token from callback', () async {
        final p = PlatformPlugin(
          hostApi: hostApi,
          getAuthToken: () => 'oidc-token',
        );
        final fn = p.functions.firstWhere(
          (f) => f.schema.name == 'get_auth_token',
        );
        final result = await fn.handler({});
        expect(result, 'oidc-token');
      });

      test('fetch schema has url, method, headers, body', () {
        final schema = byName['fetch']!.schema;
        expect(schema.params, hasLength(4));
        expect(schema.params[0].name, 'url');
        expect(schema.params[1].name, 'method');
        expect(schema.params[1].defaultValue, 'GET');
        expect(schema.params[2].name, 'headers');
        expect(schema.params[3].name, 'body');
      });
    });

    group('with httpClient', () {
      late _FakeHttpClient httpClient;
      late Map<String, HostFunction> byName;

      setUp(() {
        httpClient = _FakeHttpClient();
        final p = PlatformPlugin(
          hostApi: hostApi,
          httpClient: httpClient,
        );
        byName = {for (final f in p.functions) f.schema.name: f};
      });

      test('fetch delegates to SoliplexHttpClient.request', () async {
        final result = await byName['fetch']!.handler({
          'url': 'https://api.example.com/data',
          'method': 'POST',
          'headers': <String, Object?>{'X-Custom': 'yes'},
          'body': '{"a":1}',
        });

        expect(result, isA<Map<String, Object?>>());
        final map = result! as Map<String, Object?>;
        expect(map['status'], 200);
        expect(map['body'], 'ok');
        expect(httpClient.lastMethod, 'POST');
      });

      test('fetch bare GET with no headers or body', () async {
        final result = await byName['fetch']!.handler({
          'url': 'https://public.api/data',
          'method': 'GET',
          'headers': null,
          'body': null,
        });

        final map = result! as Map<String, Object?>;
        expect(map['status'], 200);
        expect(httpClient.lastMethod, 'GET');
      });
    });
  });
}

class _FakeHostApi implements HostApi {
  final calls = <String, List<Object?>>{};

  @override
  int registerDataFrame(Map<String, List<Object?>> columns) => 0;

  @override
  Map<String, List<Object?>>? getDataFrame(int handle) => null;

  @override
  int registerChart(Map<String, Object?> chartConfig) => 0;

  @override
  bool updateChart(int chartId, Map<String, Object?> chartConfig) => false;

  @override
  Future<Object?> invoke(String name, Map<String, Object?> args) async {
    calls['invoke'] = [name, args];
    return 'invoked';
  }
}

class _FakeHttpClient implements SoliplexHttpClient {
  String? lastMethod;
  late Uri lastUri;
  Map<String, String>? lastHeaders;
  Object? lastBody;

  @override
  Future<HttpResponse> request(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    Duration? timeout,
  }) async {
    lastMethod = method;
    lastUri = uri;
    lastHeaders = headers;
    lastBody = body;
    return HttpResponse(
      statusCode: 200,
      bodyBytes: Uint8List.fromList('ok'.codeUnits),
      headers: const {'content-type': 'text/plain'},
    );
  }

  @override
  Future<StreamedHttpResponse> requestStream(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    CancelToken? cancelToken,
  }) =>
      throw UnimplementedError();

  @override
  void close() {}
}
