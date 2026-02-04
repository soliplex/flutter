# 20 - Quiz Feature

## Overview

Interactive quiz system with state machine-based session management. Supports
multiple choice, fill-in-blank, and free-form questions with answer validation
and results tracking.

## Files

| File | Purpose |
|------|---------|
| `lib/core/providers/quiz_provider.dart` | Quiz data and session state |
| `lib/features/quiz/quiz_screen.dart` | Quiz UI |

## Public API

### Providers (quiz_provider.dart)

| Provider | Type | Purpose |
|----------|------|---------|
| `quizProvider` | `FutureProvider.family` | Fetches Quiz metadata |
| `quizSessionProvider` | `NotifierProvider.family` | Session state manager |

### QuizSessionNotifier Methods

- `start(Quiz)` - Initialize session to `QuizInProgress`
- `updateInput(QuizInput)` - Update current answer draft
- `clearInput()` - Reset current input
- `submitAnswer()` - Submit and validate answer
- `nextQuestion()` - Advance to next question or completion
- `reset()` - Revert to `QuizNotStarted`
- `retake()` - Restart quiz from beginning

### State Models (sealed)

**`QuizInput`:**

- `MultipleChoiceInput` - Selected option index
- `TextInput` - Text answer content

**`QuestionState`:**

- `AwaitingInput` - Fresh question
- `Composing` - User entering answer
- `Submitting` - API call in progress
- `Answered` - Result received

**`QuizSession`:**

- `QuizNotStarted` - Initial state
- `QuizInProgress` - Active session with questions
- `QuizCompleted` - All questions answered

### Screen (quiz_screen.dart)

**`QuizScreen`** - Main quiz UI widget

- `roomId`, `quizId` - Required parameters
- Builds UI based on `QuizSession` state
- Manages TextEditingController sync with provider

## Dependencies

### External Packages

- `flutter_riverpod` - State management
- `go_router` - Navigation
- `soliplex_client` - Domain models

### Internal Dependencies

| Domain | Imports |
|--------|---------|
| Core/Providers | `api_provider`, `shell_config_provider` |
| Shared | `AppShell`, `ErrorDisplay`, `LoadingIndicator` |
| Design | `SoliplexSpacing`, `SoliplexTheme` |

## Quiz Flow

```text
1. QuizScreen initialized with roomId, quizId
2. quizProvider fetches Quiz metadata
3. User clicks "Start Quiz" → notifier.start(quiz)
4. Interaction loop:
   ├─ User input → notifier.updateInput
   ├─ Submit → notifier.submitAnswer → API call
   └─ Next → notifier.nextQuestion
5. Last question answered → QuizCompleted
6. Results displayed with retake option
```

## Architectural Patterns

### Finite State Machines

Sealed classes enforce valid state transitions at compile time.

### Family Providers

State isolated per `(roomId, quizId)` tuple.

### Unidirectional Data Flow

UI reads state, calls notifier methods, notifier updates state, UI rebuilds.

### Optimistic/Revert Updates

`submitAnswer` transitions to Submitting immediately, reverts on error.

## Cross-Component Dependencies

### Depends On

- **03 - State Core**: API provider access
- **10 - Configuration**: Feature configuration
- **11 - Design System**: Theme and styling tokens
- **12 - Shared Widgets**: Common UI components
- **14 - HTTP Layer**: Client integration via barrel file

### Used By

- **19 - Router**: Navigation target

## Contribution Guidelines

### DO

- **Use Sealed Classes for State:** Always use `sealed` class hierarchies (`QuizSession`, `QuestionState`) to force exhaustive pattern matching in the UI. This prevents "impossible state" bugs.
- **Isolate State via Family:** Always access quiz providers with the `({roomId, quizId})` tuple. Never create a singleton "current quiz" provider.
- **Sync Controllers from State:** In `build()`, explicitly sync `TextEditingController.text` with the provider state (`TextInput`). The Provider is the source of truth; the controller is just a UI implementation detail.
- **Handle Logic in Notifier:** All submission logic, validation, and API calls must reside in `QuizSessionNotifier`. The UI only calls notifier methods.
- **Use Optimistic UI with Revert:** When submitting, transition to `Submitting` immediately. If the API fails, catch the error and revert to `Composing` (preserving the user's input).

### DON'T

- **No Split Logic:** Do not put "next question" logic or "score calculation" inside `QuizScreen`. Keep it in the Notifier.
- **Don't Pass `WidgetRef` to Logic:** The `QuizSessionNotifier` methods must not accept `WidgetRef` or `BuildContext`. Return values or throw exceptions to let the UI handle side effects.
- **No Manual State Mutation:** Never modify `currentIndex` or `results` directly. Use defined actions (`nextQuestion`, `updateInput`) to ensure valid State Machine transitions.
- **Don't Forget Error Handling:** Do not swallow API errors in the Notifier. Rethrow them so the UI can show specific error messages (Retry button, Auth expiration).
- **Avoid Fat Widgets:** Extract sub-views (e.g., `_MultipleChoiceView`, `_ResultsView`) into separate files if they exceed 100 lines.

### Extending This Component

- **New Question Types:** Add the type to `QuizQuestion` (client package), add a corresponding `QuizInput` subclass, update `QuizSessionNotifier.updateInput`, and add a build method in `QuizScreen`.
- **New Session States:** If adding a "Timed Quiz" mode, extend `QuizInProgress` or add a wrapping state, ensuring the sealed class hierarchy remains exhaustive.
- **Persistence:** If saving progress locally, implement it inside `QuizSessionNotifier` by listening to state changes, strictly avoiding logic leaks into the UI layer.
