# Feature 13: Workflow Automations (Shortcuts)

## Usage
Users can bind a prompt to a Siri Shortcut or Quick Setting tile. e.g., "Summarize last email" or "Daily Standup".

## Specification
- **Platform Channels:** `quick_actions` or `receive_intent`.
- **Deep Linking:** URL schemes to trigger specific prompts.

## Skeleton Code

```dart
final QuickActions quickActions = const QuickActions();

void init() {
  quickActions.setShortcutItems(<ShortcutItem>[
    const ShortcutItem(type: 'action_summarize', localizedTitle: 'Summarize Clipboard'),
  ]);

  quickActions.initialize((String type) {
    if (type == 'action_summarize') {
       // Read clipboard, send to chat
    }
  });
}
```

## Reviews

### Codex Review (Technical)
**Completeness:** High.
**Feasibility:** High.
**Novelty:** Medium.

### Skeptic Review (Product)
**Critique:** Increases retention/stickiness. Makes the app part of the OS.
