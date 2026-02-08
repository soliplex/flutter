import 'package:soliplex_client/soliplex_client.dart';
import 'package:test/test.dart';

void main() {
  group('BackendVersionInfo', () {
    test('creates with required fields', () {
      const info = BackendVersionInfo(
        soliplexVersion: '0.36.dev0',
        packageVersions: {'soliplex': '0.36.dev0', 'fastapi': '0.124.0'},
      );

      expect(info.soliplexVersion, equals('0.36.dev0'));
      expect(info.packageVersions, hasLength(2));
      expect(info.packageVersions['soliplex'], equals('0.36.dev0'));
      expect(info.packageVersions['fastapi'], equals('0.124.0'));
    });

    test('creates with empty package versions', () {
      const info = BackendVersionInfo(
        soliplexVersion: 'Unknown',
        packageVersions: <String, String>{},
      );

      expect(info.soliplexVersion, equals('Unknown'));
      expect(info.packageVersions, isEmpty);
    });

    group('equality', () {
      test('equal when all fields match', () {
        const info1 = BackendVersionInfo(
          soliplexVersion: '0.36.dev0',
          packageVersions: {'a': '1.0', 'b': '2.0'},
        );
        const info2 = BackendVersionInfo(
          soliplexVersion: '0.36.dev0',
          packageVersions: {'a': '1.0', 'b': '2.0'},
        );

        expect(info1, equals(info2));
      });

      test('not equal when soliplexVersion differs', () {
        const info1 = BackendVersionInfo(
          soliplexVersion: '0.36.dev0',
          packageVersions: {'a': '1.0'},
        );
        const info2 = BackendVersionInfo(
          soliplexVersion: '0.37.0',
          packageVersions: {'a': '1.0'},
        );

        expect(info1, isNot(equals(info2)));
      });

      test('not equal when packageVersions differ', () {
        const info1 = BackendVersionInfo(
          soliplexVersion: '0.36.dev0',
          packageVersions: {'a': '1.0'},
        );
        const info2 = BackendVersionInfo(
          soliplexVersion: '0.36.dev0',
          packageVersions: {'a': '2.0'},
        );

        expect(info1, isNot(equals(info2)));
      });

      test('not equal when packageVersions have different keys', () {
        const info1 = BackendVersionInfo(
          soliplexVersion: '0.36.dev0',
          packageVersions: {'a': '1.0'},
        );
        const info2 = BackendVersionInfo(
          soliplexVersion: '0.36.dev0',
          packageVersions: {'b': '1.0'},
        );

        expect(info1, isNot(equals(info2)));
      });

      test('identical returns true', () {
        const info = BackendVersionInfo(
          soliplexVersion: '0.36.dev0',
          packageVersions: {'a': '1.0'},
        );
        expect(info == info, isTrue);
      });
    });

    test('hashCode equal when objects are equal', () {
      const info1 = BackendVersionInfo(
        soliplexVersion: '0.36.dev0',
        packageVersions: {'a': '1.0', 'b': '2.0'},
      );
      const info2 = BackendVersionInfo(
        soliplexVersion: '0.36.dev0',
        packageVersions: {'a': '1.0', 'b': '2.0'},
      );

      expect(info1.hashCode, equals(info2.hashCode));
    });

    test('toString includes soliplexVersion', () {
      const info = BackendVersionInfo(
        soliplexVersion: '0.36.dev0',
        packageVersions: {'a': '1.0'},
      );

      final str = info.toString();

      expect(str, contains('BackendVersionInfo'));
      expect(str, contains('0.36.dev0'));
    });
  });
}
