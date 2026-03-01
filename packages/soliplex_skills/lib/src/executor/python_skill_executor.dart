import 'package:soliplex_skills/src/executor/skill_executor.dart';
import 'package:soliplex_skills/src/model/skill.dart';

/// Executes a [PythonSkill] by delegating to the injected [PythonRunner].
Future<ExecutionOutput> executePythonSkill(
  PythonSkill skill,
  PythonRunner runner,
) async {
  try {
    final output = await runner(skill.code);
    return ExecutionOutput(output: output);
  } on Exception catch (e) {
    return ExecutionOutput(output: '', error: e.toString());
  }
}
