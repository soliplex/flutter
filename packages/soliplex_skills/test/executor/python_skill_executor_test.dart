import 'package:soliplex_skills/soliplex_skills.dart';
import 'package:test/test.dart';

void main() {
  const skill = PythonSkill(
    metadata: SkillMetadata(name: 'hello', description: 'says hello'),
    sourcePath: '/skills/hello.py',
    code: 'print("hello")',
  );

  group('executePythonSkill', () {
    test('delegates to PythonRunner and returns output', () async {
      Future<String> mockRunner(String code) async => 'hello';

      final result = await executePythonSkill(skill, mockRunner);

      expect(result, isA<ExecutionOutput>());
      expect(result.output, 'hello');
      expect(result.error, isNull);
      expect(result.isSuccess, isTrue);
    });

    test('passes skill code to runner', () async {
      String? receivedCode;
      Future<String> capturingRunner(String code) async {
        receivedCode = code;
        return '';
      }

      await executePythonSkill(skill, capturingRunner);
      expect(receivedCode, 'print("hello")');
    });

    test('captures runner exceptions as error', () async {
      Future<String> failingRunner(String code) async =>
          throw Exception('sandbox crashed');

      final result = await executePythonSkill(skill, failingRunner);

      expect(result.isSuccess, isFalse);
      expect(result.output, '');
      expect(result.error, contains('sandbox crashed'));
    });
  });
}
