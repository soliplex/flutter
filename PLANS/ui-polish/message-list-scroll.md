# Message list scroll behavior

**Branch:** `fix/scroll`
**Commit:** `6dcdc1b650a`
**Status:** Implemented

## Scroll-to-top on send

### Problem

When the user sends a message, the list auto-scrolled to the bottom, potentially
pushing the user's message out of view. During long streaming responses the user
couldn't see what they asked.

### Solution

On send, the user's message is positioned at the viewport top. A dynamic
trailing spacer fills the remaining viewport so the message can reach that
position, then shrinks as streaming content grows below it. Normal scrolling
resumes once content fills the viewport.

### How it works

Three cooperating mechanisms: trigger detection, scroll-to-target
positioning, and a dynamic trailing spacer.

#### Trigger detection (in `_buildMessageList()`)

Scroll is triggered in `_buildMessageList()` — not a listener — so that
`_spacerHeight` is guaranteed fresh and the target message is guaranteed
in the display list. The trigger fires when:

- `runState` is `RunningState`
- No scroll sequence is already in-flight (`_scrollToTargetScheduled`)
- The last user message in `runState.messages` hasn't been scrolled to yet
  (`_lastScrolledMessageId`)
- That message exists in the merged display list

Three fields coordinate the sequence:

| Field | Purpose | Lifecycle |
|---|---|---|
| `_lastScrolledMessageId` | Prevents re-trigger for same message across rebuilds | Set once per message, never cleared during the run |
| `_scrollTargetMessageId` | Controls which item gets the `GlobalKey` in `itemBuilder` | Cleared when positioning completes |
| `_scrollToTargetScheduled` | Guards against concurrent scroll sequences | True while sequence is in-flight |

#### Scroll-to-target (`_scrollToTarget()`)

Uses `RenderAbstractViewport.getOffsetToReveal(renderObject, 0.0)` to
compute the exact scroll offset that places the target at alignment 0.0
(viewport top).

**Retry logic:** `ListView.builder` only builds visible items. If the
target widget hasn't been built yet, its `GlobalKey.currentContext` is
null. The retry loop:

1. Jumps to content bottom (`maxScrollExtent - _spacerHeight`), which
   forces ListView to build items near the end including the target.
2. On the next frame, checks if the target's context is now available.
3. If yes → `_jumpToReveal()` positions precisely, done.
4. If no → re-jumps to content bottom (which may have shifted because
   ListView recalculates extent estimates as it builds new items) and
   retries. Up to 3 retries.

The re-jump on each retry is important: `maxScrollExtent` can shift
dramatically between frames as ListView replaces estimated extents with
actual measured extents for newly-built items.

`_jumpToReveal()` records `_targetScrollOffset` which the spacer uses.

#### Dynamic trailing spacer (`_computeSpacerHeight()`)

A `SizedBox` appended after the last message. Its height determines how
far past the real content the user can scroll. Also used by the
scroll-to-bottom button to compute content bottom.

Three modes:

- **No spacer needed** (`!isStreaming && lastMessage != user`): returns 0,
  clears `_targetScrollOffset`. This is the steady state after a completed
  response.
- **Before positioning** (`_targetScrollOffset == null`): returns full
  `viewportHeight`. This gives the scroll-to-target room to place the
  user message at the top even when there's little content below it.
- **After positioning** (`_targetScrollOffset != null`): dynamically
  shrinks as streaming content grows below the user message:

  ```text
  realContent = maxScrollExtent + viewportDimension - spacerHeight
  spacer = clamp(targetOffset + viewportDimension - realContent, 0, viewportHeight)
  ```

  This keeps `maxScrollExtent ≈ targetOffset` (so the user message stays
  pinned at top) until the streaming response fills the viewport, at which
  point spacer drops to 0 and normal scrolling resumes.

#### Initial load (`initState`)

On first data load, jumps to content bottom (latest messages visible).
Skips this jump if `_scrollTargetMessageId` is already set (a send happened
before data loaded — the scroll-to-target sequence takes priority).

### Known limitations

- Uses `jumpTo` (instant), not `animateTo`. Animation was avoided because
  the multi-frame retry sequence would fight with an in-progress animation.
- The 3-retry limit is a heuristic. With very long message histories and
  slow devices, ListView extent estimation could take more frames to
  converge.
- No test coverage for the positioning itself (requires enough messages to
  overflow the viewport + RunningState with user messages — hard to set up
  reliably in widget tests with estimated extents).

## Scroll-to-bottom button

### Problem

When the user scrolls up to review earlier messages during a streaming
response, there's no easy way to jump back to the latest content.

### Solution

A floating button that appears when the user is scrolled away from the
bottom, with timer-based visibility to avoid clutter.

### How it works

- `_onScroll()` tracks `_isAtBottom` using a 50px threshold, accounting
  for the trailing spacer: `contentBottom = maxScrollExtent - _spacerHeight`.
- `ScrollEndNotification` → 300 ms delay → show button → 3 s auto-hide.
- `ScrollStartNotification` → immediate hide + cancel timers.
- Tap → `animateTo(contentBottom)` + hide.
- Uses `AnimatedOpacity` + `IgnorePointer` (ignoring when hidden).

## Files changed

- `lib/features/chat/widgets/message_list.dart` — all scroll logic lives
  here. `computeDisplayMessages()` is a pure function extracted for
  testability. `_MessageListState` holds all mutable scroll state.
- `test/features/chat/widgets/message_list_test.dart` — unit tests for
  `computeDisplayMessages()`, widget tests for loading/error/empty states,
  streaming status passthrough, trailing spacer sizing, and scroll-to-bottom
  button lifecycle.
