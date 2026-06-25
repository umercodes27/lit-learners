import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/core/utils/validators.dart';

void main() {
  group('Validators', () {
    test('accepts a valid email and strong password', () {
      expect(Validators.email('parent@example.com'), isNull);
      expect(Validators.password('Strong1!'), isNull);
    });

    test('rejects weak password missing required parts', () {
      expect(Validators.password('short'), isNotNull);
      expect(Validators.password('lowercase1!'), isNotNull);
      expect(Validators.password('NoNumber!'), isNotNull);
      expect(Validators.password('NoSpecial1'), isNotNull);
    });
  });
}
