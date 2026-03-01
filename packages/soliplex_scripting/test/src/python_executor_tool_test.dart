import 'package:ag_ui/ag_ui.dart' show Tool;
import 'package:soliplex_scripting/soliplex_scripting.dart';
import 'package:test/test.dart';

void main() {
  group('PythonExecutorTool', () {
    test('toolName is execute_python', () {
      expect(PythonExecutorTool.toolName, 'execute_python');
    });

    test('definition is a const Tool', () {
      expect(PythonExecutorTool.definition, isA<Tool>());
      expect(PythonExecutorTool.definition.name, 'execute_python');
    });

    test('definition has code parameter', () {
      final params =
          PythonExecutorTool.definition.parameters as Map<String, Object?>;
      expect(params['type'], 'object');

      final properties = params['properties']! as Map<String, Object?>;
      expect(properties.containsKey('code'), isTrue);

      final codeProp = properties['code']! as Map<String, Object?>;
      expect(codeProp['type'], 'string');

      final required = params['required']! as List<Object?>;
      expect(required, contains('code'));
    });
  });
}
