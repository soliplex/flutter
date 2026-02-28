import 'package:soliplex_interpreter_monty/soliplex_interpreter_monty.dart';
import 'package:test/test.dart';

void main() {
  group('PythonExecutorTool', () {
    test('toolName is execute_python', () {
      expect(PythonExecutorTool.toolName, 'execute_python');
    });
  });
}
