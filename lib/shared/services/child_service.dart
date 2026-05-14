import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:risha_v01/shared/services/child_behavior_service.dart';

import 'package:risha_v01/shared/services/child_local_state_service.dart';
import 'package:risha_v01/shared/services/child_reward_service.dart';
import 'package:risha_v01/shared/services/email_notification_service.dart';

class ChildProfile {
  const ChildProfile({
    required this.id,
    required this.name,
    this.avatarBase64,
    this.ageYears,
  });

  final String id;
  final String name;
  final String? avatarBase64;
  final int? ageYears;

  factory ChildProfile.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return ChildProfile.fromMap(doc.data() ?? <String, dynamic>{}, id: doc.id);
  }

  factory ChildProfile.fromMap(
    Map<String, dynamic> data, {
    required String id,
  }) {
    return ChildProfile(
      id: id,
      name: (data['name'] as String? ?? '').trim(),
      avatarBase64: data['avatarBase64'] as String?,
      ageYears: _parseAgeYears(data['ageYears']),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'name': name,
      if (ageYears != null) 'ageYears': ageYears,
      if (avatarBase64 != null && avatarBase64!.trim().isNotEmpty)
        'avatarBase64': avatarBase64!.trim(),
    };
  }

  static int? _parseAgeYears(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value.trim());
    }
    return null;
  }
}

class ChildService {
  ChildService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    ChildLocalStateService? localStateService,
    EmailNotificationService? emailNotificationService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _localStateService =
           localStateService ?? ChildLocalStateService(auth: auth),
       _emailNotificationService =
           emailNotificationService ??
           EmailNotificationService(
             auth: auth ?? FirebaseAuth.instance,
             firestore: firestore ?? FirebaseFirestore.instance,
           );

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final ChildLocalStateService _localStateService;
  final EmailNotificationService _emailNotificationService;
  static const Duration _remoteRequestTimeout = Duration(seconds: 6);

  CollectionReference<Map<String, dynamic>> _childrenCollection(String uid) {
    return _firestore.collection('users').doc(uid).collection('children');
  }

