import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:risha_v01/shared/config/feature_flags.dart';
import 'package:risha_v01/shared/services/child_local_state_service.dart';
import 'package:risha_v01/shared/services/device_sleep_lock_service.dart';
import 'package:risha_v01/shared/services/email_notification_service.dart';

class CustomBehaviorConfig {
  const CustomBehaviorConfig({
    required this.id,
    required this.title,
    required this.repeatCount,
    required this.periods,
    this.reminderTimesMinutes = const <int>[],
  });

  final String id;
  final String title;
  final int repeatCount;
  final List<String> periods;
  final List<int> reminderTimesMinutes;

  factory CustomBehaviorConfig.fromMap(Map<String, dynamic> map) {
    final id = (map['id'] as String? ?? '').trim();
    final title = (map['title'] as String? ?? '').trim();
    final repeatCount = _clampInt(
      _toInt(map['repeatCount'], fallback: 1),
      1,
      10,
    );
    final periods = (map['periods'] as List<dynamic>? ?? const <dynamic>[])
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
    final reminderTimesMinutes = _parseReminderTimes(map['reminderTimes']);

    return CustomBehaviorConfig(
      id: id,
      title: title,
      repeatCount: repeatCount,
      periods: periods,
      reminderTimesMinutes: reminderTimesMinutes,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'repeatCount': repeatCount,
      'periods': periods,
      'reminderTimes': reminderTimesMinutes
          .map(
            (minutes) => <String, int>{
              'hour': minutes ~/ 60,
              'minute': minutes % 60,
            },
          )
          .toList(),
    };
  }
}

class ChildBehaviorConfig {
  const ChildBehaviorConfig({
    required this.selectedBehaviorIds,
    required this.customBehaviors,
    required this.waterCupsCount,
    required this.waterReminderTimesMinutes,
    required this.sportSessionsCount,
    required this.sportLightActivityEnabled,
    required this.sportSessionTimesMinutes,
    required this.sleepHour,
    required this.sleepMinute,
    required this.sleepNotificationsEnabled,
    required this.sleepRoutineConfigured,
  });

  final List<String> selectedBehaviorIds;
  final List<CustomBehaviorConfig> customBehaviors;
  final int waterCupsCount;
  final List<int> waterReminderTimesMinutes;
  final int sportSessionsCount;
  final bool sportLightActivityEnabled;
  final List<int> sportSessionTimesMinutes;
  final int sleepHour;
  final int sleepMinute;
  final bool sleepNotificationsEnabled;
  final bool sleepRoutineConfigured;

  factory ChildBehaviorConfig.defaults() {
    return const ChildBehaviorConfig(
      selectedBehaviorIds: <String>['morning_athkar'],
      customBehaviors: <CustomBehaviorConfig>[],
      waterCupsCount: 2,
      waterReminderTimesMinutes: <int>[10 * 60, 15 * 60],
      sportSessionsCount: 1,
      sportLightActivityEnabled: true,
      sportSessionTimesMinutes: <int>[8 * 60],
      sleepHour: 0,
      sleepMinute: 0,
      sleepNotificationsEnabled: true,
      sleepRoutineConfigured: false,
    );
  }

  factory ChildBehaviorConfig.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    final behaviorSettingsRaw = data['behaviorSettings'];
    final behaviorSettings = behaviorSettingsRaw is Map<String, dynamic>
        ? behaviorSettingsRaw
        : behaviorSettingsRaw is Map
        ? behaviorSettingsRaw.map(
            (key, value) => MapEntry(key.toString(), value),
          )
        : const <String, dynamic>{};

