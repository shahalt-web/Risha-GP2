import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChildLocalStateService {
  ChildLocalStateService({FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  Future<Map<String, dynamic>?> getChildProfileMap({
    required String childId,
  }) async {
    return _readMap(_profileKeyFor(childId));
  }

  Future<List<Map<String, dynamic>>> getChildrenListMaps() async {
    return _readMapList(_childrenListKeyFor());
  }

  Future<void> saveChildProfileMap({
    required String childId,
    required Map<String, dynamic> data,
  }) async {
    await _writeMap(_profileKeyFor(childId), data);
  }

  Future<void> saveChildrenListMaps(List<Map<String, dynamic>> items) async {
    await _writeMapList(_childrenListKeyFor(), items);
  }

  Future<void> deleteChildProfileMap({required String childId}) async {
    final key = _profileKeyFor(childId);
    if (key != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    }
  }

  Future<Map<String, dynamic>?> getBehaviorSettingsMap({
    required String childId,
  }) async {
    return _readMap(_behaviorKeyFor(childId));
  }

  Future<void> saveBehaviorSettingsMap({
    required String childId,
    required Map<String, dynamic> data,
  }) async {
    await _writeMap(_behaviorKeyFor(childId), data);
  }

  Future<Map<String, dynamic>?> getWalletMap({required String childId}) async {
    return _readMap(_walletKeyFor(childId));
  }

  Future<void> saveWalletMap({
    required String childId,
    required Map<String, dynamic> data,
  }) async {
    await _writeMap(_walletKeyFor(childId), data);
  }

  Future<Map<String, dynamic>?> getPendingWalletSyncMap({
    required String childId,
  }) async {
    return _readMap(_pendingWalletSyncKeyFor(childId));
  }

  Future<void> savePendingWalletSyncMap({
    required String childId,
    required Map<String, dynamic> data,
  }) async {
    await _writeMap(_pendingWalletSyncKeyFor(childId), data);
  }

  Future<Map<String, dynamic>?> getDailyTaskProgressMap({
    required String childId,
  }) async {
    return _readMap(_taskProgressKeyFor(childId));
  }

  Future<void> saveDailyTaskProgressMap({
    required String childId,
    required Map<String, dynamic> data,
  }) async {
    await _writeMap(_taskProgressKeyFor(childId), data);
  }

  Future<Map<String, dynamic>?> getTaskProgressHistoryMap({
    required String childId,
  }) async {
    return _readMap(_taskHistoryKeyFor(childId));
  }

  Future<void> saveTaskProgressHistoryMap({
    required String childId,
    required Map<String, dynamic> data,
  }) async {
    await _writeMap(_taskHistoryKeyFor(childId), data);
  }

  Future<Map<String, dynamic>?> getPendingTaskProgressSyncMap({
    required String childId,
  }) async {
    return _readMap(_pendingTaskSyncKeyFor(childId));
  }

  Future<void> savePendingTaskProgressSyncMap({
    required String childId,
    required Map<String, dynamic> data,
  }) async {
    await _writeMap(_pendingTaskSyncKeyFor(childId), data);
  }

  String? _uidOrNull() => _auth.currentUser?.uid;

  String? _profileKeyFor(String childId) => _keyFor(childId, 'profile');
  String? _childrenListKeyFor() => _uidKeyFor('children_list');
  String? _behaviorKeyFor(String childId) => _keyFor(childId, 'behavior');
  String? _walletKeyFor(String childId) => _keyFor(childId, 'wallet');
  String? _pendingWalletSyncKeyFor(String childId) =>
      _keyFor(childId, 'wallet_pending_sync');
  String? _taskProgressKeyFor(String childId) =>
      _keyFor(childId, 'task_progress');
  String? _taskHistoryKeyFor(String childId) =>
      _keyFor(childId, 'task_history');
  String? _pendingTaskSyncKeyFor(String childId) =>
      _keyFor(childId, 'task_progress_pending_sync');

  String? _keyFor(String childId, String suffix) {
    final uid = _uidOrNull();
    final cleanChildId = childId.trim();
    if (uid == null || cleanChildId.isEmpty) {
      return null;
    }
    return 'child_local_state_${uid}_${cleanChildId}_$suffix';
  }

  String? _uidKeyFor(String suffix) {
    final uid = _uidOrNull();
    if (uid == null) {
      return null;
    }
    return 'child_local_state_${uid}_$suffix';
  }

  Future<Map<String, dynamic>?> _readMap(String? key) async {
    if (key == null) {
      return null;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null || raw.trim().isEmpty) {
        return null;
      }

      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      return _normalizeMap(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeMap(String? key, Map<String, dynamic> data) async {
    if (key == null) {
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonEncode(data));
    } catch (_) {
      // Ignore local storage failures to avoid blocking app flow.
    }
  }

  Future<List<Map<String, dynamic>>> _readMapList(String? key) async {
    if (key == null) {
      return const <Map<String, dynamic>>[];
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null || raw.trim().isEmpty) {
        return const <Map<String, dynamic>>[];
      }

      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <Map<String, dynamic>>[];
      }

      return decoded
          .whereType<Map>()
          .map(_normalizeMap)
          .toList(growable: false);
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  Future<void> _writeMapList(
    String? key,
    List<Map<String, dynamic>> items,
  ) async {
    if (key == null) {
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonEncode(items));
    } catch (_) {
      // Ignore local storage failures to avoid blocking app flow.
    }
  }

  Map<String, dynamic> _normalizeMap(Map<dynamic, dynamic> map) {
    return map.map(
      (key, value) => MapEntry(key.toString(), _normalizeValue(value)),
    );
  }

  Object? _normalizeValue(Object? value) {
    if (value is Map) {
      return _normalizeMap(value);
    }
    if (value is List) {
      return value.map(_normalizeValue).toList(growable: false);
    }
    return value;
  }
}
