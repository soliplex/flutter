import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_frontend/core/models/app_config.dart';

void main() {
  group('AppConfig', () {
    test('copyWith replaces baseUrl', () {
      const config = AppConfig(baseUrl: 'http://localhost:8000');
      final updated = config.copyWith(baseUrl: 'http://example.com:9000');

      expect(updated.baseUrl, 'http://example.com:9000');
    });

    test('copyWith preserves baseUrl when not provided', () {
      const config = AppConfig(baseUrl: 'http://localhost:8000');
      final updated = config.copyWith();

      expect(updated.baseUrl, 'http://localhost:8000');
    });
  });
}
