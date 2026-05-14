/// -------------------------------------------------------
/// R1 / R2 / R8  –  Validation Unit Tests
///
/// Tests the pure validation logic used across registration,
/// login, and PIN screens: email format, password strength,
/// and PIN format validation.
/// -------------------------------------------------------
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// We replicate the validators exactly as they appear in login_screen.dart
// and pin_service.dart so unit tests stay independent of widget imports.
// ---------------------------------------------------------------------------

/// Email validator (mirrors LoginScreen._validateEmail).
String? validateEmail(String? value) {
  final text = value ?? '';
  if (text.trim().isEmpty) {
    return 'الرجاء إدخال البريد الإلكتروني.';
  }
  if (text.contains(RegExp(r'\s'))) {
    return 'البريد الإلكتروني لا يجب أن يحتوي على مسافات.';
  }

  final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  if (!emailRegex.hasMatch(text)) {
    return 'الرجاء إدخال بريد إلكتروني صحيح.';
  }
  return null;
}

/// Password validator (mirrors LoginScreen._validatePassword).
String? validatePassword(String? value) {
  final text = value ?? '';
  if (text.trim().isEmpty) {
    return 'الرجاء إدخال كلمة المرور.';
  }
  return null;
}

/// PIN validator (mirrors PinService._isValidPin).
bool isValidPin(String pin) {
  if (pin.length != 4) {
    return false;
  }
  return pin.codeUnits.every((unit) => unit >= 48 && unit <= 57);
}

// ===================== TESTS =====================

void main() {
  // ── Email Validation ─────────────────────────────────
  group('Email validation (R1/R2)', () {
    test('returns null for a valid email address', () {
      final input = 'parent@example.com';
      debugPrint(
        '🔍 فحص البريد الإلكتروني: [المدخلات: $input] -> [النتيجة المتوقعة: مقبول]',
      );
      final result = validateEmail(input);
      expect(result, isNull);
      debugPrint('✅ النتيجة: تم قبول البريد بنجاح.');
    });

    test('returns error for an empty string', () {
      final input = '';
      debugPrint(
        '🔍 فحص البريد الإلكتروني: [المدخلات: نص فارغ] -> [النتيجة المتوقعة: خطأ]',
      );
      final result = validateEmail(input);
      expect(result, isNotNull);
      debugPrint('✅ النتيجة: تم رفض النص الفارغ بنجاح (الرسالة: $result).');
    });

    test('returns error for null input', () {
      final result = validateEmail(null);
      expect(result, isNotNull);
    });

    test('returns error when email contains spaces', () {
      final result = validateEmail('par ent@example.com');
      expect(result, isNotNull);
      expect(result, contains('مسافات'));
    });

    test('returns error for email missing @ symbol', () {
      final result = validateEmail('parentexample.com');
      expect(result, isNotNull);
      expect(result, contains('بريد إلكتروني صحيح'));
    });

    test('returns error for email missing domain', () {
      final result = validateEmail('parent@');
      expect(result, isNotNull);
    });

    test('accepts email with subdomain', () {
      expect(validateEmail('user@mail.example.com'), isNull);
    });

    test('FAIL case: email with trailing whitespace only is rejected', () {
      // The email '  ' is all whitespace – trimmed it becomes empty.
      final result = validateEmail('   ');
      expect(result, isNotNull);
    });
  });

  // ── Password Validation ──────────────────────────────
  group('Password validation (R2)', () {
    test('returns null for a non-empty password', () {
      expect(validatePassword('SecurePass123'), isNull);
    });

    test('returns error for an empty password', () {
      final result = validatePassword('');
      expect(result, isNotNull);
      expect(result, contains('كلمة المرور'));
    });

    test('returns error for whitespace-only password', () {
      final result = validatePassword('   ');
      expect(result, isNotNull);
    });

    test('returns null for password with special characters', () {
      expect(validatePassword('P@ss!2024'), isNull);
    });
  });

  // ── PIN Validation ──────────────────────────────────
  group('PIN validation (R8)', () {
    test('accepts a valid 4-digit PIN', () {
      final input = '1234';
      debugPrint(
        '🔍 فحص الرمز السري (PIN): [المدخلات: $input] -> [النتيجة المتوقعة: مقبول]',
      );
      expect(isValidPin(input), isTrue);
      debugPrint('✅ النتيجة: تم قبول الرمز بنجاح.');
    });

    test('rejects PIN containing letters', () {
      final input = '12ab';
      debugPrint(
        '🔍 فحص الرمز السري (PIN): [المدخلات: $input] -> [النتيجة المتوقعة: مرفوض]',
      );
      expect(isValidPin(input), isFalse);
      debugPrint('✅ النتيجة: تم رفض الرمز المحتوي على حروف بنجاح.');
    });

    test('rejects PIN with special characters', () {
      expect(isValidPin('12#4'), isFalse);
    });

    test('rejects empty string', () {
      expect(isValidPin(''), isFalse);
    });

    test('FAIL case: PIN with Arabic digits is not accepted', () {
      // Arabic-Indic digits (٠١٢٣) have different code units than ASCII 0-9.
      expect(isValidPin('٠١٢٣'), isFalse);
    });
  });
}
