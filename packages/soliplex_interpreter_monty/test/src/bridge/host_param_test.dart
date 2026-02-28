import 'package:soliplex_interpreter_monty/src/bridge/host_param.dart';
import 'package:soliplex_interpreter_monty/src/bridge/host_param_type.dart';
import 'package:test/test.dart';

void main() {
  group('HostParam.validate', () {
    group('string', () {
      const param = HostParam(
        name: 'query',
        type: HostParamType.string,
      );

      test('accepts String', () {
        expect(param.validate('hello'), 'hello');
      });

      test('rejects non-String', () {
        expect(() => param.validate(42), throwsFormatException);
      });

      test('rejects null when required', () {
        expect(() => param.validate(null), throwsFormatException);
      });
    });

    group('integer', () {
      const param = HostParam(
        name: 'count',
        type: HostParamType.integer,
      );

      test('accepts int', () {
        expect(param.validate(42), 42);
      });

      test('rejects double', () {
        expect(() => param.validate(3.14), throwsFormatException);
      });

      test('rejects String', () {
        expect(() => param.validate('42'), throwsFormatException);
      });
    });

    group('number', () {
      const param = HostParam(
        name: 'score',
        type: HostParamType.number,
      );

      test('accepts int', () {
        expect(param.validate(42), 42);
      });

      test('accepts double', () {
        expect(param.validate(3.14), 3.14);
      });

      test('rejects String', () {
        expect(() => param.validate('3.14'), throwsFormatException);
      });
    });

    group('boolean', () {
      const param = HostParam(
        name: 'verbose',
        type: HostParamType.boolean,
      );

      test('accepts bool', () {
        expect(param.validate(true), true);
        expect(param.validate(false), false);
      });

      test('rejects int', () {
        expect(() => param.validate(1), throwsFormatException);
      });
    });

    group('list', () {
      const param = HostParam(
        name: 'tags',
        type: HostParamType.list,
      );

      test('accepts List', () {
        expect(param.validate(<Object?>['a', 'b']), ['a', 'b']);
      });

      test('rejects String', () {
        expect(() => param.validate('not a list'), throwsFormatException);
      });
    });

    group('map', () {
      const param = HostParam(
        name: 'metadata',
        type: HostParamType.map,
      );

      test('accepts Map<String, Object?>', () {
        expect(
          param.validate(<String, Object?>{'key': 'val'}),
          {'key': 'val'},
        );
      });

      test('rejects List', () {
        expect(
          () => param.validate(<Object?>[1, 2]),
          throwsFormatException,
        );
      });
    });

    group('optional with default', () {
      const param = HostParam(
        name: 'limit',
        type: HostParamType.integer,
        isRequired: false,
        defaultValue: 10,
      );

      test('returns default when null', () {
        expect(param.validate(null), 10);
      });

      test('accepts provided value', () {
        expect(param.validate(5), 5);
      });
    });

    group('optional without default', () {
      const param = HostParam(
        name: 'filter',
        type: HostParamType.string,
        isRequired: false,
      );

      test('returns null when null and no default', () {
        expect(param.validate(null), isNull);
      });
    });
  });

  group('HostParamType.jsonSchemaType', () {
    test('maps to JSON Schema types', () {
      expect(HostParamType.string.jsonSchemaType, 'string');
      expect(HostParamType.integer.jsonSchemaType, 'integer');
      expect(HostParamType.number.jsonSchemaType, 'number');
      expect(HostParamType.boolean.jsonSchemaType, 'boolean');
      expect(HostParamType.list.jsonSchemaType, 'array');
      expect(HostParamType.map.jsonSchemaType, 'object');
    });
  });
}
