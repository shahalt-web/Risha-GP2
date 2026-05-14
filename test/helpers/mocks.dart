/// -------------------------------------------------------
/// Shared mock classes for the Risha test suite.
///
/// Uses **mocktail** so that test files can register custom
/// return values on-the-fly without writing manual fakes.
/// -------------------------------------------------------
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

// ── Firebase Auth ────────────────────────────────────────
class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}

class MockUserCredential extends Mock implements UserCredential {}

// ── Firestore ────────────────────────────────────────────
class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

// ملاحظة: تم إزالة Mocks الخاصة بـ Query و CollectionReference لأنها فئات مختومة (sealed).
// يفضل استخدام fake_cloud_firestore للاختبارات التي تتطلب تفاعل مع قاعدة البيانات.

// ── HTTP ─────────────────────────────────────────────────
class MockHttpClient extends Mock implements http.Client {}

// ── Fallback Values (required by mocktail for value types) ──
class FakeUri extends Fake implements Uri {}

/// Call once in `setUpAll` for every test file that uses HTTP mocks.
void registerFallbackValues() {
  registerFallbackValue(FakeUri());
  registerFallbackValue(Uri.parse('https://example.com'));
}
