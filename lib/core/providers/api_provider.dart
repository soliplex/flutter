import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_client_native/soliplex_client_native.dart';
import 'package:soliplex_frontend/core/auth/auth_provider.dart';
import 'package:soliplex_frontend/core/logging/loggers.dart';
import 'package:soliplex_frontend/core/providers/config_provider.dart';
import 'package:soliplex_frontend/core/providers/deferred_message_queue_provider.dart';
import 'package:soliplex_frontend/core/providers/http_log_provider.dart';
import 'package:soliplex_frontend/core/providers/rooms_provider.dart';
import 'package:soliplex_frontend/core/providers/sidebar_provider.dart';
import 'package:soliplex_frontend/core/providers/thread_history_cache.dart';
import 'package:soliplex_frontend/core/providers/thread_return_stack_provider.dart';
import 'package:soliplex_frontend/core/providers/threads_provider.dart';
import 'package:soliplex_frontend/core/router/app_router.dart';
import 'package:soliplex_frontend/core/services/thread_bridge_cache.dart';
import 'package:soliplex_frontend/core/services/tool_definition_converter.dart';
import 'package:soliplex_frontend/core/services/tool_execution_zone.dart';
import 'package:soliplex_monty/soliplex_monty.dart';

/// Static client-side tools. White-label apps override this in
/// [ProviderScope.overrides] to inject custom tool definitions:
///
/// ```dart
/// clientToolRegistryProvider.overrideWithValue(
///   const ToolRegistry()
///       .register(myGpsTool)
///       .register(myDbLookupTool),
/// ),
/// ```
final clientToolRegistryProvider = Provider<ToolRegistry>((ref) {
  return const ToolRegistry();
});

/// No-op executor for server-side tools.
///
/// Room tools are sent to the backend so the LLM knows they exist, but
/// executed server-side. The client never invokes this executor.
Future<String> _serverSideToolExecutor(ToolCallInfo _) async => '';

