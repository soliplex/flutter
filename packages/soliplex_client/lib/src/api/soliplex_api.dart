import 'package:ag_ui/ag_ui.dart' hide CancelToken;
import 'package:soliplex_client/src/api/mappers.dart';
import 'package:soliplex_client/src/application/agui_event_processor.dart';
import 'package:soliplex_client/src/application/streaming_state.dart';
import 'package:soliplex_client/src/domain/backend_version_info.dart';
import 'package:soliplex_client/src/domain/chat_message.dart';
import 'package:soliplex_client/src/domain/conversation.dart';
import 'package:soliplex_client/src/domain/quiz.dart';
import 'package:soliplex_client/src/domain/rag_document.dart';
import 'package:soliplex_client/src/domain/room.dart';
import 'package:soliplex_client/src/domain/run_info.dart';
import 'package:soliplex_client/src/domain/thread_info.dart';
import 'package:soliplex_client/src/errors/exceptions.dart';
import 'package:soliplex_client/src/http/http_transport.dart';
import 'package:soliplex_client/src/utils/cancel_token.dart';
import 'package:soliplex_client/src/utils/url_builder.dart';

/// API client for Soliplex backend CRUD operations.
///
/// Provides methods for managing rooms, threads, and runs.
/// Built on top of [HttpTransport] for JSON handling and error mapping.
///
/// Example:
/// ```dart
/// final api = SoliplexApi(
///   transport: HttpTransport(client: DartHttpClient()),
///   urlBuilder: UrlBuilder('https://api.example.com/api/v1'),
/// );
///
/// // List rooms
/// final rooms = await api.getRooms();
///
/// // Create a thread
/// final thread = await api.createThread('room-123');
/// print('Created thread: ${thread.id}');
///
/// api.close();
/// ```
class SoliplexApi {
  /// Creates an API client with the given [transport] and [urlBuilder].
  ///
  /// Parameters:
  /// - [transport]: HTTP transport for making requests
  /// - [urlBuilder]: URL builder configured with the API base URL
  /// - [onWarning]: Optional callback for warning messages (e.g., partial
  ///   failures during history loading). If not provided, warnings are silent.
  SoliplexApi({
    required HttpTransport transport,
    required UrlBuilder urlBuilder,
    void Function(String message)? onWarning,
  })  : _transport = transport,
        _urlBuilder = urlBuilder,
        _onWarning = onWarning;

  final HttpTransport _transport;
  final UrlBuilder _urlBuilder;
  final void Function(String message)? _onWarning;

  /// Maximum number of runs to cache. Covers ~5-10 threads of history.
  static const _maxCacheSize = 100;

  /// LRU cache for run events. Completed runs are immutable, so safe to cache.
  /// Uses insertion order - oldest entries are at the front.
  final _runEventsCache = <String, List<Map<String, dynamic>>>{};

  String _runCacheKey(String threadId, String runId) => '$threadId:$runId';

  /// Adds to cache with LRU eviction.
  void _cacheRunEvents(String key, List<Map<String, dynamic>> events) {
    // Remove if exists (to update position for LRU)
    _runEventsCache.remove(key);

    // Evict oldest entries if at capacity
    while (_runEventsCache.length >= _maxCacheSize) {
      _runEventsCache.remove(_runEventsCache.keys.first);
    }

    _runEventsCache[key] = events;
  }

  /// Gets from cache and updates LRU position.
  List<Map<String, dynamic>>? _getCachedRunEvents(String key) {
    final events = _runEventsCache.remove(key);
    if (events != null) {
      _runEventsCache[key] = events; // Re-add to move to end (most recent)
    }
    return events;
  }

  // ============================================================
  // Rooms
  // ============================================================

