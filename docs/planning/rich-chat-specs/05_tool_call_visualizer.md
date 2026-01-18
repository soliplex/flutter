# Feature Specification: Client-Side Tool Call Visualizer

## 1. Overview
The **Tool Call Visualizer** renders the "actions" the agent is taking (e.g., "Searching Google", "Querying Database", "Calculating") as distinct UI elements in the chat stream. This exposes the "Agentic" nature of the system via AG-UI events.

## 2. Business Case
- **Latency Masking:** Agent operations can take 5-10 seconds. A spinner is boring; showing "Searching for 'Annual Report'..." keeps the user engaged and patient.
- **Debuggability:** If the agent fails, the user sees *which* tool failed (e.g., "Weather API Error").
- **Control:** Allows for potential "Human-in-the-loop" intervention (e.g., Cancel a tool call).

## 3. UI/UX Specification
- **State: In Progress**
    - A slim card or inline status line.
    - Spinner icon + "Action: [Tool Name] - [Input Summary]".
    - *Example:* ⟳ "Searching documentation for 'auth'..."
- **State: Completed (Success)**
    - Icon turns to green checkmark.
    - Collapsed by default.
    - Click to expand and see "Output" (JSON/Text).
- **State: Completed (Error)**
    - Icon turns to red warning.
    - Text: "Error in [Tool Name]".
    - Auto-expanded to show error message.

## 4. Technical Implementation

### AG-UI Integration
This relies heavily on the `ActiveRunState` and `ToolCallBuffer`.

```dart
// Data model from AG-UI
class ToolCallEvent {
  final String id;
  final String toolName;
  final Map<String, dynamic> args;
  final ToolStatus status; // distinct from streaming status
  final String? result;
}

// Widget
class ToolExecutionTile extends StatelessWidget {
  final ToolCallEvent event;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: _getColor(event.status), width: 3)),
        color: Colors.grey.shade50,
      ),
      child: ExpansionTile(
        leading: _getIcon(event.status),
        title: Text(event.toolName, style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(_formatArgs(event.args), maxLines: 1, overflow: TextOverflow.ellipsis),
        children: [
          if (event.result != null)
             Padding(padding: EdgeInsets.all(8), child: Text(event.result!))
        ],
      ),
    );
  }
}
```

## 5. Codex Review
- **Refinement:** Don't show *raw* JSON arguments to non-technical users. Use a "descriptor" field if available (e.g., `tool_display_name: "Searching Web"`).
- **Security:** Be careful showing tool outputs that might contain raw API keys or PII if the agent echoes them. Sanitize outputs.

## 6. Skeptic Review
- "This breaks the conversation flow." -> **Mitigation:** These should be "ephemeral" or visually distinct (smaller font, grayed out) so they don't look like chat messages.
- "Too much noise." -> **Mitigation:** Group sequential tool calls into a single "Processing..." block that expands to show details.
