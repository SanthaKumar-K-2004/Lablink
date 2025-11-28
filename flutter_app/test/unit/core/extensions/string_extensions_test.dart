import 'package:flutter_test/flutter_test.dart';
import 'package:lablink/core/extensions/string_extensions.dart';

void main() {
  group('StringExtensions', () {
    group('isValidEmail', () {
      test('returns true for valid email', () {
        expect('user@example.com'.isValidEmail, true);
        expect('test.user+tag@example.co.uk'.isValidEmail, true);
      });

      test('returns false for invalid email', () {
        expect('invalid'.isValidEmail, false);
        expect('user@'.isValidEmail, false);
        expect('@example.com'.isValidEmail, false);
      });
    });

    group('capitalize', () {
      test('capitalizes first letter', () {
        expect('hello'.capitalize(), 'Hello');
        expect('HELLO'.capitalize(), 'Hello');
      });

      test('returns empty string as is', () {
        expect(''.capitalize(), '');
      });
    });

    group('capitalizeWords', () {
      test('capitalizes all words', () {
        expect('hello world'.capitalizeWords(), 'Hello World');
        expect('HELLO WORLD'.capitalizeWords(), 'Hello World');
      });
    });

    group('isNumeric', () {
      test('returns true for numeric strings', () {
        expect('123'.isNumeric, true);
        expect('123.45'.isNumeric, true);
        expect('-123'.isNumeric, true);
      });

      test('returns false for non-numeric strings', () {
        expect('abc'.isNumeric, false);
        expect('12a'.isNumeric, false);
      });
    });

    group('truncate', () {
      test('truncates string longer than length', () {
        expect('Hello World'.truncate(5), 'He...');
        expect('Hello'.truncate(10), 'Hello');
      });
    });
  });
}
