import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PinService {
  PinService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  static const String _fallbackPinKey = 'parent_pin_code_fallback';

  String _pinKeyFor(String uid) => 'parent_pin_code_$uid';
  String _childPinKeyFor(String uid, String childId) =>
      'child_pin_code_${uid}_${childId.trim()}';

  Future<void> savePin(String pin, {String? childId}) async {
    final uid = _auth.currentUser?.uid;
    final cleanPin = pin.trim();
    if (!_isValidPin(cleanPin)) {
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final cleanChildId = childId?.trim() ?? '';
      if (uid != null && cleanChildId.isNotEmpty) {
        await prefs.setString(_childPinKeyFor(uid, cleanChildId), cleanPin);
        return;
      }

      await prefs.setString(_fallbackPinKey, cleanPin);
      if (uid != null) {
        await prefs.setString(_pinKeyFor(uid), cleanPin);
      }
    } catch (_) {
      // Ignore local storage failures to avoid blocking app flow.
    }
  }

  Future<String?> getSavedPin({
    String? childId,
    bool allowParentFallback = false,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = _auth.currentUser?.uid;
      final cleanChildId = childId?.trim() ?? '';

      if (uid != null && cleanChildId.isNotEmpty) {
        final childValue = prefs
            .getString(_childPinKeyFor(uid, cleanChildId))
            ?.trim();
        if (childValue != null && _isValidPin(childValue)) {
          return childValue;
        }
        if (!allowParentFallback) {
          return null;
        }
      }

      if (uid != null) {
        final savedValue = prefs.getString(_pinKeyFor(uid))?.trim();
        if (savedValue != null && _isValidPin(savedValue)) {
          return savedValue;
        }
      }

      final fallbackValue = prefs.getString(_fallbackPinKey)?.trim();
      if (fallbackValue != null && _isValidPin(fallbackValue)) {
        return fallbackValue;
      }

      return _getPinFromAnyParentKey(prefs);
    } catch (_) {
      return null;
    }
  }

  String? _getPinFromAnyParentKey(SharedPreferences prefs) {
    for (final key in prefs.getKeys()) {
      if (!key.startsWith('parent_pin_code_')) {
        continue;
      }
      final value = prefs.getString(key)?.trim();
      if (value != null && _isValidPin(value)) {
        return value;
      }
    }
    return null;
  }

  Future<bool> hasSavedPin({
    String? childId,
    bool allowParentFallback = false,
  }) async =>
      (await getSavedPin(
        childId: childId,
        allowParentFallback: allowParentFallback,
      )) !=
      null;

  Future<bool> verifyPin(
    String pin, {
    String? childId,
    bool allowParentFallback = false,
  }) async {
    final savedPin = await getSavedPin(
      childId: childId,
      allowParentFallback: allowParentFallback,
    );
    if (savedPin == null) {
      return false;
    }
    return pin.trim() == savedPin;
  }

  bool _isValidPin(String pin) {
    if (pin.length != 4) {
      return false;
    }
    return pin.codeUnits.every((unit) => unit >= 48 && unit <= 57);
  }
}
