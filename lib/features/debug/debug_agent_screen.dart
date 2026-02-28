// TEMPORARY: Debug agent screen — remove after F1 validation.
// Cleanup: git rm -rf lib/features/debug/

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soliplex_agent/soliplex_agent.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_frontend/core/providers/agent_run_provider.dart';
import 'package:soliplex_frontend/core/providers/api_provider.dart';
import 'package:soliplex_frontend/core/providers/rooms_provider.dart';
import 'package:soliplex_frontend/core/providers/threads_provider.dart';

class DebugAgentScreen extends ConsumerStatefulWidget {
  const DebugAgentScreen({super.key});

  @override
  ConsumerState<DebugAgentScreen> createState() => _DebugAgentScreenState();
}

class _DebugAgentScreenState extends ConsumerState<DebugAgentScreen> {
  String? _selectedRoomId;
  String? _selectedThreadId;
  final _messageController = TextEditingController();
  bool _isCreatingThread = false;
  final List<String> _eventLog = [];

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<RunState>(agentRunProvider, (previous, next) {
      final prevName = previous?.runtimeType.toString() ?? '?';
      final nextName = next.runtimeType.toString();
      final now = DateTime.now();
      final ts = '${now.hour.toString().padLeft(2, '0')}:'
          '${now.minute.toString().padLeft(2, '0')}:'
          '${now.second.toString().padLeft(2, '0')}';
      setState(() {
        _eventLog.add('$ts $prevName \u2192 $nextName');
      });
    });

