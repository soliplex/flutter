import 'package:nocterm/nocterm.dart';
import 'package:signals_core/signals_core.dart';

/// Rebuilds its child whenever a [ReadonlySignal] changes.
///
/// Analogous to `BlocBuilder` but for signals. Subscribe on mount,
/// dispose on unmount, call `setState` on each signal emission.
///
/// ```dart
/// SignalBuilder<RunState>(
///   signal: session.runState,
///   builder: (context, state) => Text('$state'),
/// )
/// ```
class SignalBuilder<T> extends StatefulComponent {
  const SignalBuilder({required this.signal, required this.builder, super.key});

  final ReadonlySignal<T> signal;
  final Component Function(BuildContext context, T value) builder;

  @override
  State<SignalBuilder<T>> createState() => _SignalBuilderState<T>();
}

class _SignalBuilderState<T> extends State<SignalBuilder<T>> {
  late T _value;
  EffectCleanup? _dispose;

  @override
  void initState() {
    super.initState();
    _value = component.signal.value;
    _dispose = effect(() {
      final newValue = component.signal.value;
      if (!identical(newValue, _value)) {
        setState(() {
          _value = newValue;
        });
      }
    });
  }

  @override
  void dispose() {
    _dispose?.call();
    super.dispose();
  }

  @override
  Component build(BuildContext context) {
    return component.builder(context, _value);
  }
}