  /// Lists all available rooms.
  ///
  /// Returns a list of [Room] objects.
  ///
  /// The backend returns rooms as a map keyed by room ID. This method
  /// converts the map to a list of Room objects.
  ///
  /// Throws:
  /// - [AuthException] if not authenticated (401/403)
  /// - [NetworkException] if connection fails
  /// - [ApiException] for other server errors
  /// - [CancelledException] if cancelled via [cancelToken]
  Future<List<Room>> getRooms({CancelToken? cancelToken}) async {
    final response = await _transport.request<Map<String, dynamic>>(
      'GET',
      _urlBuilder.build(path: 'rooms'),
      cancelToken: cancelToken,
    );
    // Backend returns a map of room_id -> room object
    // Convert to list of Room objects
    return response.values
        .map((e) => roomFromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Gets a room by ID.
  ///
  /// Parameters:
  /// - [roomId]: The room ID (must not be empty)
  ///
  /// Returns the [Room] with the given ID.
  ///
  /// Throws:
  /// - [ArgumentError] if [roomId] is empty
  /// - [NotFoundException] if room not found (404)
  /// - [AuthException] if not authenticated (401/403)
  /// - [NetworkException] if connection fails
  /// - [ApiException] for other server errors
  /// - [CancelledException] if cancelled via [cancelToken]
  Future<Room> getRoom(String roomId, {CancelToken? cancelToken}) async {
    _requireNonEmpty(roomId, 'roomId');

    return _transport.request<Room>(
      'GET',
      _urlBuilder.build(pathSegments: ['rooms', roomId]),
      cancelToken: cancelToken,
      fromJson: roomFromJson,
    );
  }

  /// Gets documents available for narrowing RAG in a room.
  ///
  /// Parameters:
  /// - [roomId]: The room ID (must not be empty)
  ///
  /// Returns a list of [RagDocument] objects for the room.
  ///
  /// Throws:
  /// - [ArgumentError] if [roomId] is empty
  /// - [NotFoundException] if room not found (404)
  /// - [AuthException] if not authenticated (401/403)
  /// - [NetworkException] if connection fails
  /// - [ApiException] for other server errors
  /// - [CancelledException] if cancelled via [cancelToken]
  Future<List<RagDocument>> getDocuments(
    String roomId, {
    CancelToken? cancelToken,
  }) async {
    _requireNonEmpty(roomId, 'roomId');

    final response = await _transport.request<Map<String, dynamic>>(
      'GET',
      _urlBuilder.build(pathSegments: ['rooms', roomId, 'documents']),
      cancelToken: cancelToken,
    );

    // Backend returns {"document_set": {id: {...}, ...}} - map keyed by doc ID
    final documentSet = response['document_set'] as Map<String, dynamic>?;
    if (documentSet == null || documentSet.isEmpty) {
      return [];
    }
    return documentSet.values
        .map((e) => ragDocumentFromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ============================================================
  // Threads
  // ============================================================

  /// Lists all threads in a room.
  ///
  /// Parameters:
  /// - [roomId]: The room ID (must not be empty)
  ///
  /// Returns a list of [ThreadInfo] objects for the room.
  ///
  /// The backend returns threads wrapped in a {"threads": [...]} object.
  /// This method extracts the threads array.
  ///
  /// Throws:
  /// - [ArgumentError] if [roomId] is empty
  /// - [NotFoundException] if room not found (404)
  /// - [AuthException] if not authenticated (401/403)
  /// - [NetworkException] if connection fails
  /// - [ApiException] for other server errors
  /// - [CancelledException] if cancelled via [cancelToken]
  Future<List<ThreadInfo>> getThreads(
    String roomId, {
    CancelToken? cancelToken,
  }) async {
    _requireNonEmpty(roomId, 'roomId');

    final response = await _transport.request<Map<String, dynamic>>(
      'GET',
      _urlBuilder.build(pathSegments: ['rooms', roomId, 'agui']),
      cancelToken: cancelToken,
    );
    // Backend returns {"threads": [...]} - extract the threads array
    final threads = response['threads'] as List<dynamic>;
    return threads
        .map((e) => threadInfoFromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Gets a thread by ID.
  ///
  /// Parameters:
  /// - [roomId]: The room ID (must not be empty)
  /// - [threadId]: The thread ID (must not be empty)
  ///
  /// Returns the [ThreadInfo] with the given ID.
  ///
  /// Throws:
  /// - [ArgumentError] if [roomId] or [threadId] is empty
  /// - [NotFoundException] if thread not found (404)
  /// - [AuthException] if not authenticated (401/403)
  /// - [NetworkException] if connection fails
  /// - [ApiException] for other server errors
  /// - [CancelledException] if cancelled via [cancelToken]
  Future<ThreadInfo> getThread(
    String roomId,
    String threadId, {
    CancelToken? cancelToken,
  }) async {
    _requireNonEmpty(roomId, 'roomId');
    _requireNonEmpty(threadId, 'threadId');

    return _transport.request<ThreadInfo>(
      'GET',
      _urlBuilder.build(pathSegments: ['rooms', roomId, 'agui', threadId]),
      cancelToken: cancelToken,
      fromJson: threadInfoFromJson,
    );
  }

  /// Creates a new thread in a room.
  ///
  /// Parameters:
  /// - [roomId]: The room ID (must not be empty)
  ///
  /// Returns a [ThreadInfo] for the newly created thread.
  ///
  /// Throws:
  /// - [ArgumentError] if [roomId] is empty
  /// - [NotFoundException] if room not found (404)
  /// - [AuthException] if not authenticated (401/403)
  /// - [NetworkException] if connection fails
  /// - [ApiException] for other server errors
  /// - [CancelledException] if cancelled via [cancelToken]
  Future<ThreadInfo> createThread(
    String roomId, {
    CancelToken? cancelToken,
  }) async {
    _requireNonEmpty(roomId, 'roomId');

    final response = await _transport.request<Map<String, dynamic>>(
      'POST',
      _urlBuilder.build(pathSegments: ['rooms', roomId, 'agui']),
      body: const {
        'metadata': {'name': 'New Thread', 'description': ''},
      },
      cancelToken: cancelToken,
    );

    // Extract initial run_id from runs map
    String? initialRunId;
    final runs = response['runs'] as Map<String, dynamic>?;
    if (runs != null && runs.isNotEmpty) {
      initialRunId = runs.keys.first;
    }

    // Normalize response: backend returns thread_id, we use id
    return ThreadInfo(
      id: response['thread_id'] as String,
      roomId: roomId,
      initialRunId: initialRunId ?? '',
      createdAt: DateTime.now(),
    );
  }

  /// Deletes a thread.
  ///
  /// Parameters:
  /// - [roomId]: The room ID (must not be empty)
  /// - [threadId]: The thread ID (must not be empty)
  ///
  /// Throws:
  /// - [ArgumentError] if [roomId] or [threadId] is empty
  /// - [NotFoundException] if thread not found (404)
  /// - [AuthException] if not authenticated (401/403)
  /// - [NetworkException] if connection fails
  /// - [ApiException] for other server errors
  /// - [CancelledException] if cancelled via [cancelToken]
  Future<void> deleteThread(
    String roomId,
    String threadId, {
    CancelToken? cancelToken,
  }) async {
    _requireNonEmpty(roomId, 'roomId');
    _requireNonEmpty(threadId, 'threadId');

    await _transport.request<void>(
      'DELETE',
      _urlBuilder.build(pathSegments: ['rooms', roomId, 'agui', threadId]),
      cancelToken: cancelToken,
    );
  }

  // ============================================================
  // Runs
  // ============================================================

  /// Creates a new run in a thread.
  ///
  /// Parameters:
  /// - [roomId]: The room ID (must not be empty)
  /// - [threadId]: The thread ID (must not be empty)
  ///
  /// Returns a [RunInfo] for the newly created run.
  ///
  /// Throws:
  /// - [ArgumentError] if [roomId] or [threadId] is empty
  /// - [NotFoundException] if thread not found (404)
  /// - [AuthException] if not authenticated (401/403)
  /// - [NetworkException] if connection fails
  /// - [ApiException] for other server errors
  /// - [CancelledException] if cancelled via [cancelToken]
  Future<RunInfo> createRun(
    String roomId,
    String threadId, {
    CancelToken? cancelToken,
  }) async {
    _requireNonEmpty(roomId, 'roomId');
    _requireNonEmpty(threadId, 'threadId');

    final response = await _transport.request<Map<String, dynamic>>(
      'POST',
      _urlBuilder.build(pathSegments: ['rooms', roomId, 'agui', threadId]),
      body: <String, dynamic>{},
      cancelToken: cancelToken,
    );

    // Normalize response: backend returns run_id, we use id
    return RunInfo(
      id: response['run_id'] as String,
      threadId: threadId,
      createdAt: DateTime.now(),
    );
  }

  /// Gets a run by ID.
  ///
  /// Parameters:
  /// - [roomId]: The room ID (must not be empty)
  /// - [threadId]: The thread ID (must not be empty)
  /// - [runId]: The run ID (must not be empty)
  ///
  /// Returns the [RunInfo] with the given ID.
  ///
  /// Throws:
  /// - [ArgumentError] if any ID is empty
  /// - [NotFoundException] if run not found (404)
  /// - [AuthException] if not authenticated (401/403)
  /// - [NetworkException] if connection fails
  /// - [ApiException] for other server errors
  /// - [CancelledException] if cancelled via [cancelToken]
  Future<RunInfo> getRun(
    String roomId,
    String threadId,
    String runId, {
    CancelToken? cancelToken,
  }) async {
    _requireNonEmpty(roomId, 'roomId');
    _requireNonEmpty(threadId, 'threadId');
    _requireNonEmpty(runId, 'runId');

    return _transport.request<RunInfo>(
      'GET',
      _urlBuilder.build(
        pathSegments: ['rooms', roomId, 'agui', threadId, runId],
      ),
      cancelToken: cancelToken,
      fromJson: runInfoFromJson,
    );
  }

  // ============================================================
  // Messages
  // ============================================================

  /// Fetches historical messages for a thread by replaying stored events.
  ///
  /// Parameters:
  /// - [roomId]: The room ID (must not be empty)
  /// - [threadId]: The thread ID (must not be empty)
  ///
  /// Returns a list of [ChatMessage] reconstructed from stored AG-UI events.
  /// Messages are ordered chronologically (oldest first) based on run creation
  /// time.
  ///
  /// This method fetches events from individual run endpoints in parallel,
  /// caches them (completed runs are immutable), and replays them to
  /// reconstruct the message history.
  ///
  /// Throws:
  /// - [ArgumentError] if [roomId] or [threadId] is empty
  /// - [NotFoundException] if thread not found (404)
  /// - [AuthException] if not authenticated (401/403)
  /// - [NetworkException] if connection fails
  /// - [ApiException] for other server errors
  /// - [CancelledException] if cancelled via [cancelToken]
  Future<List<ChatMessage>> getThreadMessages(
    String roomId,
    String threadId, {
    CancelToken? cancelToken,
  }) async {
    _requireNonEmpty(roomId, 'roomId');
    _requireNonEmpty(threadId, 'threadId');

    // 1. Get thread to list runs
    final response = await _transport.request<Map<String, dynamic>>(
      'GET',
      _urlBuilder.build(pathSegments: ['rooms', roomId, 'agui', threadId]),
      cancelToken: cancelToken,
    );

    final runs = response['runs'] as Map<String, dynamic>? ?? {};
    if (runs.isEmpty) return [];

    // 2. Get completed run IDs sorted by creation time
    final completedRunIds = _sortRunsByCreationTime(runs)
        .where((e) => (e.value as Map<String, dynamic>)['finished'] != null)
        .map((e) => (e.value as Map<String, dynamic>)['run_id'] as String)
        .toList();

    if (completedRunIds.isEmpty) return [];

    // 3. Fetch all run events in parallel (cache handles duplicates)
    final eventFutures = completedRunIds.map((runId) {
      return _fetchRunEvents(roomId, threadId, runId, cancelToken: cancelToken)
          .then((events) => (runId: runId, events: events))
          .catchError(
        (Object e) {
          // Log transient failure but continue with other runs
          _onWarning?.call('Failed to fetch events for run $runId: $e');
          return (runId: runId, events: <Map<String, dynamic>>[]);
        },
        // Only catch transient errors - show partial results for batch ops:
        // - NetworkException: network blip, retry might succeed
        // - NotFoundException: run deleted between list and fetch (race)
        // Let ApiException propagate - systemic problem (500, 429, 400)
        test: (e) => e is NetworkException || e is NotFoundException,
      );
    });

    final results = await Future.wait(eventFutures);

    // 4. Collect events in run order (results may arrive out of order)
    final runIdToEvents = {for (final r in results) r.runId: r.events};
    final allEvents = <Map<String, dynamic>>[];
    for (final runId in completedRunIds) {
      allEvents.addAll(runIdToEvents[runId] ?? []);
    }

    // 5. Replay events to reconstruct messages
    return _replayEventsToMessages(allEvents, threadId);
  }

  /// Fetches events for a single run, using cache for completed runs.
  ///
  /// Returns events including synthetic user message events extracted from
  /// run_input.messages. The backend stores user input separately from
  /// streamed events, so we synthesize TEXT_MESSAGE events for them.
  Future<List<Map<String, dynamic>>> _fetchRunEvents(
    String roomId,
    String threadId,
    String runId, {
    CancelToken? cancelToken,
  }) async {
    final cacheKey = _runCacheKey(threadId, runId);
    final cached = _getCachedRunEvents(cacheKey);
    if (cached != null) return cached;

    final rawRun = await _transport.request<Map<String, dynamic>>(
      'GET',
      _urlBuilder.build(
        pathSegments: ['rooms', roomId, 'agui', threadId, runId],
      ),
      cancelToken: cancelToken,
    );

    // Extract user messages from run_input and create synthetic events
    final userMessageEvents = _extractUserMessageEvents(rawRun);

    final events =
        (rawRun['events'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

    // Combine: user message events first, then actual streamed events
    final allEvents = [...userMessageEvents, ...events];
    _cacheRunEvents(cacheKey, allEvents);
    return allEvents;
  }

  /// Extracts user messages from run_input and creates synthetic events.
  List<Map<String, dynamic>> _extractUserMessageEvents(
    Map<String, dynamic> rawRun,
  ) {
    final runInput = rawRun['run_input'] as Map<String, dynamic>?;
    if (runInput == null) return [];

    final messages = runInput['messages'] as List<dynamic>? ?? [];
    final syntheticEvents = <Map<String, dynamic>>[];

    for (var i = 0; i < messages.length; i++) {
      final raw = messages[i];
      if (raw is! Map<String, dynamic>) continue; // Skip malformed entries
      final msgMap = raw;
      final role = msgMap['role'] as String? ?? 'user';

      // Only process user messages - assistant messages come from events
      if (role != 'user') continue;

      final id = msgMap['id'] as String? ?? 'user-$i';
      final content = msgMap['content'] as String? ?? '';

      // Create synthetic TEXT_MESSAGE events (START, CONTENT, END)
      syntheticEvents
        ..add({
          'type': 'TEXT_MESSAGE_START',
          'messageId': id,
          'role': role,
        })
        ..add({
          'type': 'TEXT_MESSAGE_CONTENT',
          'messageId': id,
          'delta': content,
        })
        ..add({'type': 'TEXT_MESSAGE_END', 'messageId': id});
    }

    return syntheticEvents;
  }

  /// Replays events to reconstruct messages.
  List<ChatMessage> _replayEventsToMessages(
    List<Map<String, dynamic>> events,
    String threadId,
  ) {
    if (events.isEmpty) return [];

    var conversation = Conversation.empty(threadId: threadId);
    var streaming = const AwaitingText() as StreamingState;
    const decoder = EventDecoder();
    var skippedEventCount = 0;

    for (final eventJson in events) {
      try {
        final event = decoder.decodeJson(eventJson);
        final result = processEvent(conversation, streaming, event);
        conversation = result.conversation;
        streaming = result.streaming;
      } on DecodeError {
        // Skip malformed events - don't fail entire history for one bad
        // event. This can happen if the backend stores events from a newer
        // protocol version or if data corruption occurs.
        skippedEventCount++;
        assert(
          () {
            // ignore: avoid_print
            print('Skipped malformed event during replay: $eventJson');
            return true;
          }(),
          'Debug logging for malformed events',
        );
      }
    }

    if (skippedEventCount > 0) {
      _onWarning?.call(
        'Skipped $skippedEventCount malformed event(s) '
        'while loading thread $threadId',
      );
    }

    return conversation.messages;
  }

  /// Sorts runs by creation time (oldest first).
  List<MapEntry<String, dynamic>> _sortRunsByCreationTime(
    Map<String, dynamic> runs,
  ) {
    return runs.entries.toList()
      ..sort((a, b) {
        final aData = a.value as Map<String, dynamic>;
        final bData = b.value as Map<String, dynamic>;
        final aCreated = aData['created'] as String?;
        final bCreated = bData['created'] as String?;

        if (aCreated == null && bCreated == null) return 0;
        if (aCreated == null) return 1;
        if (bCreated == null) return -1;

        // Use tryParse to handle malformed timestamps gracefully
        final epoch = DateTime.fromMillisecondsSinceEpoch(0);
        final aTime = DateTime.tryParse(aCreated) ?? epoch;
        final bTime = DateTime.tryParse(bCreated) ?? epoch;
        return aTime.compareTo(bTime);
      });
  }

  // ============================================================
  // Quizzes
  // ============================================================

  /// Gets a quiz by ID.
  ///
  /// Parameters:
  /// - [roomId]: The room ID (must not be empty)
  /// - [quizId]: The quiz ID (must not be empty)
  ///
  /// Returns the [Quiz] with the given ID.
  ///
  /// Throws:
  /// - [ArgumentError] if [roomId] or [quizId] is empty
  /// - [NotFoundException] if quiz not found (404)
  /// - [AuthException] if not authenticated (401/403)
  /// - [NetworkException] if connection fails
  /// - [ApiException] for other server errors
  /// - [CancelledException] if cancelled via [cancelToken]
  Future<Quiz> getQuiz(
    String roomId,
    String quizId, {
    CancelToken? cancelToken,
  }) async {
    _requireNonEmpty(roomId, 'roomId');
    _requireNonEmpty(quizId, 'quizId');

    return _transport.request<Quiz>(
      'GET',
      _urlBuilder.build(pathSegments: ['rooms', roomId, 'quiz', quizId]),
      cancelToken: cancelToken,
      fromJson: quizFromJson,
    );
  }

  /// Submits an answer for a quiz question.
  ///
  /// Parameters:
  /// - [roomId]: The room ID (must not be empty)
  /// - [quizId]: The quiz ID (must not be empty)
  /// - [questionId]: The question UUID (must not be empty)
  /// - [answer]: The user's answer text
  ///
  /// Returns a [QuizAnswerResult] indicating if the answer was correct.
  ///
  /// Throws:
  /// - [ArgumentError] if any ID is empty
  /// - [NotFoundException] if quiz or question not found (404)
  /// - [AuthException] if not authenticated (401/403)
  /// - [NetworkException] if connection fails
  /// - [ApiException] for other server errors
  /// - [CancelledException] if cancelled via [cancelToken]
  Future<QuizAnswerResult> submitQuizAnswer(
    String roomId,
    String quizId,
    String questionId,
    String answer, {
    CancelToken? cancelToken,
  }) async {
    _requireNonEmpty(roomId, 'roomId');
    _requireNonEmpty(quizId, 'quizId');
    _requireNonEmpty(questionId, 'questionId');

    return _transport.request<QuizAnswerResult>(
      'POST',
      _urlBuilder.build(
        pathSegments: ['rooms', roomId, 'quiz', quizId, questionId],
      ),
      body: {'text': answer},
      cancelToken: cancelToken,
      fromJson: quizAnswerResultFromJson,
    );
  }

  // ============================================================
  // Installation Info
  // ============================================================

  /// Gets backend version information.
  ///
  /// Returns [BackendVersionInfo] containing the soliplex version
  /// and all installed package versions.
  ///
  /// Throws:
  /// - [NetworkException] if connection fails
  /// - [ApiException] for server errors
  /// - [CancelledException] if cancelled via [cancelToken]
  Future<BackendVersionInfo> getBackendVersionInfo({
    CancelToken? cancelToken,
  }) async {
    final response = await _transport.request<Map<String, dynamic>>(
      'GET',
      _urlBuilder.build(pathSegments: ['installation', 'versions']),
      cancelToken: cancelToken,
    );

    return backendVersionInfoFromJson(response);
  }

  // ============================================================
  // Lifecycle
  // ============================================================

  /// Closes the API client and releases resources.
  ///
  /// After calling this method, no further requests should be made.
  void close() {
    _runEventsCache.clear();
    _transport.close();
  }

  // ============================================================
  // Private helpers
  // ============================================================

  /// Validates that a string value is not empty.
  void _requireNonEmpty(String value, String name) {
    if (value.isEmpty) {
      throw ArgumentError.value(value, name, 'must not be empty');
    }
  }
}
