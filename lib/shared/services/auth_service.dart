import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  User? get currentUser => _auth.currentUser;

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = _normalizeEmail(email);
    try {
      await _auth
          .signInWithEmailAndPassword(
            email: normalizedEmail,
            password: password,
          )
          .timeout(const Duration(seconds: 20));
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_mapSignInError(e.code), code: e.code);
    } on TimeoutException {
      throw const AuthFailure(
        'انتهت مهلة الاتصال. تحقق من الإنترنت ثم حاول مرة أخرى.',
        code: 'timeout',
      );
    }
  }

  Future<void> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = _normalizeEmail(email);
    UserCredential? credential;

    try {
      credential = await _auth
          .createUserWithEmailAndPassword(
            email: normalizedEmail,
            password: password,
          )
          .timeout(const Duration(seconds: 20));
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_mapSignUpError(e.code), code: e.code);
    } on TimeoutException {
      throw const AuthFailure(
        'تعذر إكمال التسجيل حالياً. تحقق من الإنترنت وحاول مرة أخرى.',
        code: 'timeout',
      );
    }

    final uid = credential.user?.uid;
    if (uid == null) {
      throw const AuthFailure(
        'تعذر إنشاء الحساب حالياً. حاول مرة أخرى.',
        code: 'missing-user',
      );
    }

    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .set({
            'email': normalizedEmail,
            'locale': 'ar',
            'emailVerification': {
              'isVerified': false,
              'pendingCodeHash': null,
              'pendingCodeExpiresAt': null,
              'lastCodeSentAt': null,
              'verifiedAt': null,
            },
            'emailNotificationSettings': {
              'enabled': true,
              'verification': true,
              'welcomeGuide': true,
              'login': true,
              'childActivity': true,
              'weeklyStats': true,
              'dailyWarnings': true,
            },
            'welcomeGuide': {'sentAt': null},
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true))
          .timeout(const Duration(seconds: 20));
    } on FirebaseException catch (e) {
      if (_shouldContinueWithoutFirestore(e)) {
        return;
      }
      await _deleteCreatedUserIfNeeded(credential);
      throw AuthFailure(_mapFirestoreWriteError(e), code: e.code);
    } on TimeoutException {
      // Keep the authenticated account and let the app continue with local state.
      return;
    }
  }

  Future<void> sendPasswordResetEmail({required String email}) async {
    final normalizedEmail = _normalizeEmail(email);

    try {
      await _auth
          .sendPasswordResetEmail(email: normalizedEmail)
          .timeout(const Duration(seconds: 20));
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_mapPasswordResetError(e.code), code: e.code);
    } on TimeoutException {
      throw const AuthFailure(
        'تعذر إرسال الرابط بسبب بطء الشبكة. حاول مرة أخرى.',
        code: 'timeout',
      );
    }
  }

  Future<void> confirmPasswordReset({
    required String resetLinkOrCode,
    required String newPassword,
  }) async {
    final oobCode = _extractPasswordResetCode(resetLinkOrCode);
    final cleanPassword = newPassword.trim();

    try {
      await _auth
          .verifyPasswordResetCode(oobCode)
          .timeout(const Duration(seconds: 20));
      await _auth
          .confirmPasswordReset(code: oobCode, newPassword: cleanPassword)
          .timeout(const Duration(seconds: 20));
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_mapConfirmPasswordResetError(e.code), code: e.code);
    } on TimeoutException {
      throw const AuthFailure(
        'تعذر إكمال إعادة التعيين بسبب بطء الشبكة. حاول مرة أخرى.',
        code: 'timeout',
      );
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut().timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw const AuthFailure(
        'تعذر تسجيل الخروج بسبب بطء الشبكة. حاول مرة أخرى.',
        code: 'timeout',
      );
    } catch (_) {
      throw const AuthFailure(
        'تعذر تسجيل الخروج حالياً. حاول مرة أخرى.',
        code: 'sign-out-failed',
      );
    }
  }

  Future<void> _deleteCreatedUserIfNeeded(UserCredential? credential) async {
    final user = credential?.user;
    if (user == null) {
      return;
    }

    try {
      await user.delete();
    } catch (_) {
      // Best effort to avoid half-created accounts when Firestore write fails.
    }
  }

  String _normalizeEmail(String email) => email.trim().toLowerCase();

  String _extractPasswordResetCode(String value) {
    final normalizedValue = value
        .trim()
        .replaceAll('&amp;', '&')
        .replaceAll('<', '')
        .replaceAll('>', '');
    if (normalizedValue.isEmpty) {
      throw const AuthFailure(
        'ألصق رابط إعادة التعيين أو رمز الاستعادة أولًا.',
        code: 'missing-oob-code',
      );
    }

    final uri = Uri.tryParse(normalizedValue);
    final codeFromUri = uri?.queryParameters['oobCode']?.trim();
    if (codeFromUri != null && codeFromUri.isNotEmpty) {
      return codeFromUri;
    }

    if (!normalizedValue.contains('/') &&
        !normalizedValue.contains('?') &&
        !normalizedValue.contains(' ')) {
      return normalizedValue;
    }

    throw const AuthFailure(
      'تعذر استخراج رمز الاستعادة من الرابط. ألصق الرابط كاملًا كما وصلك في البريد.',
      code: 'invalid-oob-link',
    );
  }

  bool _shouldContinueWithoutFirestore(FirebaseException e) {
    final message = e.message ?? '';
    final normalizedCode = e.code.trim().toLowerCase();
    final normalizedMessage = message.toLowerCase();
    return normalizedCode == 'permission-denied' ||
        normalizedCode == 'unavailable' ||
        normalizedCode == 'resource-exhausted' ||
        message.contains('Cloud Firestore API has not been used') ||
        normalizedMessage.contains('resource-exhausted') ||
        normalizedMessage.contains('quota') ||
        normalizedMessage.contains('exceeded');
  }

  String _mapFirestoreWriteError(FirebaseException e) {
    final message = e.message ?? '';
    if (message.contains('Cloud Firestore API has not been used')) {
      return 'خدمة Firestore غير مفعلة في مشروع Firebase. فعّل Firestore Database ثم أعد المحاولة.';
    }

    switch (e.code) {
      case 'permission-denied':
        return 'ليس لديك صلاحية للوصول إلى قاعدة البيانات. تحقق من قواعد Firestore.';
      case 'unavailable':
        return 'خدمة قاعدة البيانات غير متاحة حالياً. حاول بعد قليل.';
      case 'resource-exhausted':
        return 'تم إنشاء الحساب، لكن تم تجاوز حصة Firestore الحالية وسيتم الاعتماد على البيانات المحلية مؤقتاً.';
      default:
        return 'تم إنشاء الحساب لكن تعذر حفظ بياناته في قاعدة البيانات.';
    }
  }

  String _mapSignInError(String code) {
    switch (code) {
      case 'invalid-email':
        return 'صيغة البريد الإلكتروني غير صحيحة.';
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'البريد الإلكتروني أو كلمة المرور غير صحيحة.';
      case 'user-disabled':
        return 'هذا الحساب معطل حالياً.';
      case 'too-many-requests':
        return 'تمت محاولات كثيرة. حاول لاحقاً.';
      case 'network-request-failed':
        return 'تحقق من اتصال الإنترنت ثم حاول مرة أخرى.';
      default:
        return 'تعذر تسجيل الدخول حالياً. حاول مرة أخرى.';
    }
  }

  String _mapSignUpError(String code) {
    switch (code) {
      case 'invalid-email':
        return 'صيغة البريد الإلكتروني غير صحيحة.';
      case 'email-already-in-use':
        return 'هذا البريد مستخدم مسبقاً.';
      case 'weak-password':
        return 'كلمة المرور ضعيفة. استخدم 6 أحرف على الأقل.';
      case 'operation-not-allowed':
        return 'تسجيل الحسابات عبر البريد غير مفعّل في Firebase.';
      case 'network-request-failed':
        return 'تحقق من اتصال الإنترنت ثم حاول مرة أخرى.';
      default:
        return 'تعذر إنشاء الحساب حالياً. حاول مرة أخرى.';
    }
  }

  String _mapPasswordResetError(String code) {
    switch (code) {
      case 'invalid-email':
        return 'صيغة البريد الإلكتروني غير صحيحة.';
      case 'user-not-found':
        return 'هذا البريد غير مسجل.';
      case 'network-request-failed':
        return 'تحقق من اتصال الإنترنت ثم حاول مرة أخرى.';
      case 'too-many-requests':
        return 'تمت محاولات كثيرة. حاول لاحقاً.';
      default:
        return 'تعذر إرسال رابط إعادة التعيين حالياً. حاول مرة أخرى.';
    }
  }

  String _mapConfirmPasswordResetError(String code) {
    switch (code) {
      case 'expired-action-code':
        return 'انتهت صلاحية رابط إعادة التعيين. اطلب رابطًا جديدًا.';
      case 'invalid-action-code':
        return 'رابط إعادة التعيين غير صالح أو تم استخدامه مسبقًا.';
      case 'weak-password':
        return 'كلمة المرور الجديدة ضعيفة. استخدم 6 أحرف على الأقل.';
      case 'user-disabled':
        return 'هذا الحساب معطل حاليًا.';
      case 'network-request-failed':
        return 'تحقق من اتصال الإنترنت ثم حاول مرة أخرى.';
      case 'too-many-requests':
        return 'تمت محاولات كثيرة. حاول لاحقًا.';
      default:
        return 'تعذر إكمال إعادة تعيين كلمة المرور حاليًا. حاول مرة أخرى.';
    }
  }
}

class AuthFailure implements Exception {
  const AuthFailure(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}