/// Merged registry: client-side tools + current room's negotiated tools +
/// execute_python (when room has tool definitions).
///
/// Room tools are definition-only (no client executor). They're sent to
/// the backend so the LLM knows about them, but executed server-side.
///
/// The execute_python tool uses [threadBridgeCacheProvider] to get a
/// per-thread [MontyBridge]. The active thread is read from the Zone
/// via [activeThreadKey], set by `ActiveRunNotifier`.
///
/// Provider dependency chain (no cycles):
/// ```text
/// currentRoomProvider ──[watch]──→ toolRegistryProvider
/// clientToolRegistryProvider ──[watch]──→ toolRegistryProvider
/// threadBridgeCacheProvider ──[read]──→ (from executor closure)
/// toolRegistryProvider ──[read]──→ (from host function closures)
/// ```
final Provider<ToolRegistry> toolRegistryProvider =
    Provider<ToolRegistry>((ref) {
  var registry = ref.watch(clientToolRegistryProvider);
  final room = ref.watch(currentRoomProvider);
  if (room != null) {
    for (final toolDef in room.toolDefinitions) {
      final tool = toolDefinitionToAgUiTool(toolDef);
      if (tool.name.isEmpty) continue;

      // Skip agent-owned tools — the backend agent handles these
      // directly; registering them client-side causes name conflicts.
      final kind = toolDef['kind'] as String?;
      if (kind == 'get_current_datetime') continue;

      registry = registry.register(
        ClientTool(definition: tool, executor: _serverSideToolExecutor),
      );

      // Alias the short `kind` name to the canonical tool_name so LLM
      // tool calls resolve without sending a duplicate definition to
      // the backend (which would conflict).
      if (kind != null && kind.isNotEmpty && kind != tool.name) {
        registry = registry.alias(kind, tool.name);
      }
    }
  }

  // Add execute_python when room has tool definitions.
  // Each thread gets its own bridge via threadBridgeCacheProvider.
  if (room != null && room.hasToolDefinitions) {
    final cacheNotifier = ref.read(threadBridgeCacheProvider.notifier);
    final mappings = roomToolDefsToMappings(room.toolDefinitions);

    registry = registry.register(
      ClientTool(
        definition: PythonExecutorTool.definition,
        executor: (toolCall) async {
          final key = activeThreadKey;
          if (key == null) return 'Error: No thread context for execute_python';

          final args = jsonDecode(toolCall.arguments) as Map<String, dynamic>;
          final code = args['code'] as String? ?? '';
          if (code.isEmpty) return 'Error: No code provided';

          try {
            final bridge = cacheNotifier.getOrCreate(key, mappings);
            final output = StringBuffer();
            await for (final event in bridge.execute(code)) {
              if (event is TextMessageContentEvent) output.write(event.delta);
              if (event is RunErrorEvent) return 'Error: ${event.message}';
            }
            return output.isEmpty
                ? 'Code executed successfully with no output.'
                : output.toString();
            // MontyPlatform throws StateError when the interpreter is stuck
            // in active state. We must catch it to return a tool result
            // instead of crashing the run.
            // ignore: avoid_catching_errors
          } on StateError catch (e) {
            return 'Error: ${e.message}';
          }
        },
      ),
    );
  }

  // Navigation & orchestration tools (available in all rooms).
  return registry
      .register(
        ClientTool(
          definition: const Tool(
            name: 'navigate_to_settings',
            description: 'Open the app settings screen',
            parameters: {'type': 'object', 'properties': <String, dynamic>{}},
          ),
          executor: (toolCall) async {
            await ref.read(routerProvider).push('/settings');
            return 'Opened settings.';
          },
        ),
      )
      .register(
        ClientTool(
          definition: const Tool(
            name: 'create_thread',
            description: 'Create a new thread in the current room',
            parameters: {'type': 'object', 'properties': <String, dynamic>{}},
          ),
          executor: (toolCall) async {
            final roomId = ref.read(currentRoomIdProvider);
            if (roomId == null) return 'Error: No room selected.';
            final api = ref.read(apiProvider);
            final (threadInfo, aguiState) = await api.createThread(roomId);
            if (aguiState.isNotEmpty) {
              ref.read(threadHistoryCacheProvider.notifier).updateHistory(
                (roomId: roomId, threadId: threadInfo.id),
                ThreadHistory(messages: const [], aguiState: aguiState),
              );
            }
            ref.invalidate(threadsProvider(roomId));
            return 'Thread created: ${threadInfo.id}';
          },
        ),
      )
      .register(
        ClientTool(
          definition: const Tool(
            name: 'switch_thread',
            description:
                'Switch to a thread by ID, or pass "back" to return to '
                'the previous thread from the return stack',
            parameters: {
              'type': 'object',
              'properties': {
                'thread_id': {
                  'type': 'string',
                  'description': 'Thread ID to switch to, or "back" to return '
                      'to the previous thread',
                },
              },
              'required': ['thread_id'],
            },
          ),
          executor: (toolCall) async {
            final roomId = ref.read(currentRoomIdProvider);
            if (roomId == null) return 'Error: No room selected.';

            final args = jsonDecode(toolCall.arguments) as Map<String, dynamic>;
            final threadId = args['thread_id'] as String? ?? '';
            if (threadId.isEmpty) return 'Error: thread_id is required.';

            final stackNotifier = ref.read(threadReturnStackProvider.notifier);

            if (threadId == 'back') {
              final entry = stackNotifier.pop();
              if (entry == null) return 'Error: Return stack is empty.';
              ref
                  .read(threadSelectionProvider.notifier)
                  .set(ThreadSelected(entry.threadId));
              ref.read(routerProvider).go(
                    '/rooms/${entry.roomId}?thread=${entry.threadId}',
                  );
              final depth = ref.read(threadReturnStackProvider).length;
              return 'Switched back to thread ${entry.threadId}. '
                  'Return stack depth: $depth';
            }

            // Push current thread onto return stack before switching.
            final currentThreadId = ref.read(currentThreadIdProvider);
            if (currentThreadId != null) {
              stackNotifier.push(
                ThreadReturnEntry(roomId: roomId, threadId: currentThreadId),
              );
            }

            ref
                .read(threadSelectionProvider.notifier)
                .set(ThreadSelected(threadId));
            ref.read(routerProvider).go(
                  '/rooms/$roomId?thread=$threadId',
                );
            final depth = ref.read(threadReturnStackProvider).length;
            return 'Switched to thread $threadId. '
                'Return stack depth: $depth';
          },
        ),
      )
      .register(
        ClientTool(
          definition: const Tool(
            name: 'list_threads',
            description:
                'List all threads in the current room with markers for '
                'the current thread and threads on the return stack',
            parameters: {'type': 'object', 'properties': <String, dynamic>{}},
          ),
          executor: (toolCall) async {
            final roomId = ref.read(currentRoomIdProvider);
            if (roomId == null) return 'Error: No room selected.';

            final threadsAsync = ref.read(threadsProvider(roomId));
            final threads = threadsAsync.whenOrNull(
              data: (threads) => threads,
            );
            if (threads == null) return 'Error: Threads not loaded.';

            final currentThreadId = ref.read(currentThreadIdProvider);
            final stack = ref.read(threadReturnStackProvider);
            final stackIds = stack.map((e) => e.threadId).toSet();

            final buffer = StringBuffer();
            for (final thread in threads) {
              buffer.write('- ${thread.id}');
              if (thread.name.isNotEmpty) buffer.write(' (${thread.name})');
              if (thread.id == currentThreadId) buffer.write(' [CURRENT]');
              if (stackIds.contains(thread.id)) buffer.write(' [IN STACK]');
              buffer.writeln();
            }
            return buffer.isEmpty ? 'No threads found.' : buffer.toString();
          },
        ),
      )
      .register(
        ClientTool(
          definition: const Tool(
            name: 'toggle_sidebar',
            description: 'Show or hide the thread history sidebar panel',
            parameters: {'type': 'object', 'properties': <String, dynamic>{}},
          ),
          executor: (toolCall) async {
            final notifier = ref.read(sidebarCollapsedProvider.notifier);
            final wasCollapsed = ref.read(sidebarCollapsedProvider);
            notifier.toggle();
            return wasCollapsed ? 'Sidebar opened.' : 'Sidebar closed.';
          },
        ),
      )
      .register(
        ClientTool(
          definition: const Tool(
            name: 'send_message_to_thread',
            description: 'Send a message to another thread. The message '
                'will be delivered after the current response completes.',
            parameters: {
              'type': 'object',
              'properties': {
                'thread_id': {
                  'type': 'string',
                  'description': 'Target thread ID to send the message to',
                },
                'message': {
                  'type': 'string',
                  'description': 'The message to send in the target thread',
                },
              },
              'required': ['thread_id', 'message'],
            },
          ),
          executor: (toolCall) async {
            final roomId = ref.read(currentRoomIdProvider);
            if (roomId == null) return 'Error: No room selected.';

            final args = jsonDecode(toolCall.arguments) as Map<String, dynamic>;
            final threadId = args['thread_id'] as String? ?? '';
            final message = args['message'] as String? ?? '';
            if (threadId.isEmpty) return 'Error: thread_id is required.';
            if (message.isEmpty) return 'Error: message is required.';

            // Push current thread onto return stack before sending
            final currentThreadId = ref.read(currentThreadIdProvider);
            if (currentThreadId != null) {
              ref.read(threadReturnStackProvider.notifier).push(
                    ThreadReturnEntry(
                      roomId: roomId,
                      threadId: currentThreadId,
                    ),
                  );
            }

            // Enqueue the message for delivery after this run completes
            ref.read(deferredMessageQueueProvider.notifier).enqueue(
                  DeferredMessage(
                    targetKey: (roomId: roomId, threadId: threadId),
                    message: message,
                  ),
                );

            return 'Message queued for thread $threadId. '
                'Will be sent after this response completes.';
          },
        ),
      );
});

