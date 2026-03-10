import 'package:soliplex_dataframe/soliplex_dataframe.dart';
import 'package:soliplex_interpreter_monty/soliplex_interpreter_monty.dart';
import 'package:soliplex_scripting/src/df_functions.dart';

/// Plugin exposing 37 DataFrame operations to Monty scripts.
///
/// All function names are prefixed with `df_` (e.g. `df_create`, `df_head`).
class DfPlugin extends MontyPlugin {
  DfPlugin({required DfRegistry dfRegistry}) : _dfRegistry = dfRegistry;

  final DfRegistry _dfRegistry;

  @override
  String get namespace => 'df';

  @override
  List<HostFunction> get functions => buildDfFunctions(_dfRegistry);
}