    return ChildBehaviorConfig.fromMap(behaviorSettings);
  }

  factory ChildBehaviorConfig.fromMap(Map<String, dynamic> behaviorSettings) {
    final defaults = ChildBehaviorConfig.defaults();

    final selectedBehaviorIds =
        (behaviorSettings['selectedBehaviorIds'] as List<dynamic>? ??
                const <dynamic>[])
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toSet()
            .toList();

    final customBehaviorsRaw =
        behaviorSettings['customBehaviors'] as List<dynamic>? ??
        const <dynamic>[];
    final customBehaviors = customBehaviorsRaw
        .whereType<Map>()
        .map(
          (map) => CustomBehaviorConfig.fromMap(
            map.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .where((item) => item.id.isNotEmpty && item.title.isNotEmpty)
        .toList();

    final waterMap =
        behaviorSettings['water'] as Map<String, dynamic>? ??
        const <String, dynamic>{};
    final sportMap =
        behaviorSettings['sport'] as Map<String, dynamic>? ??
        const <String, dynamic>{};
    final sleepMap =
        behaviorSettings['sleep'] as Map<String, dynamic>? ??
        const <String, dynamic>{};
    final sleepRoutineConfigured =
        sleepMap['configured'] as bool? ??
        (sleepMap.containsKey('hour') && sleepMap.containsKey('minute'));

    final waterCupsCount = _clampInt(
      _toInt(waterMap['cupsCount'], fallback: defaults.waterCupsCount),
      1,
      12,
    );
    final waterReminderTimesMinutes = _normalizeWaterReminderTimes(
      _parseReminderTimes(
        waterMap['reminderTimes'] ?? waterMap['times'] ?? waterMap['cupTimes'],
      ),
      cupsCount: waterCupsCount,
      fallback: defaults.waterReminderTimesMinutes,
    );
    final sportSessionsCount = _clampInt(
      _toInt(sportMap['sessionsCount'], fallback: defaults.sportSessionsCount),
      1,
      6,
    );
    final sportLightActivityEnabled =
        sportMap['lightActivityEnabled'] as bool? ??
        defaults.sportLightActivityEnabled;
    final sportSessionTimesMinutes = _normalizeSportSessionTimes(
      _parseSportSessionTimes(sportMap['sessionTimes']),
      sessionsCount: sportSessionsCount,
      fallback: defaults.sportSessionTimesMinutes,
    );
    final sleepHour = _clampInt(
      _toInt(sleepMap['hour'], fallback: defaults.sleepHour),
      0,
      23,
    );
    final sleepMinute = _clampInt(
      _toInt(sleepMap['minute'], fallback: defaults.sleepMinute),
      0,
      59,
    );
    final sleepNotificationsEnabled =
        sleepMap['notificationsEnabled'] as bool? ??
        defaults.sleepNotificationsEnabled;

    return ChildBehaviorConfig(
      selectedBehaviorIds: selectedBehaviorIds.isEmpty
          ? defaults.selectedBehaviorIds
          : selectedBehaviorIds,
      customBehaviors: customBehaviors,
      waterCupsCount: waterCupsCount,
      waterReminderTimesMinutes: waterReminderTimesMinutes,
      sportSessionsCount: sportSessionsCount,
      sportLightActivityEnabled: sportLightActivityEnabled,
      sportSessionTimesMinutes: sportSessionTimesMinutes,
      sleepHour: sleepHour,
      sleepMinute: sleepMinute,
      sleepNotificationsEnabled: sleepNotificationsEnabled,
      sleepRoutineConfigured: sleepRoutineConfigured,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'selectedBehaviorIds': selectedBehaviorIds.toList(growable: false),
      'customBehaviors': customBehaviors
          .map((item) => item.toMap())
          .toList(growable: false),
      'water': <String, dynamic>{
        'cupsCount': waterCupsCount,
        'reminderTimes': waterReminderTimesMinutes
            .map(
              (minutes) => <String, int>{
                'hour': minutes ~/ 60,
                'minute': minutes % 60,
              },
            )
            .toList(growable: false),
      },
      'sport': <String, dynamic>{
        'sessionsCount': sportSessionsCount,
        'lightActivityEnabled': sportLightActivityEnabled,
        'sessionTimes': sportSessionTimesMinutes
            .map(
              (minutes) => <String, int>{
                'hour': minutes ~/ 60,
                'minute': minutes % 60,
              },
            )
            .toList(growable: false),
      },
      'sleep': <String, dynamic>{
        'hour': sleepHour,
        'minute': sleepMinute,
        'notificationsEnabled': sleepNotificationsEnabled,
        'configured': sleepRoutineConfigured,
      },
    };
  }
}

class ChildBehaviorService {
  ChildBehaviorService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    ChildLocalStateService? localStateService,
    DeviceSleepLockService? deviceSleepLockService,
    EmailNotificationService? emailNotificationService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _localStateService =
           localStateService ?? ChildLocalStateService(auth: auth),
       _deviceSleepLockService =
           deviceSleepLockService ?? DeviceSleepLockService(),
       _emailNotificationService =
           emailNotificationService ??
           EmailNotificationService(
             auth: auth ?? FirebaseAuth.instance,
             firestore: firestore ?? FirebaseFirestore.instance,
           );

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final ChildLocalStateService _localStateService;
  final DeviceSleepLockService _deviceSleepLockService;
  final EmailNotificationService _emailNotificationService;
  final Set<String> _remoteBehaviorSyncInFlight = <String>{};
  final Set<String> _remoteBehaviorRefreshInFlight = <String>{};
  final Map<String, DateTime> _remoteBehaviorLastRefreshAttemptAt =
      <String, DateTime>{};

  static const Duration _remoteReadTimeout = Duration(seconds: 6);
  static const Duration _remoteWriteTimeout = Duration(seconds: 6);
  static const Duration _remoteRefreshMinInterval = Duration(minutes: 2);
  static const List<Duration> _remoteWriteRetryDelays = <Duration>[
    Duration(seconds: 12),
    Duration(seconds: 35),
    Duration(minutes: 1),
  ];
  static final Object _remoteTimeoutSentinel = Object();

  CollectionReference<Map<String, dynamic>> _childrenCollection(String uid) {
    return _firestore.collection('users').doc(uid).collection('children');
  }

  Future<ChildBehaviorConfig> getChildBehaviorConfig({
    required String childId,
  }) async {
    final uid = _requireUid();
    final cleanChildId = _validateChildId(childId);
    final localData = await _localStateService.getBehaviorSettingsMap(
      childId: cleanChildId,
    );
    if (localData != null && localData.isNotEmpty) {
      final localConfig = ChildBehaviorConfig.fromMap(localData);
      unawaited(
        _refreshBehaviorConfigFromRemote(uid: uid, childId: cleanChildId),
      );
      return localConfig;
    }

    final remoteConfig = await _fetchRemoteBehaviorConfig(
      uid: uid,
      childId: cleanChildId,
    );
    if (remoteConfig != null) {
      return remoteConfig;
    }

    final fallbackConfig = ChildBehaviorConfig.defaults();
    await _localStateService.saveBehaviorSettingsMap(
      childId: cleanChildId,
      data: fallbackConfig.toMap(),
    );
    unawaited(
      _refreshBehaviorConfigFromRemote(uid: uid, childId: cleanChildId),
    );
    return fallbackConfig;
  }

  Future<bool> hasPreparedChildSetup({required String childId}) async {
    try {
      await verifyChildSetupPersisted(childId: childId);
      return true;
    } on ChildBehaviorFailure {
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> verifyChildSetupPersisted({required String childId}) async {
    final config = await getChildBehaviorConfig(childId: childId);
    if (config.selectedBehaviorIds.isEmpty) {
      throw const ChildBehaviorFailure(
        'يرجى اختيار سلوك واحد على الأقل قبل المتابعة.',
      );
    }

    if (config.selectedBehaviorIds.contains('drink_water') &&
        (config.waterCupsCount < 1 || config.waterCupsCount > 12)) {
      throw const ChildBehaviorFailure('إعدادات شرب الماء غير مكتملة.');
    }
    if (config.selectedBehaviorIds.contains('drink_water') &&
        config.waterReminderTimesMinutes.length < config.waterCupsCount) {
      throw const ChildBehaviorFailure('أوقات شرب الماء غير مكتملة.');
    }

    if (config.selectedBehaviorIds.contains('sport_activity')) {
      if (config.sportSessionsCount < 1 || config.sportSessionsCount > 6) {
        throw const ChildBehaviorFailure('إعدادات النشاط الرياضي غير مكتملة.');
      }
      if (config.sportSessionTimesMinutes.length < config.sportSessionsCount) {
        throw const ChildBehaviorFailure(
          'أوقات جلسات النشاط الرياضي غير مكتملة.',
        );
      }
    }

    if (!config.sleepRoutineConfigured) {
      throw const ChildBehaviorFailure('وقت النوم غير محفوظ بشكل صحيح.');
    }
    if (config.sleepHour < 0 ||
        config.sleepHour > 23 ||
        config.sleepMinute < 0 ||
        config.sleepMinute > 59) {
      throw const ChildBehaviorFailure('وقت النوم غير محفوظ بشكل صحيح.');
    }
  }

  Future<void> saveSelectedBehaviorIds({
    required String childId,
    required List<String> behaviorIds,
  }) async {
    final cleanIds = behaviorIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    final currentConfig = await getChildBehaviorConfig(childId: childId);
    final nextConfig = ChildBehaviorConfig(
      selectedBehaviorIds: cleanIds,
      customBehaviors: currentConfig.customBehaviors,
      waterCupsCount: currentConfig.waterCupsCount,
      waterReminderTimesMinutes: currentConfig.waterReminderTimesMinutes,
      sportSessionsCount: currentConfig.sportSessionsCount,
      sportLightActivityEnabled: currentConfig.sportLightActivityEnabled,
      sportSessionTimesMinutes: currentConfig.sportSessionTimesMinutes,
      sleepHour: currentConfig.sleepHour,
      sleepMinute: currentConfig.sleepMinute,
      sleepNotificationsEnabled: currentConfig.sleepNotificationsEnabled,
      sleepRoutineConfigured: currentConfig.sleepRoutineConfigured,
    );
    await _persistBehaviorConfig(childId: childId, config: nextConfig);
  }

  Future<void> saveWaterRoutine({
    required String childId,
    required int cupsCount,
    List<int> reminderTimesMinutes = const <int>[],
  }) async {
    final cleanCupsCount = _clampInt(cupsCount, 1, 12);
    final currentConfig = await getChildBehaviorConfig(childId: childId);
    final normalizedWaterReminderTimes = reminderTimesMinutes.isEmpty
        ? _defaultWaterReminderTimes(cleanCupsCount)
        : _normalizeWaterReminderTimes(
            reminderTimesMinutes,
            cupsCount: cleanCupsCount,
            fallback: currentConfig.waterReminderTimesMinutes,
          );
    final nextConfig = ChildBehaviorConfig(
      selectedBehaviorIds: currentConfig.selectedBehaviorIds,
      customBehaviors: currentConfig.customBehaviors,
      waterCupsCount: cleanCupsCount,
      waterReminderTimesMinutes: normalizedWaterReminderTimes,
      sportSessionsCount: currentConfig.sportSessionsCount,
      sportLightActivityEnabled: currentConfig.sportLightActivityEnabled,
      sportSessionTimesMinutes: currentConfig.sportSessionTimesMinutes,
      sleepHour: currentConfig.sleepHour,
      sleepMinute: currentConfig.sleepMinute,
      sleepNotificationsEnabled: currentConfig.sleepNotificationsEnabled,
      sleepRoutineConfigured: currentConfig.sleepRoutineConfigured,
    );
    await _persistBehaviorConfig(childId: childId, config: nextConfig);
  }

  Future<void> saveSportRoutine({
    required String childId,
    required int sessionsCount,
    required bool lightActivityEnabled,
    required List<int> sessionTimesMinutes,
  }) async {
    final cleanSessionsCount = _clampInt(sessionsCount, 1, 6);
    final normalizedTimes = _normalizeSportSessionTimes(
      sessionTimesMinutes,
      sessionsCount: cleanSessionsCount,
      fallback: const <int>[8 * 60],
    );

    final currentConfig = await getChildBehaviorConfig(childId: childId);
    final nextConfig = ChildBehaviorConfig(
      selectedBehaviorIds: currentConfig.selectedBehaviorIds,
      customBehaviors: currentConfig.customBehaviors,
      waterCupsCount: currentConfig.waterCupsCount,
      waterReminderTimesMinutes: currentConfig.waterReminderTimesMinutes,
      sportSessionsCount: cleanSessionsCount,
      sportLightActivityEnabled: lightActivityEnabled,
      sportSessionTimesMinutes: normalizedTimes,
      sleepHour: currentConfig.sleepHour,
      sleepMinute: currentConfig.sleepMinute,
      sleepNotificationsEnabled: currentConfig.sleepNotificationsEnabled,
      sleepRoutineConfigured: currentConfig.sleepRoutineConfigured,
    );
    await _persistBehaviorConfig(childId: childId, config: nextConfig);
  }

  Future<void> saveSleepRoutine({
    required String childId,
    required int hour,
    required int minute,
    required bool notificationsEnabled,
  }) async {
    final currentConfig = await getChildBehaviorConfig(childId: childId);
    final nextConfig = ChildBehaviorConfig(
      selectedBehaviorIds: currentConfig.selectedBehaviorIds,
      customBehaviors: currentConfig.customBehaviors,
      waterCupsCount: currentConfig.waterCupsCount,
      waterReminderTimesMinutes: currentConfig.waterReminderTimesMinutes,
      sportSessionsCount: currentConfig.sportSessionsCount,
      sportLightActivityEnabled: currentConfig.sportLightActivityEnabled,
      sportSessionTimesMinutes: currentConfig.sportSessionTimesMinutes,
      sleepHour: _clampInt(hour, 0, 23),
      sleepMinute: _clampInt(minute, 0, 59),
      sleepNotificationsEnabled: notificationsEnabled,
      sleepRoutineConfigured: true,
    );
    await _persistBehaviorConfig(childId: childId, config: nextConfig);
  }

  Future<void> clearDeviceSleepLock() async {
    await _deviceSleepLockService.clearSleepLockConfig();
  }

  Future<void> syncDeviceSleepLockForChild({
    required String childId,
    String? childName,
  }) async {
    final cleanChildId = _validateChildId(childId);
    if (FeatureFlags.disableSleepLockTemporarily) {
      await _deviceSleepLockService.clearSleepLockConfig();
      return;
    }
    final config = await getChildBehaviorConfig(childId: cleanChildId);
    await _deviceSleepLockService.syncSleepLockConfig(
      childId: cleanChildId,
      childName: childName,
      configured: config.sleepRoutineConfigured,
      enabled: config.sleepNotificationsEnabled,
      sleepHour: config.sleepHour,
      sleepMinute: config.sleepMinute,
    );
  }

  Future<void> addCustomBehavior({
    required String childId,
    required String title,
    required int repeatCount,
    required List<String> periods,
    List<int> reminderTimesMinutes = const <int>[],
  }) async {
    final cleanChildId = _validateChildId(childId);
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) {
      throw const ChildBehaviorFailure('الرجاء إدخال اسم السلوك.');
    }

    final cleanRepeatCount = _clampInt(repeatCount, 1, 10);
    final cleanPeriods = periods
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
    final normalizedReminderTimes = _normalizeCustomReminderTimes(
      reminderTimesMinutes,
      repeatCount: cleanRepeatCount,
      fallback: const <int>[8 * 60],
    );
    final behaviorId = 'custom_${DateTime.now().microsecondsSinceEpoch}';

    final currentConfig = await getChildBehaviorConfig(childId: cleanChildId);
    final updatedCustomBehaviors = <CustomBehaviorConfig>[
      ...currentConfig.customBehaviors,
      CustomBehaviorConfig(
        id: behaviorId,
        title: cleanTitle,
        repeatCount: cleanRepeatCount,
        periods: cleanPeriods,
        reminderTimesMinutes: normalizedReminderTimes,
      ),
    ];
    final selectedIds = <String>{
      ...currentConfig.selectedBehaviorIds,
      behaviorId,
    }.toList(growable: false);

    final nextConfig = ChildBehaviorConfig(
      selectedBehaviorIds: selectedIds,
      customBehaviors: updatedCustomBehaviors,
      waterCupsCount: currentConfig.waterCupsCount,
      waterReminderTimesMinutes: currentConfig.waterReminderTimesMinutes,
      sportSessionsCount: currentConfig.sportSessionsCount,
      sportLightActivityEnabled: currentConfig.sportLightActivityEnabled,
      sportSessionTimesMinutes: currentConfig.sportSessionTimesMinutes,
      sleepHour: currentConfig.sleepHour,
      sleepMinute: currentConfig.sleepMinute,
      sleepNotificationsEnabled: currentConfig.sleepNotificationsEnabled,
      sleepRoutineConfigured: currentConfig.sleepRoutineConfigured,
    );
    await _persistBehaviorConfig(childId: cleanChildId, config: nextConfig);
  }

  Future<void> _persistBehaviorConfig({
    required String childId,
    required ChildBehaviorConfig config,
  }) async {
    final uid = _requireUid();
    final cleanChildId = _validateChildId(childId);
    await _localStateService.saveBehaviorSettingsMap(
      childId: cleanChildId,
      data: config.toMap(),
    );
    _scheduleBehaviorConfigRemoteSync(uid: uid, childId: cleanChildId);
    _syncBehaviorConfigEmail(childId: cleanChildId, config: config);
  }

  Future<ChildBehaviorConfig?> _fetchRemoteBehaviorConfig({
    required String uid,
    required String childId,
  }) async {
    try {
      final doc = await _readChildDocWithSoftTimeout(
        uid: uid,
        childId: childId,
      );
      if (doc == null) {
        return null;
      }
      if (!doc.exists) {
        return null;
      }
      final config = ChildBehaviorConfig.fromDocument(doc);
      await _localStateService.saveBehaviorSettingsMap(
        childId: childId,
        data: config.toMap(),
      );
      return config;
    } on FirebaseException catch (e) {
      if (_shouldUseLocalFallback(e)) {
        return null;
      }
      throw ChildBehaviorFailure(_mapFirebaseError(e));
    }
  }

  Future<void> _refreshBehaviorConfigFromRemote({
    required String uid,
    required String childId,
  }) async {
    final refreshKey = '$uid|$childId';
    final now = DateTime.now();
    final lastAttemptAt = _remoteBehaviorLastRefreshAttemptAt[refreshKey];
    if (_remoteBehaviorRefreshInFlight.contains(refreshKey)) {
      return;
    }
    if (lastAttemptAt != null &&
        now.difference(lastAttemptAt) < _remoteRefreshMinInterval) {
      return;
    }
    _remoteBehaviorLastRefreshAttemptAt[refreshKey] = now;
    _remoteBehaviorRefreshInFlight.add(refreshKey);
    try {
      await _fetchRemoteBehaviorConfig(uid: uid, childId: childId);
    } catch (_) {
      // Keep local-first reads fast even when remote refresh fails.
    } finally {
      _remoteBehaviorRefreshInFlight.remove(refreshKey);
    }
  }

  void _scheduleBehaviorConfigRemoteSync({
    required String uid,
    required String childId,
  }) {
    unawaited(_pushLatestBehaviorConfigToRemote(uid: uid, childId: childId));
    for (final delay in _remoteWriteRetryDelays) {
      unawaited(
        Future<void>.delayed(delay, () async {
          await _pushLatestBehaviorConfigToRemote(uid: uid, childId: childId);
        }),
      );
    }
  }

  Future<void> _pushLatestBehaviorConfigToRemote({
    required String uid,
    required String childId,
  }) async {
    final syncKey = '$uid|$childId';
    if (_remoteBehaviorSyncInFlight.contains(syncKey)) {
      return;
    }

    _remoteBehaviorSyncInFlight.add(syncKey);
    try {
      final localData = await _localStateService.getBehaviorSettingsMap(
        childId: childId,
      );
      if (localData == null || localData.isEmpty) {
        return;
      }
      await _setBehaviorConfigWithSoftTimeout(
        uid: uid,
        childId: childId,
        data: localData,
      );
    } catch (_) {
      // Best-effort remote sync to keep UI responsive.
    } finally {
      _remoteBehaviorSyncInFlight.remove(syncKey);
    }
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> _readChildDocWithSoftTimeout({
    required String uid,
    required String childId,
  }) async {
    return _awaitOrNullOnSoftTimeout(
      _childrenCollection(uid).doc(childId).get(),
      timeout: _remoteReadTimeout,
    );
  }

  Future<void> _setBehaviorConfigWithSoftTimeout({
    required String uid,
    required String childId,
    required Map<String, dynamic> data,
  }) async {
    await _awaitOrNullOnSoftTimeout<void>(
      _childrenCollection(uid).doc(childId).set({
        'behaviorSettings': data,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)),
      timeout: _remoteWriteTimeout,
    );
  }

  Future<T?> _awaitOrNullOnSoftTimeout<T>(
    Future<T> future, {
    required Duration timeout,
  }) async {
    final result = await Future.any<Object?>(<Future<Object?>>[
      future
          .then<Object?>((value) => value)
          .catchError(
            (Object error, StackTrace stackTrace) =>
                _BehaviorSoftTimeoutFailure(error, stackTrace),
          ),
      Future<Object?>.delayed(timeout, () => _remoteTimeoutSentinel),
    ]);
    if (identical(result, _remoteTimeoutSentinel)) {
      return null;
    }
    if (result is _BehaviorSoftTimeoutFailure) {
      Error.throwWithStackTrace(result.error, result.stackTrace);
    }
    return result == null ? null : result as T;
  }

  void _syncBehaviorConfigEmail({
    required String childId,
    required ChildBehaviorConfig config,
  }) {
    unawaited(
      _emailNotificationService.syncChildBehaviorConfig(
        childId: childId,
        behaviorConfig: config.toMap(),
      ),
    );
  }

  bool _shouldUseLocalFallback(FirebaseException e) {
    final message = e.message ?? '';
    final normalizedMessage = message.toLowerCase();
    final normalizedCode = e.code.trim().toLowerCase();
    return normalizedCode == 'permission-denied' ||
        normalizedCode.endsWith('/permission-denied') ||
        normalizedCode == 'unavailable' ||
        normalizedCode.endsWith('/unavailable') ||
        normalizedCode == 'resource-exhausted' ||
        normalizedCode.endsWith('/resource-exhausted') ||
        normalizedCode == 'deadline-exceeded' ||
        normalizedCode.endsWith('/deadline-exceeded') ||
        message.contains('Cloud Firestore API has not been used') ||
        normalizedMessage.contains('resource-exhausted') ||
        normalizedMessage.contains('quota') ||
        normalizedMessage.contains('exceeded') ||
        normalizedMessage.contains('network') ||
        normalizedMessage.contains('timeout') ||
        normalizedMessage.contains('timed out') ||
        normalizedMessage.contains('deadline exceeded') ||
        normalizedMessage.contains('deadline-exceeded') ||
        normalizedMessage.contains('unable to resolve host');
  }

  String _requireUid() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw const ChildBehaviorFailure('يجب تسجيل الدخول أولاً.');
    }
    return uid;
  }

  String _validateChildId(String childId) {
    final cleanId = childId.trim();
    if (cleanId.isEmpty) {
      throw const ChildBehaviorFailure('لم يتم اختيار الطفل بعد.');
    }
    return cleanId;
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
        return 'تم تجاوز حصة Firestore الحالية. سيستخدم التطبيق إعدادات السلوك المحلية ويحاول المزامنة لاحقاً.';
      case 'not-found':
        return 'لم يتم العثور على ملف الطفل المحدد.';
      default:
        return 'تعذر حفظ إعدادات السلوكيات حالياً. حاول مرة أخرى.';
    }
  }
}

