import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionProgressService {
  SessionProgressService({FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance;

  static const Set<String> resumableChildSetupRoutes = {
    '/child-home/behaviors',
    '/child-home/add-behavior',
    '/child-home/water-routine',
    '/child-home/sport-routine',
    '/child-home/sleep-routine',
    '/child-home/pin',
    '/child-home/setup-preparing',
    '/child-home/setup-success',
  };

  final FirebaseAuth _auth;

  String _routeKeyFor(String uid) => 'child_setup_resume_route_$uid';
  String _completedKeyFor(String uid) => 'child_setup_completed_$uid';

  Future<void> saveChildSetupRoute(String route) async {
    if (!resumableChildSetupRoutes.contains(route)) {
      return;
    }
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_routeKeyFor(uid), route);
    } catch (_) {
      // Ignore local storage failures to avoid blocking app flow.
    }
  }

  Future<String?> getSavedChildSetupRoute() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return null;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final route = prefs.getString(_routeKeyFor(uid));
      if (route == null || route.isEmpty) {
        return null;
      }
      if (!resumableChildSetupRoutes.contains(route)) {
        return null;
      }
      return route;
    } catch (_) {
      // If local storage is unavailable, continue without resume.
      return null;
    }
  }

  Future<void> clearChildSetupRoute() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_routeKeyFor(uid));
    } catch (_) {
      // Ignore local storage failures to avoid blocking app flow.
    }
  }

  Future<void> setChildSetupCompleted(bool isCompleted) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_completedKeyFor(uid), isCompleted);
    } catch (_) {
      // Ignore local storage failures to avoid blocking app flow.
    }
  }

  Future<bool> hasCompletedChildSetup() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return false;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_completedKeyFor(uid)) == true;
    } catch (_) {
      return false;
    }
  }
}
