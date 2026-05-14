import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:risha_v01/shared/services/email_notification_service.dart';

class SelectedChildService {
  SelectedChildService({
    FirebaseAuth? auth,
    EmailNotificationService? emailNotificationService,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _emailNotificationService =
           emailNotificationService ??
           EmailNotificationService(auth: auth ?? FirebaseAuth.instance);

  final FirebaseAuth _auth;
  final EmailNotificationService _emailNotificationService;

  String _selectedChildKeyFor(String uid) => 'selected_child_id_$uid';

  Future<void> saveSelectedChildId(String childId, {String? childName}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return;
    }
    final cleanChildId = childId.trim();
    if (cleanChildId.isEmpty) {
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_selectedChildKeyFor(uid), cleanChildId);
      unawaited(
        _emailNotificationService.queueChildSwitchedEmail(
          childId: cleanChildId,
          childName: childName,
        ),
      );
      _emailNotificationService.flushDurableOutboxInBackground();
    } catch (_) {
      // Ignore local storage failures to avoid blocking app flow.
    }
  }

  Future<String?> getSelectedChildId() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return null;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString(_selectedChildKeyFor(uid))?.trim();
      if (value == null || value.isEmpty) {
        return null;
      }
      return value;
    } catch (_) {
      return null;
    }
  }

  Future<void> clearSelectedChildId() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_selectedChildKeyFor(uid));
    } catch (_) {
      // Ignore local storage failures to avoid blocking app flow.
    }
  }
}