class ChildBehaviorFailure implements Exception {
  const ChildBehaviorFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

class _BehaviorSoftTimeoutFailure {
  const _BehaviorSoftTimeoutFailure(this.error, this.stackTrace);

  final Object error;
  final StackTrace stackTrace;
}

List<int> _parseSportSessionTimes(dynamic rawValue) {
  if (rawValue is! List<dynamic>) {
    return const <int>[];
  }

  final parsed = <int>[];
  for (final item in rawValue) {
    if (item is Map<dynamic, dynamic>) {
      final hour = _toInt(item['hour'], fallback: -1);
      final minute = _toInt(item['minute'], fallback: -1);
      if (hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59) {
        parsed.add(hour * 60 + minute);
      }
      continue;
    }

    final parsedMinutes = _parseMinutesValue(item);
    if (parsedMinutes != null) {
      parsed.add(parsedMinutes);
    }
  }

  return parsed;
}

List<int> _parseReminderTimes(dynamic rawValue) {
  if (rawValue is! List<dynamic>) {
    return const <int>[];
  }

  final parsed = <int>[];
  for (final item in rawValue) {
    if (item is Map<dynamic, dynamic>) {
      final hour = _toInt(item['hour'], fallback: -1);
      final minute = _toInt(item['minute'], fallback: -1);
      if (hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59) {
        parsed.add(hour * 60 + minute);
      }
      continue;
    }

    final parsedMinutes = _parseMinutesValue(item);
    if (parsedMinutes != null) {
      parsed.add(parsedMinutes);
    }
  }

  return parsed;
}

List<int> _normalizeWaterReminderTimes(
  List<int> rawTimes, {
  required int cupsCount,
  required List<int> fallback,
}) {
  final cleanCount = _clampInt(cupsCount, 1, 12);
  final cleanRaw = rawTimes
      .map((value) => _clampInt(value, 0, 1439))
      .toList(growable: false);
  final cleanFallback = fallback.isEmpty
      ? _defaultWaterReminderTimes(cleanCount)
      : fallback
            .map((value) => _clampInt(value, 0, 1439))
            .toList(growable: false);

  final normalized = <int>[];
  for (var i = 0; i < cleanCount; i++) {
    if (i < cleanRaw.length) {
      normalized.add(cleanRaw[i]);
      continue;
    }
    if (i < cleanFallback.length) {
      normalized.add(cleanFallback[i]);
      continue;
    }
    normalized.add(((8 * 60) + ((i + 1) * 60)) % (24 * 60));
  }

  normalized.sort((a, b) => a.compareTo(b));
  return normalized;
}

int? _parseMinutesValue(dynamic value) {
  if (value is int) {
    return value >= 0 && value <= 1439 ? value : null;
  }
  if (value is num) {
    final minutes = value.toInt();
    return minutes >= 0 && minutes <= 1439 ? minutes : null;
  }
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final asNumber = int.tryParse(trimmed);
    if (asNumber != null) {
      return asNumber >= 0 && asNumber <= 1439 ? asNumber : null;
    }

    final parts = trimmed.split(':');
    if (parts.length == 2) {
      final hour = int.tryParse(parts.first);
      final minute = int.tryParse(parts.last);
      if (hour != null &&
          minute != null &&
          hour >= 0 &&
          hour <= 23 &&
          minute >= 0 &&
          minute <= 59) {
        return hour * 60 + minute;
      }
    }
  }
  return null;
}

