# Feature 14: Focus (Zen) Mode

## Usage
A toggle that hides all chrome (sidebar, app bar, input field) and only shows the text content in a beautiful, readable typography (serif, increased line height).

## Specification
- **UI:** Animated opacity/visibility toggle.
- **Theme:** Specific `ThemeData` for reading.

## Skeleton Code

```dart
class ZenModeScaffold extends StatelessWidget {
  final bool isZen;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: isZen ? null : AppBar(),
      body: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        padding: isZen ? EdgeInsets.symmetric(horizontal: 100) : EdgeInsets.zero,
        child: child,
      ),
    );
  }
}
```

## Reviews

### Codex Review (Technical)
**Completeness:** High.
**Feasibility:** High.
**Novelty:** Low.

### Skeptic Review (Product)
**Critique:** "Nice to have". Low engineering effort, high aesthetic value.
