# Visual Design Preferences

Timeless design preferences for the Soliplex frontend. These capture
**what the UI should do**, not how it's implemented.

## Message list

### User message placed to viewport top on send

When the user sends a message, it should be positioned at the top of
the viewport — not scrolled to the bottom. This keeps the user's
question visible while the assistant response streams in below it.

A dynamic trailing spacer fills remaining viewport space so the message
can reach the top position, then shrinks as streaming content grows.
Normal scrolling resumes once the response fills the viewport.

### Scroll-to-bottom button

When the user scrolls away from the latest content, a floating button
appears to let them jump back to the bottom. The button uses timer-based
visibility: brief delay before appearing, auto-hides after a few seconds
of inactivity, and hides immediately when the user starts scrolling.
