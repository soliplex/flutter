import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_monty/soliplex_monty.dart';

void main() {
  group('PythonExecutorTool', () {
    test('toolName is execute_python', () {
      expect(PythonExecutorTool.toolName, 'execute_python');
    });
  });
}
