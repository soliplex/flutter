import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_frontend/core/models/consent_notice.dart';

void main() {
  group('ConsentNotice', () {
    test('constructor requires title and body, defaults acknowledgmentLabel',
        () {
      const notice = ConsentNotice(title: 'Notice', body: 'Body text');

      expect(notice.title, 'Notice');
      expect(notice.body, 'Body text');
      expect(notice.acknowledgmentLabel, 'OK');
    });

    test('custom acknowledgmentLabel is preserved', () {
      const notice = ConsentNotice(
        title: 'Notice',
        body: 'Body text',
        acknowledgmentLabel: 'I Agree',
      );

      expect(notice.acknowledgmentLabel, 'I Agree');
    });

    test('copyWith replaces specified fields', () {
      const original = ConsentNotice(title: 'A', body: 'B');
      final modified = original.copyWith(title: 'X', acknowledgmentLabel: 'Go');

      expect(modified.title, 'X');
      expect(modified.body, 'B');
      expect(modified.acknowledgmentLabel, 'Go');
    });

    test('copyWith preserves original when no changes', () {
      const original = ConsentNotice(title: 'A', body: 'B');
      final copy = original.copyWith();

      expect(copy, equals(original));
    });

    test('equality works correctly', () {
      const a = ConsentNotice(title: 'A', body: 'B');
      const b = ConsentNotice(title: 'A', body: 'B');
      const c = ConsentNotice(title: 'A', body: 'Different');

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('hashCode is consistent with equality', () {
      const a = ConsentNotice(title: 'A', body: 'B');
      const b = ConsentNotice(title: 'A', body: 'B');
      const c = ConsentNotice(title: 'A', body: 'Different');

      expect(a.hashCode, equals(b.hashCode));
      expect(a.hashCode, isNot(equals(c.hashCode)));
    });

    test('toString returns readable representation', () {
      const notice = ConsentNotice(title: 'Title', body: 'Body');

      expect(notice.toString(), contains('ConsentNotice'));
      expect(notice.toString(), contains('title: Title'));
      expect(notice.toString(), contains('body: Body'));
      expect(notice.toString(), contains('acknowledgmentLabel: OK'));
    });
  });
}