/// HTTP client wrapper that delegates all operations except close().
///
/// Used to inject a shared HTTP client into consumers that call close()
/// but shouldn't own the client lifecycle. The close() operation is a no-op,
/// allowing the client to remain active for other consumers.
///
/// This enforces the resource ownership principle: "Don't close resources
/// you don't own" at the type system level.
class _NonClosingHttpClient extends http.BaseClient {
  _NonClosingHttpClient(this._inner);

  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _inner.send(request);
  }

  @override
  void close() {
    // No-op: lifecycle is managed by the provider, not the consumer
  }
}

/// Provider for the base observable HTTP client (without auth).
///
/// Creates a single [ObservableHttpClient] that wraps the platform client
/// and notifies [HttpLogNotifier] of all HTTP activity.
///
/// **Note**: Use [authenticatedClientProvider] for API requests; this provider
/// is the base client without authentication. Use this provider for:
/// - Token refresh calls (must not use authenticated client to avoid loops)
/// - Backend health checks (don't require authentication)
/// - Any other calls that should be observable but not authenticated
final baseHttpClientProvider = Provider<SoliplexHttpClient>((ref) {
  final baseClient = createPlatformClient();
  Loggers.http.debug('Platform HTTP client created');
  final observer = ref.watch(httpLogProvider.notifier);
  final observable = ObservableHttpClient(
    client: baseClient,
    observers: [observer],
  );
  Loggers.http.debug('Observable client created with 1 observer');
  ref.onDispose(() {
    try {
      observable.close();
    } catch (e, stack) {
      Loggers.http.error(
        'Error disposing observable client',
        error: e,
        stackTrace: stack,
      );
    }
  });
  return observable;
});