    final runState = ref.watch(agentRunProvider);
    final roomsAsync = ref.watch(roomsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            color: Colors.amber.shade100,
            child: const Text(
              '\u26A0 TEMPORARY SCAFFOLDING \u2014 remove after F1 validation',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 16),
          _buildRoomDropdown(roomsAsync),
          const SizedBox(height: 8),
          _buildThreadRow(),
          const Divider(height: 32),
          _buildStateIndicator(runState),
          const Divider(height: 32),
          _buildMessageInput(runState),
          const SizedBox(height: 8),
          _buildActionButtons(runState),
          const Divider(height: 32),
          _buildConversationLog(runState),
          const Divider(height: 32),
          _buildEventLog(),
        ],
      ),
    );
  }

  // -- Room dropdown --------------------------------------------------------

  Widget _buildRoomDropdown(AsyncValue<List<Room>> roomsAsync) {
    return roomsAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('Error loading rooms: $e'),
      data: (rooms) => DropdownButtonFormField<String>(
        initialValue: _selectedRoomId,
        decoration: const InputDecoration(
          labelText: 'Room',
          border: OutlineInputBorder(),
        ),
        items: rooms
            .map(
              (r) => DropdownMenuItem(value: r.id, child: Text(r.name)),
            )
            .toList(),
        onChanged: (value) {
          setState(() {
            _selectedRoomId = value;
            _selectedThreadId = null;
          });
          ref.read(agentRunProvider.notifier).reset();
        },
      ),
    );
  }

  // -- Thread dropdown + New Thread -----------------------------------------

  Widget _buildThreadRow() {
    final roomId = _selectedRoomId;
    if (roomId == null) return const Text('Select a room first.');

    final threadsAsync = ref.watch(threadsProvider(roomId));
    return Row(
      children: [
        Expanded(
          child: threadsAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Error loading threads: $e'),
            data: (threads) => DropdownButtonFormField<String>(
              initialValue: _selectedThreadId,
              decoration: const InputDecoration(
                labelText: 'Thread',
                border: OutlineInputBorder(),
              ),
              items: threads
                  .map(
                    (t) => DropdownMenuItem(
                      value: t.id,
                      child: Text(t.hasName ? t.name : t.id),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _selectedThreadId = value),
            ),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: _isCreatingThread ? null : _createThread,
          icon: _isCreatingThread
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add),
          label: const Text('New Thread'),
        ),
      ],
    );
  }

  Future<void> _createThread() async {
    final roomId = _selectedRoomId;
    if (roomId == null) return;

    setState(() => _isCreatingThread = true);
    try {
      final api = ref.read(apiProvider);
      final (threadInfo, _) = await api.createThread(roomId);
      ref.invalidate(threadsProvider(roomId));
      if (mounted) setState(() => _selectedThreadId = threadInfo.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create thread: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreatingThread = false);
    }
  }

  // -- State indicator ------------------------------------------------------

  Widget _buildStateIndicator(RunState runState) {
    final (label, color) = switch (runState) {
      IdleState() => ('Idle', Colors.grey),
      RunningState() => ('Running', Colors.blue),
      ToolYieldingState() => ('ToolYielding', Colors.orange),
      CompletedState() => ('Completed', Colors.green),
      FailedState() => ('Failed', Colors.red),
      CancelledState() => ('Cancelled', Colors.amber),
    };

    final runId = switch (runState) {
      RunningState(:final runId) => runId,
      CompletedState(:final runId) => runId,
      ToolYieldingState(:final runId) => runId,
      _ => null,
    };

    final threadKey = switch (runState) {
      RunningState(:final threadKey) => threadKey,
      CompletedState(:final threadKey) => threadKey,
      ToolYieldingState(:final threadKey) => threadKey,
      FailedState(:final threadKey) => threadKey,
      CancelledState(:final threadKey) => threadKey,
      _ => null,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'State: ',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Chip(
              label: Text(label),
              backgroundColor: color.withAlpha(51),
              side: BorderSide(color: color),
            ),
          ],
        ),
        if (runId != null) Text('RunId: $runId'),
        if (threadKey != null) Text('ThreadId: ${threadKey.threadId}'),
        if (runState is FailedState)
          Text(
            'Error: ${runState.error}',
            style: const TextStyle(color: Colors.red),
          ),
        if (runState is ToolYieldingState)
          Text('Tool depth: ${runState.toolDepth}'),
      ],
    );
  }

  // -- Message input --------------------------------------------------------

  Widget _buildMessageInput(RunState runState) {
    final isRunning = runState is RunningState || runState is ToolYieldingState;
    final canSend =
        _selectedRoomId != null && _selectedThreadId != null && !isRunning;

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _messageController,
            decoration: const InputDecoration(
              hintText: 'Enter message...',
              border: OutlineInputBorder(),
            ),
            onSubmitted: canSend ? (_) => _sendMessage() : null,
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: canSend ? _sendMessage : null,
          child: const Text('Send'),
        ),
      ],
    );
  }

  void _sendMessage() {
    final roomId = _selectedRoomId;
    final threadId = _selectedThreadId;
    final message = _messageController.text.trim();
    if (roomId == null || threadId == null || message.isEmpty) return;

    _messageController.clear();
    ref.read(agentRunProvider.notifier).startRun(
          roomId: roomId,
          threadId: threadId,
          userMessage: message,
        );
  }

  // -- Cancel / Reset -------------------------------------------------------

  Widget _buildActionButtons(RunState runState) {
    final isRunning = runState is RunningState || runState is ToolYieldingState;
    final isIdle = runState is IdleState;

    return Row(
      children: [
        ElevatedButton(
          onPressed: isRunning
              ? () => ref.read(agentRunProvider.notifier).cancelRun()
              : null,
          child: const Text('Cancel'),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed:
              isIdle ? null : () => ref.read(agentRunProvider.notifier).reset(),
          child: const Text('Reset'),
        ),
      ],
    );
  }

  // -- Conversation log -----------------------------------------------------

  Widget _buildConversationLog(RunState runState) {
    final conversation = switch (runState) {
      RunningState(:final conversation) => conversation,
      CompletedState(:final conversation) => conversation,
      ToolYieldingState(:final conversation) => conversation,
      FailedState(:final conversation) => conversation,
      CancelledState(:final conversation) => conversation,
      _ => null,
    };

    if (conversation == null) return const Text('No conversation yet.');

    final messages = conversation.messages;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Conversation (${messages.length} messages):',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...messages.map(_buildMessageTile),
      ],
    );
  }

  Widget _buildMessageTile(ChatMessage message) {
    final (icon, role, text) = switch (message) {
      TextMessage(:final user, :final text) => (
          user == ChatUser.user ? Icons.person : Icons.smart_toy,
          user.name,
          text,
        ),
      ErrorMessage(:final errorText) => (
          Icons.error,
          'system',
          errorText,
        ),
      ToolCallMessage(:final toolCalls) => (
          Icons.build,
          'tool',
          toolCalls.map((t) => '${t.name} \u2192 ${t.status.name}').join(', '),
        ),
      GenUiMessage(:final widgetName) => (
          Icons.widgets,
          'genui',
          widgetName,
        ),
      LoadingMessage() => (Icons.hourglass_empty, 'loading', '...'),
    };

    return ListTile(
      dense: true,
      leading: Icon(icon, size: 20),
      title: Text('$role: $text'),
    );
  }

  // -- Event log ------------------------------------------------------------

  Widget _buildEventLog() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Event Log:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          height: 150,
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(4),
          ),
          child: _eventLog.isEmpty
              ? const Center(child: Text('No events yet'))
              : ListView.builder(
                  itemCount: _eventLog.length,
                  padding: const EdgeInsets.all(8),
                  itemBuilder: (_, i) => Text(
                    _eventLog[i],
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