List<int> _normalizeSportSessionTimes(
  List<int> rawTimes, {
  required int sessionsCount,
  required List<int> fallback,
}) {
  final cleanCount = _clampInt(sessionsCount, 1, 6);
  final cleanRaw = rawTimes
      .map((value) => _clampInt(value, 0, 1439))
      .toList(growable: false);
  final cleanFallback = fallback
      .map((value) => _clampInt(value, 0, 1439))
      .toList(growable: false);

  final normalized = <int>[];
  for (var i = 0; i < cleanCount; i++) {
    if (i < cleanRaw.length) {
      normalized.add(cleanRaw[i]);
      continue;
    }
    if (i < cleanFallback.length) {
      normalized.add(cleanFallback[i]);
      continue;
    }

    if (normalized.isEmpty) {
      normalized.add(8 * 60);
    } else {
      normalized.add((normalized.last + 60) % (24 * 60));
    }
  }

  return normalized;
}

List<int> _normalizeCustomReminderTimes(
  List<int> rawTimes, {
  required int repeatCount,
  required List<int> fallback,
}) {
  final cleanCount = _clampInt(repeatCount, 1, 10);
  final cleanRaw = rawTimes
      .map((value) => _clampInt(value, 0, 1439))
      .toList(growable: false);
  final cleanFallback = fallback
      .map((value) => _clampInt(value, 0, 1439))
      .toList(growable: false);

  final normalized = <int>[];
  for (var i = 0; i < cleanCount; i++) {
    if (i < cleanRaw.length) {
      normalized.add(cleanRaw[i]);
      continue;
    }
    if (i < cleanFallback.length) {
      normalized.add(cleanFallback[i]);
      continue;
    }

    if (normalized.isEmpty) {
      normalized.add(8 * 60);
    } else {
      normalized.add((normalized.last + 60) % (24 * 60));
    }
  }

  return normalized;
}

List<int> _defaultWaterReminderTimes(int cupsCount) {
  final cleanCount = _clampInt(cupsCount, 1, 12);
  const startMinutes = 8 * 60;
  const endMinutes = 20 * 60;
  const minIntervalMinutes = 60;
  const maxIntervalMinutes = 120;
  final availableSpan = endMinutes - startMinutes;
  if (cleanCount == 1) {
    return const <int>[14 * 60];
  }

  final equalInterval = (availableSpan / cleanCount).round();
  final interval = _clampInt(
    equalInterval,
    minIntervalMinutes,
    maxIntervalMinutes,
  );
  final consumedSpan = interval * (cleanCount - 1);
  final centeredStart = startMinutes + ((availableSpan - consumedSpan) ~/ 2);
  return List<int>.generate(cleanCount, (index) {
    return centeredStart + (interval * index);
  }, growable: false);
}

int _toInt(dynamic value, {required int fallback}) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value) ?? fallback;
  }
  return fallback;
}

int _clampInt(int value, int min, int max) {
  if (value < min) {
    return min;
  }
  if (value > max) {
    return max;
  }
  return value;
}