/// Provider for the shared HTTP client with auth token injection and refresh.
///
/// Wraps the observable client to automatically add Authorization header
/// when a token is available, and handles token refresh on expiry or 401.
///
/// This client is shared by both REST API ([httpTransportProvider]) and
/// SSE streaming ([soliplexHttpClientProvider]) to provide unified HTTP
/// logging, authentication, and token refresh.
///
/// **Decorator order**: `Refreshing(Authenticated(Observable(Platform)))`
/// - Refreshing handles proactive refresh and 401 retry (once only)
/// - Authenticated adds Authorization header
/// - Observer sees requests WITH auth headers (accurate logging)
/// - Observer sees all responses including 401s
///
/// **Lifecycle**: Lives for the entire app session. Closed when container
/// is disposed.
final authenticatedClientProvider = Provider<SoliplexHttpClient>((ref) {
  final observableClient = ref.watch(baseHttpClientProvider);
  final authNotifier = ref.watch(authProvider.notifier);

  // Inner client: adds Authorization header
  final authClient = AuthenticatedHttpClient(
    observableClient,
    () => ref.read(accessTokenProvider),
  );

  // Outer client: handles proactive refresh + 401 retry
  Loggers.http.debug('Authenticated client created');
  return RefreshingHttpClient(inner: authClient, refresher: authNotifier);
});

/// Provider for the HTTP transport layer.
///
/// Creates a singleton [HttpTransport] instance using the shared
/// [authenticatedClientProvider]. All HTTP requests through this transport
/// are logged to [httpLogProvider].
///
/// **Lifecycle**: This is a non-autoDispose provider because the HTTP
/// transport should live for the entire app session.
///
/// **Threading**: Safe to call from any isolate. The underlying
/// adapter uses dart:http which is isolate-safe.
final httpTransportProvider = Provider<HttpTransport>((ref) {
  final client = ref.watch(authenticatedClientProvider);
  final transport = HttpTransport(client: client);

  // Note: Don't dispose transport here - client is managed by
  // authenticatedClientProvider
  return transport;
});

/// Provider for the URL builder.
///
/// Creates a [UrlBuilder] configured with the base URL from [configProvider].
/// Automatically reconstructs when the config changes (e.g., user changes
/// backend URL in settings).
///
/// The URL builder appends `/api/v1` to the base URL to construct
/// API endpoint URLs.
final urlBuilderProvider = Provider<UrlBuilder>((ref) {
  final config = ref.watch(configProvider);
  Loggers.http.debug('URL builder created: ${config.baseUrl}/api/v1');
  return UrlBuilder('${config.baseUrl}/api/v1');
});