  Stream<List<ChildProfile>> watchChildren() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return Stream.value(const <ChildProfile>[]);
    }

    Stream<List<ChildProfile>> stream() async* {
      try {
        await for (final snapshot in _childrenCollection(
          uid,
        ).orderBy('createdAt', descending: false).snapshots()) {
          final children = snapshot.docs
              .map(ChildProfile.fromDocument)
              .where((child) {
                return child.name.isNotEmpty;
              })
              .toList(growable: false);
          unawaited(_cacheChildren(children));
          yield children;
        }
      } on FirebaseException catch (e) {
        if (_shouldUseLocalFallback(e)) {
          yield await getCachedChildren();
          return;
        }
        rethrow;
      }
    }

    return stream();
  }

  Future<List<ChildProfile>> getCachedChildren() async {
    final items = await _localStateService.getChildrenListMaps();
    return items
        .map((item) {
          final id = (item['id'] as String? ?? '').trim();
          if (id.isEmpty) {
            return null;
          }
          final child = ChildProfile.fromMap(item, id: id);
          return child.name.isEmpty ? null : child;
        })
        .whereType<ChildProfile>()
        .toList(growable: false);
  }

  Future<ChildProfile> getChildById({required String childId}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw const ChildFailure('Please sign in first.');
    }

    final localData = await _localStateService.getChildProfileMap(
      childId: childId,
    );
    if (localData != null && localData.isNotEmpty) {
      final localChild = ChildProfile.fromMap(localData, id: childId);
      unawaited(_refreshChildByIdFromRemote(uid: uid, childId: childId));
      if (localChild.name.isNotEmpty) {
        return localChild;
      }
    }

    try {
      final doc = await _childrenCollection(
        uid,
      ).doc(childId).get().timeout(_remoteRequestTimeout);

      if (!doc.exists) {
        throw const ChildFailure('Child profile was not found.');
      }
      final child = ChildProfile.fromDocument(doc);
      await _cacheChild(child);
      return child;
    } on FirebaseException catch (e) {
      if (_shouldUseLocalFallback(e)) {
        return _getLocalOrFallbackChild(childId);
      }
      throw ChildFailure(_mapFirebaseError(e));
    } on TimeoutException {
      return _getLocalOrFallbackChild(childId);
    }
  }

  Future<void> _refreshChildByIdFromRemote({
    required String uid,
    required String childId,
  }) async {
    try {
      final doc = await _childrenCollection(
        uid,
      ).doc(childId).get().timeout(_remoteRequestTimeout);
      if (!doc.exists) {
        return;
      }
      final child = ChildProfile.fromDocument(doc);
      await _cacheChild(child);
    } catch (_) {
      // Keep local-first reads responsive.
    }
  }

  Future<void> addChild({
    required String name,
    required int ageYears,
    String? avatarBase64,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw const ChildFailure('يجب تسجيل الدخول أولاً لإضافة طفل.');
    }

    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw const ChildFailure('الرجاء إدخال اسم الطفل.');
    }
    if (ageYears < 3 || ageYears > 30) {
      throw const ChildFailure('عمر الطفل يجب أن يكون بين 3 و30 سنة.');
    }
    final cleanAvatar = avatarBase64?.trim();
    final childData = <String, dynamic>{
      'uid': uid,
      'name': cleanName,
      'ageYears': ageYears,
      'coins': ChildRewardService.defaultCoins,
      'ownedMarketItemAssetPaths': const <String>[],
      'levelState': ChildLevelState.defaults().toMap(),
      'behaviorSettings': ChildBehaviorConfig.defaults().toMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (cleanAvatar != null && cleanAvatar.isNotEmpty) {
      childData['avatarBase64'] = cleanAvatar;
    }

    final childDoc = _childrenCollection(uid).doc();
    final nextChild = _buildChildProfile(
      id: childDoc.id,
      name: cleanName,
      ageYears: ageYears,
      avatarBase64: cleanAvatar,
    );

    try {
      // Persist to Firestore first.
      await childDoc.set(childData).timeout(const Duration(seconds: 20));
      await _firestore.waitForPendingWrites().timeout(
        const Duration(seconds: 12),
      );
      final serverDoc = await childDoc
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 12));
      if (!serverDoc.exists) {
        throw const ChildFailure(
          'لم يتم تأكيد حفظ الطفل في قاعدة البيانات. حاول مرة أخرى.',
        );
      }
    } on ChildFailure {
      rethrow;
    } on FirebaseException catch (e) {
      throw ChildFailure(_mapFirebaseError(e));
    } on TimeoutException {
      throw const ChildFailure(
        'انتهت مهلة الاتصال بقاعدة البيانات أثناء إضافة الطفل. تحقق من الاتصال ثم حاول مرة أخرى.',
      );
    }

    try {
      await _cacheChild(nextChild, appendIfMissing: true);
    } catch (_) {
      // Local cache update is best-effort after confirmed Firestore write.
    }

    unawaited(
      _emailNotificationService
          .syncChildProfile(
            childId: nextChild.id,
            childName: nextChild.name,
            ageYears: nextChild.ageYears,
            avatarBase64: nextChild.avatarBase64,
          )
          .catchError((_) {}),
    );

    unawaited(
      _emailNotificationService.queueChildAddedEmail(
        childId: nextChild.id,
        childName: nextChild.name,
      ),
    );
  }

  Future<void> updateChild({
    required String childId,
    required String name,
    int? ageYears,
    String? avatarBase64,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw const ChildFailure('يجب تسجيل الدخول أولاً.');
    }

    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw const ChildFailure('الرجاء إدخال اسم الطفل.');
    }
    if (ageYears != null && ageYears < 3) {
      throw const ChildFailure('عمر الطفل يجب أن يكون 3 سنوات فأكثر.');
    }
    final cleanAvatar = avatarBase64?.trim();
    final existingChild = await _getLocalOrFallbackChild(childId);
    final updateData = <String, dynamic>{
      'name': cleanName,
      'updatedAt': FieldValue.serverTimestamp(),
      'avatarBase64': cleanAvatar == null || cleanAvatar.isEmpty
          ? FieldValue.delete()
          : cleanAvatar,
      ...?((ageYears == null) ? null : <String, dynamic>{'ageYears': ageYears}),
    };

    final nextChild = _buildChildProfile(
      id: childId,
      name: cleanName,
      ageYears: ageYears ?? existingChild.ageYears,
      avatarBase64: cleanAvatar,
    );

    try {
      await _childrenCollection(uid)
          .doc(childId)
          .set(updateData, SetOptions(merge: true))
          .timeout(const Duration(seconds: 20));
      await _cacheChild(nextChild);
      unawaited(
        _emailNotificationService.syncChildProfile(
          childId: nextChild.id,
          childName: nextChild.name,
          ageYears: nextChild.ageYears,
          avatarBase64: nextChild.avatarBase64,
        ),
      );
      unawaited(
        _emailNotificationService.queueChildUpdatedEmail(
          childId: nextChild.id,
          childName: nextChild.name,
        ),
      );
    } on FirebaseException catch (e) {
      if (_shouldUseLocalFallback(e)) {
        await _cacheChild(nextChild);
        return;
      }
      throw ChildFailure(_mapFirebaseError(e));
    } on TimeoutException {
      await _cacheChild(nextChild);
      return;
    }
  }

  Future<void> deleteChild(String childId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw const ChildFailure('Please sign in first.');
    }

    final cleanChildId = childId.trim();
    if (cleanChildId.isEmpty) {
      return;
    }

    String? childName;
    try {
      final child = await _getLocalOrFallbackChild(cleanChildId);
      final cleanName = child.name.trim();
      childName = cleanName.isEmpty ? null : cleanName;
    } catch (_) {
      childName = null;
    }

    ChildFailure? pendingFailure;
    var firestoreDeleteConfirmed = false;
    try {
      await _childrenCollection(
        uid,
      ).doc(cleanChildId).delete().timeout(const Duration(seconds: 20));
      firestoreDeleteConfirmed = true;
    } on FirebaseException catch (e) {
      if (!_shouldUseLocalFallback(e)) {
        pendingFailure = ChildFailure(_mapFirebaseError(e));
      }
    } on TimeoutException {
      // Continue with local removal + immediate Apps Script delete.
    }

    if (firestoreDeleteConfirmed) {
      try {
        final check = await _childrenCollection(
          uid,
        ).doc(cleanChildId).get().timeout(_remoteRequestTimeout);
        if (check.exists) {
          pendingFailure ??= const ChildFailure(
            'تم إرسال طلب الحذف لكن ملف الطفل ما زال موجوداً في قاعدة البيانات. حاول مرة أخرى.',
          );
        }
      } on FirebaseException catch (e) {
        if (!_shouldUseLocalFallback(e)) {
          pendingFailure ??= ChildFailure(_mapFirebaseError(e));
        }
      } on TimeoutException {
        // Verification is best-effort.
      }
    }

    try {
      await _removeCachedChild(cleanChildId);
    } catch (_) {
      // Local cache cleanup is best-effort.
    }

    try {
      await _emailNotificationService.deleteChildNow(
        childId: cleanChildId,
        childName: childName,
      );
    } on EmailNotificationFailure catch (e) {
      final isEmailTimeout = _emailNotificationService.isRequestTimeoutFailure(
        e,
      );
      if (isEmailTimeout && firestoreDeleteConfirmed) {
        unawaited(
          _emailNotificationService.queueChildDeletedSync(
            childId: cleanChildId,
            childName: childName,
          ),
        );
      } else {
        pendingFailure = ChildFailure(e.message);
      }
    } catch (_) {
      pendingFailure ??= const ChildFailure(
        'تم حذف الطفل محليًا لكن تعذر حذفه فورياً من خدمة Google Apps Script.',
      );
    }

    if (pendingFailure != null) {
      throw pendingFailure;
    }
  }

  String _mapFirebaseError(FirebaseException e) {
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
        return 'تم تجاوز حصة Firestore الحالية. سيستخدم التطبيق البيانات المحلية ويحاول المزامنة لاحقاً.';
      default:
        return 'تعذر تنفيذ العملية حالياً. حاول مرة أخرى.';
    }
  }

  bool _shouldUseLocalFallback(FirebaseException e) {
    final message = e.message ?? '';
    final normalizedCode = e.code.trim().toLowerCase();
    final normalizedMessage = message.toLowerCase();
    return normalizedCode == 'permission-denied' ||
        normalizedCode == 'unavailable' ||
        normalizedCode == 'resource-exhausted' ||
        message.contains('Cloud Firestore API has not been used') ||
        normalizedMessage.contains('resource-exhausted') ||
        normalizedMessage.contains('quota') ||
        normalizedMessage.contains('exceeded') ||
        normalizedMessage.contains('network') ||
        normalizedMessage.contains('timeout') ||
        normalizedMessage.contains('timed out') ||
        normalizedMessage.contains('unable to resolve host');
  }

  ChildProfile _buildChildProfile({
    required String id,
    required String name,
    int? ageYears,
    String? avatarBase64,
  }) {
    final cleanAvatar = avatarBase64?.trim();
    return ChildProfile(
      id: id,
      name: name,
      ageYears: ageYears,
      avatarBase64: cleanAvatar == null || cleanAvatar.isEmpty
          ? null
          : cleanAvatar,
    );
  }

  Future<ChildProfile> _getLocalOrFallbackChild(String childId) async {
    final localData = await _localStateService.getChildProfileMap(
      childId: childId,
    );
    if (localData != null) {
      return ChildProfile.fromMap(localData, id: childId);
    }

    return ChildProfile(id: childId, name: 'الطفل');
  }

  Future<void> _cacheChildren(List<ChildProfile> children) async {
    final items = <Map<String, dynamic>>[];
    for (final child in children) {
      await _localStateService.saveChildProfileMap(
        childId: child.id,
        data: child.toMap(),
      );
      items.add(<String, dynamic>{'id': child.id, ...child.toMap()});
    }
    await _localStateService.saveChildrenListMaps(items);
  }

  Future<void> _removeCachedChild(String childId) async {
    await _localStateService.deleteChildProfileMap(childId: childId);
    final children = await getCachedChildren();
    final updatedChildren = children.where((child) => child.id != childId);
    await _localStateService.saveChildrenListMaps(
      updatedChildren
          .map((item) => <String, dynamic>{'id': item.id, ...item.toMap()})
          .toList(growable: false),
    );
  }

  Future<void> _cacheChild(
    ChildProfile child, {
    bool appendIfMissing = false,
  }) async {
    await _localStateService.saveChildProfileMap(
      childId: child.id,
      data: child.toMap(),
    );

    final children = await getCachedChildren();
    final merged = <ChildProfile>[];
    var replaced = false;
    for (final item in children) {
      if (item.id == child.id) {
        merged.add(child);
        replaced = true;
      } else {
        merged.add(item);
      }
    }
    if (!replaced) {
      if (appendIfMissing) {
        merged.add(child);
      } else {
        merged.insert(0, child);
      }
    }

    await _localStateService.saveChildrenListMaps(
      merged
          .map((item) => <String, dynamic>{'id': item.id, ...item.toMap()})
          .toList(growable: false),
    );
  }
}

class ChildFailure implements Exception {
  const ChildFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
