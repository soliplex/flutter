import 'package:nocterm/nocterm.dart';
import 'package:soliplex_agent/soliplex_agent.dart' hide State;

import 'package:soliplex_tui/src/signal_builder.dart';

/// Side pane showing live status of all tracked agent sessions.
///
/// Each session renders as a card with state indicator, session ID, depth,
/// and elapsed time. Listens to [AgentSession.sessionState] for live updates.
class SubagentPane extends StatelessComponent {
  const SubagentPane({required this.sessions, super.key});

  final List<AgentSession> sessions;

  @override
  Component build(BuildContext context) {
    final theme = TuiTheme.of(context);

    return Container(
      color: theme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Text(
              'Sessions (${sessions.length})',
              style: TextStyle(color: theme.warning),
            ),
          ),
          Expanded(
            child: sessions.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: Text(
                      'No active sessions',
                      style: TextStyle(color: theme.onSurface.withOpacity(0.5)),
                    ),
                  )
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final session in sessions)
                          _SessionCard(session: session),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessComponent {
  const _SessionCard({required this.session});

  final AgentSession session;

  @override
  Component build(BuildContext context) {
    return SignalBuilder<AgentSessionState>(
      signal: session.sessionState,
      builder: (context, state) {
        final theme = TuiTheme.of(context);
        final indicator = _stateIndicator(state);
        final color = _stateColor(theme, state);

        // Truncate session ID for display.
        final shortId = session.id.length > 16
            ? session.id.substring(0, 16)
            : session.id;

        final depthLabel = session.depth > 0 ? ' d${session.depth}' : '';

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1),
          child: Text(
            '$indicator $shortId$depthLabel',
            style: TextStyle(color: color),
          ),
        );
      },
    );
  }

  static String _stateIndicator(AgentSessionState state) {
    return switch (state) {
      AgentSessionState.spawning => '~',
      AgentSessionState.running => '>',
      AgentSessionState.completed => '+',
      AgentSessionState.failed => '!',
      AgentSessionState.cancelled => 'x',
    };
  }

  static Color _stateColor(TuiThemeData theme, AgentSessionState state) {
    return switch (state) {
      AgentSessionState.spawning => theme.onSurface.withOpacity(0.5),
      AgentSessionState.running => theme.primary,
      AgentSessionState.completed => theme.success,
      AgentSessionState.failed => theme.error,
      AgentSessionState.cancelled => theme.onSurface.withOpacity(0.5),
    };
  }
}