/// Provider for the SoliplexApi instance.
///
/// Creates a single API client instance for the app lifetime.
/// The client is configured using dependencies from [httpTransportProvider]
/// and [urlBuilderProvider].
///
/// **Lifecycle**: This is a non-autoDispose provider because the API client
/// should live for the entire app session. The client shares the HTTP
/// transport with other potential API clients.
///
/// **Dependency Graph**:
/// ```text
/// configProvider
///     ↓
/// urlBuilderProvider → apiProvider
///                         ↑
/// httpTransportProvider ──┘
/// ```
///
/// **Usage Example**:
/// ```dart
/// final api = ref.watch(apiProvider);
/// final rooms = await api.getRooms();
/// ```
///
/// **Error Handling**:
/// Methods throw [SoliplexException] subtypes:
/// - [NetworkException]: Connection failures, timeouts
/// - [AuthException]: 401/403 authentication errors
/// - [NotFoundException]: 404 resource not found
/// - [ApiException]: Other 4xx/5xx server errors
/// - [CancelledException]: Request was cancelled
final apiProvider = Provider<SoliplexApi>((ref) {
  final transport = ref.watch(httpTransportProvider);
  final urlBuilder = ref.watch(urlBuilderProvider);

  // Note: We don't register ref.onDispose(api.close) because api.close()
  // would close the shared transport. The transport is managed by
  // httpTransportProvider, and the underlying client is managed by
  // baseHttpClientProvider.
  Loggers.http.debug('API client created');
  return SoliplexApi(
    transport: transport,
    urlBuilder: urlBuilder,
    onWarning: Loggers.http.warning,
  );
});

/// Provider for the Soliplex HTTP client.
///
/// Returns the shared [authenticatedClientProvider] to ensure all HTTP activity
/// (both REST and SSE) is logged through [httpLogProvider].
final soliplexHttpClientProvider = Provider<SoliplexHttpClient>((ref) {
  return ref.watch(authenticatedClientProvider);
});

/// Provider for http.Client that uses our HTTP client stack.
///
/// This bridges our [SoliplexHttpClient] to the standard [http.Client]
/// interface, allowing libraries like AgUiClient to use our HTTP
/// infrastructure.
///
/// **Ownership**: This provider does NOT close the underlying client on
/// disposal. [HttpClientAdapter] is a thin stateless wrapper, and the
/// underlying [soliplexHttpClientProvider] manages its own lifecycle.
final httpClientProvider = Provider<http.Client>((ref) {
  final soliplexClient = ref.watch(soliplexHttpClientProvider);
  return HttpClientAdapter(client: soliplexClient);
});

/// Provider for the AG-UI client.
///
/// Creates an [AgUiClient] that uses our HTTP stack via [httpClientProvider].
/// This ensures AG-UI requests go through our platform adapters and observers.
///
/// **Ownership**: The httpClient is wrapped in [_NonClosingHttpClient] to
/// prevent AgUiClient.close() from closing the shared HTTP client. This
/// provider watches [configProvider], so it gets disposed when the backend
/// URL changes. Without the wrapper, disposal would close the shared client,
/// breaking all HTTP consumers. See: https://github.com/soliplex/flutter/issues/27
final agUiClientProvider = Provider<AgUiClient>((ref) {
  final httpClient = ref.watch(httpClientProvider);
  final config = ref.watch(configProvider);

  // Wrap in non-closing adapter to protect shared resource.
  // AgUiClient.close() will clean up its internal resources (streams, tokens)
  // but won't close the underlying shared HTTP client.
  final protectedClient = _NonClosingHttpClient(httpClient);

  Loggers.http.debug('AG-UI client created (timeout: 600s)');
  final client = AgUiClient(
    config: AgUiClientConfig(
      baseUrl: '${config.baseUrl}/api/v1',
      requestTimeout: const Duration(seconds: 600),
      connectionTimeout: const Duration(seconds: 600),
    ),
    httpClient: protectedClient,
  );

  ref.onDispose(client.close);
  return client;
});
