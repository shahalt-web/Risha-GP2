import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:risha_v01/shared/config/apps_script_email_config.dart';

class EmailCodeRequestResult {
  const EmailCodeRequestResult({
    required this.sent,
    required this.message,
    this.cooldownSeconds = 0,
  });

  final bool sent;
  final String message;
  final int cooldownSeconds;
}

class EmailNotificationService {
  static const int _maxDurableOutboxSize = 120;
  static const Duration _pendingRewardRetryInterval = Duration(seconds: 45);
  static const Duration _bestEffortRequestTimeout = Duration(seconds: 8);
  static const int _maxTransientRequestAttempts = 2;
  static const Duration _transientRetryBaseDelay = Duration(milliseconds: 300);
  static final Set<String> _durableOutboxSyncInFlight = <String>{};
  static Timer? _pendingRewardRetryTimer;
  static bool _pendingRewardRetryLoopStarted = false;
  static bool _backgroundDispatchEnabled = false;
  static bool _pendingRewardLoopRequested = false;
  static Map<String, dynamic>? _cachedUserSnapshot;
  static DateTime? _cachedUserSnapshotAt;
  static const Duration _userSnapshotCacheTtl = Duration(seconds: 60);

  // Fix: Local throttling to prevent duplicate email events from client side
  static final Map<String, DateTime> _recentlySentEvents = <String, DateTime>{};
  static const Duration _eventThrottleDuration = Duration(minutes: 5);

  EmailNotificationService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    http.Client? httpClient,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _httpClient = httpClient ?? http.Client();

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final http.Client _httpClient;

  bool get isBackgroundDispatchEnabled => _backgroundDispatchEnabled;

  void enableBackgroundDispatch() {
    _backgroundDispatchEnabled = true;
    flushDurableOutboxInBackground();
    if (_pendingRewardLoopRequested) {
      startPendingRewardEmailSyncLoop();
    }
  }

  void disableBackgroundDispatch({bool stopRetryLoop = false}) {
    _backgroundDispatchEnabled = false;
    if (stopRetryLoop) {
      _pendingRewardRetryTimer?.cancel();
      _pendingRewardRetryTimer = null;
      _pendingRewardRetryLoopStarted = false;
    }
  }

  Future<bool> isCurrentUserEmailVerified() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return false;
    }

    if (currentUser.emailVerified) {
      return true;
    }

    try {
      await currentUser.reload().timeout(const Duration(seconds: 12));
    } catch (_) {
      // Firestore remains the source of truth when Apps Script is used.
    }

    final refreshedUser = _auth.currentUser;
    if (refreshedUser?.emailVerified == true) {
      return true;
    }

    try {
      final doc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get()
          .timeout(const Duration(seconds: 12));
      final data = doc.data() ?? const <String, dynamic>{};
      final verification = _normalizeMap(data['emailVerification']);
      return verification['isVerified'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> syncCurrentUserProfile() async {
    final user = _auth.currentUser;
    if (user == null || !_isConfigured) {
      return;
    }

    try {
      await _postAction(
        action: 'sync_user_profile',
        payload: <String, dynamic>{'user': await _buildCurrentUserSnapshot()},
        requireConfigured: false,
        requestTimeout: _bestEffortRequestTimeout,
      );
    } catch (_) {
      // Profile sync is best-effort and must not interrupt app flow.
    }
  }

  Future<Map<String, dynamic>> sendScheduledReportTestEmail({
    required String email,
  }) async {
    final normalizedEmail = _normalizeEmail(email);
    if (normalizedEmail.isEmpty) {
      throw const EmailNotificationFailure('أدخل البريد الإلكتروني أولًا.');
    }

    return _postAction(
      action: 'send_scheduled_report_test_email',
      payload: <String, dynamic>{'email': normalizedEmail},
      requireConfigured: true,
      retryEnabled: false,
    );
  }

  Future<Map<String, dynamic>> sendCompletedTasksReportPipelineTest({
    required String email,
  }) async {
    final normalizedEmail = _normalizeEmail(email);
    if (normalizedEmail.isEmpty) {
      throw const EmailNotificationFailure('أدخل البريد الإلكتروني أولًا.');
    }

    return _postAction(
      action: 'send_completed_tasks_report_pipeline_test',
      payload: <String, dynamic>{'email': normalizedEmail},
      requireConfigured: true,
      retryEnabled: false,
    );
  }

  void flushDurableOutboxInBackground() {
    _runSafelyInBackground(flushDurableOutbox);
  }

  Future<EmailCodeRequestResult> requestVerificationCode({
    String reason = 'manual',
  }) async {
    final user = _requireCurrentUser();
    final data = await _postAction(
      action: 'request_verification_code',
      payload: <String, dynamic>{
        'reason': reason.trim(),
        'user': await _buildCurrentUserSnapshot(),
      },
      requireConfigured: true,
    );

    final sent = data['sent'] == true;
    if (sent) {
      await _saveRequestedCodeMetadata(
        user.uid,
        sentAtIso: data['sentAtIso']?.toString(),
        expiresAtIso: data['expiresAtIso']?.toString(),
      );
    }

    return EmailCodeRequestResult(
      sent: sent,
      message: (data['message'] as String?)?.trim().isNotEmpty == true
          ? (data['message'] as String).trim()
          : 'تم التعامل مع طلب رمز التحقق.',
      cooldownSeconds: _toInt(data['cooldownSeconds']),
    );
  }

  Future<void> verifyEmailCode({required String code}) async {
    final user = _requireCurrentUser();
    final cleanCode = code.trim();
    if (cleanCode.isEmpty) {
      throw const EmailNotificationFailure('أدخل رمز التحقق أولًا.');
    }

    final data = await _postAction(
      action: 'verify_email_code',
      payload: <String, dynamic>{
        'code': cleanCode,
        'user': await _buildCurrentUserSnapshot(),
      },
      requireConfigured: true,
    );

    await _markEmailVerifiedInFirestore(
      user.uid,
      verifiedAtIso: data['verifiedAtIso']?.toString(),
      welcomeSentAtIso: data['welcomeSentAtIso']?.toString(),
    );
    await syncCurrentUserProfile();
  }

  Future<EmailCodeRequestResult> requestPasswordResetCode({
    required String email,
  }) async {
    final normalizedEmail = _normalizeEmail(email);
    if (normalizedEmail.isEmpty) {
      throw const EmailNotificationFailure('أدخل البريد الإلكتروني أولًا.');
    }

    final data = await _postAction(
      action: 'request_password_reset_code',
      payload: <String, dynamic>{'email': normalizedEmail},
      requireConfigured: true,
    );

    return EmailCodeRequestResult(
      sent: data['sent'] == true,
      message: _extractMessage(
        data,
        fallback: 'تم التعامل مع طلب رمز إعادة التعيين.',
      ),
      cooldownSeconds: _toInt(data['cooldownSeconds']),
    );
  }

  Future<String> verifyPasswordResetCode({
    required String email,
    required String code,
  }) async {
    final normalizedEmail = _normalizeEmail(email);
    final cleanCode = code.trim();
    if (normalizedEmail.isEmpty) {
      throw const EmailNotificationFailure('أدخل البريد الإلكتروني أولًا.');
    }
    if (cleanCode.isEmpty) {
      throw const EmailNotificationFailure('أدخل رمز إعادة التعيين أولًا.');
    }

    final data = await _postAction(
      action: 'verify_password_reset_code',
      payload: <String, dynamic>{'email': normalizedEmail, 'code': cleanCode},
      requireConfigured: true,
    );

    return _extractMessage(
      data,
      fallback: 'تم التحقق من رمز إعادة التعيين بنجاح.',
    );
  }

  Future<String> completePasswordReset({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final normalizedEmail = _normalizeEmail(email);
    final cleanCode = code.trim();
    final cleanPassword = newPassword.trim();
    if (normalizedEmail.isEmpty) {
      throw const EmailNotificationFailure('أدخل البريد الإلكتروني أولًا.');
    }
    if (cleanCode.isEmpty) {
      throw const EmailNotificationFailure('أدخل رمز إعادة التعيين أولًا.');
    }
    if (cleanPassword.isEmpty) {
      throw const EmailNotificationFailure('أدخل كلمة المرور الجديدة أولًا.');
    }

    final data = await _postAction(
      action: 'complete_password_reset',
      payload: <String, dynamic>{
        'email': normalizedEmail,
        'code': cleanCode,
        'newPassword': cleanPassword,
      },
      requireConfigured: true,
    );

    return _extractMessage(data, fallback: 'تم تحديث كلمة المرور بنجاح.');
  }

  Future<void> queueLoginEmail() async {
    // Fix: Throttle login emails (one per 5 minutes)
    if (_isEventThrottled('login', '')) return;
    _markEventSent('login', '');
    _runSafelyInBackground(
      () => _queueChildActivityEmailOperation(
        eventType: 'login',
        operationId:
            'child_activity_email:login:${DateTime.now().toUtc().microsecondsSinceEpoch}',
      ),
    );
  }

  Future<void> queueChildAddedEmail({
    required String childId,
    required String childName,
  }) async {
    final cleanChildId = childId.trim();
    // Fix: Throttle child_added emails and use stable operationId
    if (_isEventThrottled('child_added', cleanChildId)) return;
    _markEventSent('child_added', cleanChildId);
    _runSafelyInBackground(
      () => _queueChildActivityEmailOperation(
        eventType: 'child_added',
        operationId: 'child_activity_email:child_added:$cleanChildId',
        child: <String, dynamic>{'id': cleanChildId, 'name': childName.trim()},
      ),
    );
  }

  Future<void> queueChildUpdatedEmail({
    required String childId,
    required String childName,
  }) async {
    final cleanChildId = childId.trim();
    // Fix: Throttle child_updated emails and use stable operationId
    if (_isEventThrottled('child_updated', cleanChildId)) return;
    _markEventSent('child_updated', cleanChildId);
    _runSafelyInBackground(
      () => _queueChildActivityEmailOperation(
        eventType: 'child_updated',
        operationId: 'child_activity_email:child_updated:$cleanChildId',
        child: <String, dynamic>{'id': cleanChildId, 'name': childName.trim()},
      ),
    );
  }

  Future<void> queueChildSwitchedEmail({
    required String childId,
    String? childName,
  }) async {
    final cleanChildId = childId.trim();
    // Fix: Throttle child_switched emails and use stable operationId
    if (_isEventThrottled('child_switched', cleanChildId)) return;
    _markEventSent('child_switched', cleanChildId);
    _runSafelyInBackground(
      () => _queueChildActivityEmailOperation(
        eventType: 'child_switched',
        operationId: 'child_activity_email:child_switched:$cleanChildId',
        child: <String, dynamic>{
          'id': cleanChildId,
          if (childName != null && childName.trim().isNotEmpty)
            'name': childName.trim(),
        },
      ),
    );
  }

  Future<void> queueChildDeletedSync({
    required String childId,
    String? childName,
  }) async {
    final cleanChildId = childId.trim();
    if (cleanChildId.isEmpty) {
      return;
    }

    final payload = await _buildChildDeletePayload(
      childId: cleanChildId,
      childName: childName,
    );
    if (payload == null) {
      return;
    }

    await _enqueueDurableOperation(
      operationId: 'child_delete:$cleanChildId',
      operationType: 'child_delete',
      childId: cleanChildId,
      removeSameTypeForChild: true,
      payload: payload,
    );
  }

  Future<void> deleteChildNow({
    required String childId,
    String? childName,
  }) async {
    final cleanChildId = childId.trim();
    if (cleanChildId.isEmpty) {
      return;
    }

    final payload = await _buildChildDeletePayload(
      childId: cleanChildId,
      childName: childName,
    );
    if (payload == null) {
      return;
    }

    await _postAction(
      action: 'delete_child_now',
      payload: payload,
      requireConfigured: true,
      requestTimeout: AppsScriptEmailConfig.requestTimeout,
    );
  }

  Future<void> queuePendingRewardEmail({
    required String childId,
    required String childName,
    required String rewardType,
    required String description,
    required int coins,
    required String rewardId,
    required String approvalToken,
    required String rejectionToken,
    String? taskId,
  }) async {
    await _queuePendingRewardEmailInternal(
      childId: childId,
      childName: childName,
      rewardType: rewardType,
      description: description,
      coins: coins,
      rewardId: rewardId,
      approvalToken: approvalToken,
      rejectionToken: rejectionToken,
      taskId: taskId,
    );
  }

  Future<void> _queuePendingRewardEmailInternal({
    required String childId,
    required String childName,
    required String rewardType,
    required String description,
    required int coins,
    required String rewardId,
    required String approvalToken,
    required String rejectionToken,
    String? taskId,
  }) async {
    final cleanChildId = childId.trim();
    final cleanRewardId = rewardId.trim();
    if (cleanChildId.isEmpty || cleanRewardId.isEmpty) {
      return;
    }

    // Send directly via send_event_email (matching deployed Apps Script)
    try {
      final directResult = await _postAction(
        action: 'send_event_email',
        payload: <String, dynamic>{
          'eventType': 'pending_reward',
          'user': await _buildCurrentUserSnapshot(),
          'child': <String, dynamic>{
            'id': cleanChildId,
            'name': childName.trim().isEmpty ? 'الطفل' : childName.trim(),
          },
          'extraData': <String, dynamic>{
            'rewardType': rewardType.trim(),
            'description': description.trim(),
            'coins': coins,
            'rewardId': cleanRewardId,
            'approvalToken': approvalToken,
            'rejectionToken': rejectionToken,
            if (taskId != null && taskId.trim().isNotEmpty)
              'taskId': taskId.trim(),
          },
        },
        requireConfigured: false,
        requestTimeout: _bestEffortRequestTimeout,
      );
      if (directResult['sent'] != true) {
        throw const EmailNotificationFailure(
          'Pending reward email was not sent by Apps Script.',
        );
      }
    } catch (_) {
      // If direct send fails, fall back to durable outbox for retry
      await _enqueueDurableOperation(
        operationId: 'pending_reward_email:$cleanRewardId',
        operationType: 'pending_reward_email',
        childId: cleanChildId,
        removeSameTypeForChild: true,
        payload: <String, dynamic>{
          'eventType': 'pending_reward',
          'user': await _buildCurrentUserSnapshot(),
          'child': <String, dynamic>{
            'id': cleanChildId,
            'name': childName.trim().isEmpty ? 'الطفل' : childName.trim(),
          },
          'extraData': <String, dynamic>{
            'rewardType': rewardType.trim(),
            'description': description.trim(),
            'coins': coins,
            'rewardId': cleanRewardId,
            'approvalToken': approvalToken,
            'rejectionToken': rejectionToken,
            if (taskId != null && taskId.trim().isNotEmpty)
              'taskId': taskId.trim(),
          },
        },
      );
      _pendingRewardLoopRequested = true;
      startPendingRewardEmailSyncLoop();
    }
  }

  void startPendingRewardEmailSyncLoop() {
    _pendingRewardLoopRequested = true;
    if (_pendingRewardRetryLoopStarted &&
        (_pendingRewardRetryTimer?.isActive ?? false)) {
      return;
    }
    _pendingRewardRetryLoopStarted = true;
    flushDurableOutboxInBackground();
    _pendingRewardRetryTimer?.cancel();
    _pendingRewardRetryTimer = Timer.periodic(_pendingRewardRetryInterval, (_) {
      flushDurableOutboxInBackground();
    });
  }

  Future<void> flushPendingRewardEmailQueue() async {
    await flushDurableOutbox();
  }

  Future<void> syncChildProfile({
    required String childId,
    required String childName,
    int? ageYears,
    String? avatarBase64,
    bool fallbackToDurableOutbox = true,
  }) async {
    return _syncChildProfileInternal(
      childId: childId,
      childName: childName,
      ageYears: ageYears,
      avatarBase64: avatarBase64,
      fallbackToDurableOutbox: fallbackToDurableOutbox,
    );
  }

  Future<void> _syncChildProfileInternal({
    required String childId,
    required String childName,
    int? ageYears,
    String? avatarBase64,
    required bool fallbackToDurableOutbox,
  }) async {
    final cleanChildId = childId.trim();
    final cleanChildName = childName.trim();
    if (cleanChildId.isEmpty || cleanChildName.isEmpty) {
      return;
    }

    final payload = <String, dynamic>{
      'user': await _buildCurrentUserSnapshot(),
      'child': <String, dynamic>{
        'id': cleanChildId,
        'name': cleanChildName,
        'ageYears': ageYears,
        'hasAvatar': avatarBase64?.trim().isNotEmpty == true,
      },
    };

    try {
      // Send directly to GAS for immediate sync.
      // retryEnabled: false avoids request bursts if GAS is slow.
      await _postAction(
        action: 'sync_child_profile',
        payload: payload,
        requireConfigured: true,
        requestTimeout: const Duration(seconds: 20),
        retryEnabled: false,
      );
    } catch (_) {
      if (!fallbackToDurableOutbox) {
        rethrow;
      }
      // Fallback: keep child profile sync in durable outbox for later delivery.
      // This avoids dropping data when GAS is slow/unreachable.
      await _enqueueDurableOperation(
        operationId: 'child_profile_sync:$cleanChildId',
        operationType: 'child_profile_sync',
        childId: cleanChildId,
        payload: payload,
      );
    }
  }

  Future<void> syncChildBehaviorConfig({
    required String childId,
    required Map<String, dynamic> behaviorConfig,
  }) async {
    _runSafelyInBackground(
      () => _syncChildBehaviorConfigInternal(
        childId: childId,
        behaviorConfig: behaviorConfig,
      ),
    );
  }

  Future<void> _syncChildBehaviorConfigInternal({
    required String childId,
    required Map<String, dynamic> behaviorConfig,
  }) async {
    final cleanChildId = childId.trim();
    if (cleanChildId.isEmpty || behaviorConfig.isEmpty) {
      return;
    }

    try {
      await _enqueueDurableOperation(
        operationId: 'behavior_sync:$cleanChildId',
        operationType: 'behavior_sync',
        childId: cleanChildId,
        payload: <String, dynamic>{
          'user': await _buildCurrentUserSnapshot(),
          'child': <String, dynamic>{'id': cleanChildId},
          'behaviorConfig': behaviorConfig,
        },
      );
    } catch (_) {
      // Config sync is best-effort.
    }
  }

  Future<void> syncChildProgressHistory({
    required String childId,
    required Map<String, dynamic> progressHistory,
  }) async {
    _runSafelyInBackground(
      () => _syncChildProgressHistoryInternal(
        childId: childId,
        progressHistory: progressHistory,
      ),
    );
  }

  Future<void> _syncChildProgressHistoryInternal({
    required String childId,
    required Map<String, dynamic> progressHistory,
  }) async {
    final cleanChildId = childId.trim();
    if (cleanChildId.isEmpty || progressHistory.isEmpty) {
      return;
    }

    final historyEntries = progressHistory.entries
        .where((entry) => entry.key.trim().isNotEmpty && entry.value is Map)
        .map((entry) {
          final progress = _normalizeMap(entry.value);
          return <String, dynamic>{
            'dateKey': entry.key.trim(),
            'progress': <String, dynamic>{
              'completedTaskIds':
                  progress['completedTaskIds'] ?? const <String>[],
              'totalTaskCount': progress['totalTaskCount'] ?? 0,
              'awardedCoinsByTaskId':
                  progress['awardedCoinsByTaskId'] ?? const <String, int>{},
              'plannedTaskIds': progress['plannedTaskIds'] ?? const <String>[],
              'plannedTaskTitlesById':
                  progress['plannedTaskTitlesById'] ?? const <String, String>{},
            },
          };
        })
        .toList(growable: false);
    if (historyEntries.isEmpty) {
      return;
    }

    try {
      await _enqueueDurableOperation(
        operationId: 'progress_sync:$cleanChildId',
        operationType: 'progress_sync',
        childId: cleanChildId,
        payload: <String, dynamic>{
          'user': await _buildCurrentUserSnapshot(),
          'child': <String, dynamic>{'id': cleanChildId},
          'history': historyEntries,
        },
      );
    } catch (_) {
      // Progress sync is best-effort.
    }
  }

  Future<void> _queueChildActivityEmailOperation({
    required String eventType,
    required String operationId,
    Map<String, dynamic> child = const <String, dynamic>{},
    Map<String, dynamic> extraData = const <String, dynamic>{},
  }) async {
    final payload = <String, dynamic>{
      'eventType': eventType.trim(),
      'user': await _buildCurrentUserSnapshot(),
      if (child.isNotEmpty) 'child': child,
      if (extraData.isNotEmpty) 'extraData': extraData,
    };

    try {
      final directResult = await _postAction(
        action: 'send_event_email',
        payload: payload,
        requireConfigured: false,
        requestTimeout: _bestEffortRequestTimeout,
      );
      if (directResult['sent'] == true || directResult['skipped'] == true) {
        return;
      }
    } catch (_) {
      // Fall back to the durable queue when the immediate email call is unavailable.
    }

    await _enqueueDurableOperation(
      operationId: operationId,
      operationType: 'child_activity_email',
      childId: (child['id'] as String?)?.trim(),
      replaceExisting: true, // Fix: Replace duplicate entries in queue
      payload: payload,
    );
  }

  Future<void> _enqueueDurableOperation({
    required String operationId,
    required String operationType,
    required Map<String, dynamic> payload,
    String? childId,
    bool replaceExisting = true,
    bool removeSameTypeForChild = false,
  }) async {
    final user = _auth.currentUser;
    final cleanOperationId = operationId.trim();
    final cleanOperationType = operationType.trim();
    if (user == null ||
        cleanOperationId.isEmpty ||
        cleanOperationType.isEmpty) {
      return;
    }

    final queue = List<Map<String, dynamic>>.of(
      await _readDurableOutbox(user.uid),
    );
    final nextItem = <String, dynamic>{
      'operationId': cleanOperationId,
      'operationType': cleanOperationType,
      if (childId != null && childId.trim().isNotEmpty)
        'childId': childId.trim(),
      'payload': payload,
      'queuedAt': DateTime.now().toUtc().toIso8601String(),
    };

    final nextQueue = <Map<String, dynamic>>[];
    if (removeSameTypeForChild &&
        childId != null &&
        childId.trim().isNotEmpty) {
      final cleanChildId = childId.trim();
      queue.removeWhere((item) {
        final itemType = (item['operationType'] as String? ?? '').trim();
        final itemChildId = (item['childId'] as String? ?? '').trim();
        return itemType == cleanOperationType && itemChildId == cleanChildId;
      });
    }
    var replaced = false;
    for (final item in queue) {
      final existingOperationId = (item['operationId'] as String? ?? '').trim();
      if (replaceExisting && existingOperationId == cleanOperationId) {
        nextQueue.add(nextItem);
        replaced = true;
        continue;
      }
      nextQueue.add(item);
    }
    if (!replaced) {
      nextQueue.add(nextItem);
    }

    final trimmedQueue = nextQueue.length <= _maxDurableOutboxSize
        ? nextQueue
        : nextQueue.sublist(nextQueue.length - _maxDurableOutboxSize);
    await _writeDurableOutbox(user.uid, trimmedQueue);
    flushDurableOutboxInBackground();
  }

  Future<void> flushDurableOutbox() async {
    final user = _auth.currentUser;
    if (user == null || !_isConfigured) {
      return;
    }

    final uid = user.uid;
    if (_durableOutboxSyncInFlight.contains(uid)) {
      return;
    }

    _durableOutboxSyncInFlight.add(uid);
    try {
      final queue = await _readDurableOutbox(uid);
      if (queue.isEmpty) {
        return;
      }

      // Separate reward emails from other operations.
      // Rewards (newest first) get dispatched before anything else.
      final rewardItems = <Map<String, dynamic>>[];
      final otherItems = <Map<String, dynamic>>[];
      for (final item in queue) {
        final opType = (_normalizeMap(item)['operationType'] as String? ?? '')
            .trim();
        if (opType == 'pending_reward_email') {
          rewardItems.add(item);
        } else {
          otherItems.add(item);
        }
      }

      // Reverse rewards so the newest (last added) is dispatched first.
      final orderedQueue = <Map<String, dynamic>>[
        ...rewardItems.reversed,
        ...otherItems,
      ];

      final remainingQueue = <Map<String, dynamic>>[];
      var stopRewards = false;
      var stopOthers = false;
      for (final item in orderedQueue) {
        final operation = _normalizeMap(item);
        final operationId = (operation['operationId'] as String? ?? '').trim();
        final operationType = (operation['operationType'] as String? ?? '')
            .trim();
        final isReward = operationType == 'pending_reward_email';

        if ((isReward && stopRewards) || (!isReward && stopOthers)) {
          remainingQueue.add(operation);
          continue;
        }

        final operationPayload = _normalizeMap(operation['payload']);
        final operationUser = _normalizeMap(operationPayload['user']);
        final operationUid =
            (operationUser['uid'] as String? ?? '').trim().isNotEmpty
            ? (operationUser['uid'] as String).trim()
            : uid;
        if (operationId.isEmpty || operationType.isEmpty) {
          continue;
        }

        if (operationType == 'child_profile_sync') {
          final queuedChildId = (operation['childId'] as String? ?? '').trim();
          if (queuedChildId.isNotEmpty) {
            final childExists = await _childDocumentExists(
              uid: operationUid,
              childId: queuedChildId,
            );
            if (!childExists) {
              // Drop stale child-profile sync operation.
              continue;
            }
          }
        }

        try {
          await _postAction(
            action: 'enqueue_operation',
            payload: <String, dynamic>{
              'operationId': operationId,
              'operationType': operationType,
              'uid': operationUid,
              if ((operation['childId'] as String?)?.trim().isNotEmpty == true)
                'childId': (operation['childId'] as String).trim(),
              'payload': operationPayload,
            },
            requireConfigured: false,
            requestTimeout: _bestEffortRequestTimeout,
          );
        } catch (_) {
          // Only block items of the same category.
          if (isReward) {
            stopRewards = true;
          } else {
            stopOthers = true;
          }
          remainingQueue.add(operation);
        }
      }

      await _writeDurableOutbox(uid, remainingQueue);
    } finally {
      _durableOutboxSyncInFlight.remove(uid);
    }
  }

  Future<List<Map<String, dynamic>>> _readDurableOutbox(String uid) async {
    final key = _durableOutboxKey(uid);
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

  Future<void> _writeDurableOutbox(
    String uid,
    List<Map<String, dynamic>> queue,
  ) async {
    final key = _durableOutboxKey(uid);
    try {
      final prefs = await SharedPreferences.getInstance();
      if (queue.isEmpty) {
        await prefs.remove(key);
        return;
      }
      await prefs.setString(key, jsonEncode(queue));
    } catch (_) {
      // Local durable outbox persistence is best-effort.
    }
  }

  String _durableOutboxKey(String uid) => 'email_durable_outbox_${uid.trim()}';

  bool isRequestTimeoutFailure(EmailNotificationFailure failure) {
    final message = failure.message.trim().toLowerCase();
    return message.contains('مهلة') || message.contains('timeout');
  }

  Future<Map<String, dynamic>?> _buildChildDeletePayload({
    required String childId,
    String? childName,
  }) async {
    final userSnapshot = await _buildUserSnapshotWithFallback();
    if (userSnapshot == null) {
      return null;
    }
    return <String, dynamic>{
      'uid': (userSnapshot['uid'] as String? ?? '').trim(),
      'childId': childId,
      'user': userSnapshot,
      'child': <String, dynamic>{
        'id': childId,
        if (childName != null && childName.trim().isNotEmpty)
          'name': childName.trim(),
      },
    };
  }

  Future<bool> _childDocumentExists({
    required String uid,
    required String childId,
  }) async {
    if (uid.trim().isEmpty || childId.trim().isEmpty) {
      return false;
    }
    try {
      final doc = await _firestore
          .collection('users')
          .doc(uid.trim())
          .collection('children')
          .doc(childId.trim())
          .get()
          .timeout(const Duration(seconds: 10));
      return doc.exists;
    } catch (_) {
      // If verification fails, keep operation for retry.
      return true;
    }
  }

  Future<Map<String, dynamic>> _postAction({
    required String action,
    required Map<String, dynamic> payload,
    required bool requireConfigured,
    Duration? requestTimeout,
    bool retryEnabled = true,
  }) async {
    final configurationError = _configurationError();
    if (configurationError != null) {
      if (requireConfigured) {
        throw EmailNotificationFailure(configurationError);
      }
      return const <String, dynamic>{};
    }

    final uri = Uri.tryParse(AppsScriptEmailConfig.webAppUrl.trim());
    if (uri == null || (!uri.hasScheme || uri.host.trim().isEmpty)) {
      if (requireConfigured) {
        throw const EmailNotificationFailure(
          'رابط Google Apps Script غير صالح. حدده داخل ملف الإعداد أولًا.',
        );
      }
      return const <String, dynamic>{};
    }

    try {
      final requestBody = jsonEncode(<String, dynamic>{
        'secret': AppsScriptEmailConfig.sharedSecret.trim(),
        'action': action,
        'payload': payload,
      });
      final timeout = requestTimeout ?? AppsScriptEmailConfig.requestTimeout;
      final response = await (retryEnabled
          ? _sendJsonPostWithRedirects(
              uri: uri,
              body: requestBody,
              timeout: timeout,
            )
          : _sendJsonPostWithRedirectsOnce(
              uri: uri,
              body: requestBody,
              timeout: timeout,
            ));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw EmailNotificationFailure(
          'تعذر الوصول إلى خدمة البريد الحالية. رمز الاستجابة: ${response.statusCode}. تأكد أن Apps Script منشور كـ Web App بصلاحية Anyone.',
        );
      }

      final responseBody = response.body.trim();
      if (responseBody.startsWith('<!DOCTYPE html') ||
          responseBody.startsWith('<html')) {
        throw const EmailNotificationFailure(
          'خدمة البريد أعادت صفحة HTML بدل JSON. أعد نشر Apps Script كـ Web App وتأكد من استخدام رابط /exec الصحيح.',
        );
      }

      final decoded = jsonDecode(response.body);
      final envelope = _normalizeMap(decoded);
      if (envelope['ok'] != true) {
        final error = _normalizeMap(envelope['error']);
        final message = (error['message'] as String?)?.trim();
        throw EmailNotificationFailure(
          message?.isNotEmpty == true
              ? message!
              : 'تعذر تنفيذ العملية البريدية حاليًا.',
        );
      }

      return _normalizeMap(envelope['data']);
    } on EmailNotificationFailure {
      rethrow;
    } on TimeoutException {
      throw const EmailNotificationFailure(
        'انتهت مهلة الاتصال بخدمة البريد. تحقق من الإنترنت ثم حاول مرة أخرى.',
      );
    } on FormatException {
      throw const EmailNotificationFailure(
        'استجابت خدمة البريد ببيانات غير صالحة. تحقق من إعداد Apps Script ثم حاول مرة أخرى.',
      );
    } catch (_) {
      throw const EmailNotificationFailure(
        'تعذر الاتصال بخدمة البريد الحالية. تحقق من الإعدادات ثم حاول مرة أخرى.',
      );
    }
  }

  Future<http.Response> _sendJsonPostWithRedirects({
    required Uri uri,
    required String body,
    required Duration timeout,
  }) async {
    for (var attempt = 0; attempt < _maxTransientRequestAttempts; attempt++) {
      try {
        return await _sendJsonPostWithRedirectsOnce(
          uri: uri,
          body: body,
          timeout: timeout,
        );
      } catch (error) {
        if (!_isTransientNetworkFailure(error) ||
            attempt >= _maxTransientRequestAttempts - 1) {
          rethrow;
        }
        await Future<void>.delayed(
          Duration(
            milliseconds:
                _transientRetryBaseDelay.inMilliseconds * (attempt + 1),
          ),
        );
      }
    }
    throw const EmailNotificationFailure(
      'تعذر الاتصال بخدمة البريد الحالية. تحقق من الإعدادات ثم حاول مرة أخرى.',
    );
  }

  Future<http.Response> _sendJsonPostWithRedirectsOnce({
    required Uri uri,
    required String body,
    required Duration timeout,
  }) async {
    var currentUri = uri;
    var shouldUseGet = false;

    for (var redirectCount = 0; redirectCount < 5; redirectCount++) {
      final request = http.Request(shouldUseGet ? 'GET' : 'POST', currentUri)
        ..followRedirects = false
        ..maxRedirects = 0;
      request.headers['Connection'] = 'close';
      if (!shouldUseGet) {
        request.headers['Content-Type'] = 'application/json; charset=utf-8';
        request.body = body;
      }

      final streamedResponse = await _httpClient.send(request).timeout(timeout);

      if (_isRedirectStatus(streamedResponse.statusCode)) {
        final location = streamedResponse.headers['location']?.trim();
        await streamedResponse.stream.drain<void>();
        if (location == null || location.isEmpty) {
          return http.Response(
            '',
            streamedResponse.statusCode,
            headers: streamedResponse.headers,
            request: request,
          );
        }
        currentUri = currentUri.resolve(location);
        // Apps Script processes the POST before redirecting to a one-time
        // response URL on google user content, which must then be fetched via GET.
        shouldUseGet = true;
        continue;
      }

      return http.Response.fromStream(streamedResponse);
    }

    throw const EmailNotificationFailure(
      'خدمة البريد أعادت عددًا كبيرًا من عمليات التحويل. تحقق من رابط Web App ثم حاول مرة أخرى.',
    );
  }

  bool _isRedirectStatus(int statusCode) {
    return statusCode == 301 ||
        statusCode == 302 ||
        statusCode == 303 ||
        statusCode == 307 ||
        statusCode == 308;
  }

  bool _isTransientNetworkFailure(Object error) {
    return error is SocketException ||
        error is HttpException ||
        error is HandshakeException ||
        error is http.ClientException;
  }

  void _runSafelyInBackground(Future<void> Function() task) {
    unawaited(
      Future<void>(() async {
        try {
          await task();
        } catch (_) {
          // Background dispatch is best-effort and must never crash the app.
        }
      }),
    );
  }

  Future<Map<String, dynamic>> _buildCurrentUserSnapshot() async {
    final user = _requireCurrentUser();
    final normalizedEmail = (user.email ?? '').trim().toLowerCase();
    if (normalizedEmail.isEmpty) {
      throw const EmailNotificationFailure(
        'تعذر تحديد بريد الحساب الحالي لإرسال الرسائل.',
      );
    }

    // Return cached snapshot if still fresh.
    if (_cachedUserSnapshot != null &&
        _cachedUserSnapshotAt != null &&
        DateTime.now().difference(_cachedUserSnapshotAt!) <
            _userSnapshotCacheTtl &&
        (_cachedUserSnapshot!['uid'] as String? ?? '') == user.uid) {
      return _cachedUserSnapshot!;
    }

    Map<String, dynamic> userData = const <String, dynamic>{};
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .get()
          .timeout(const Duration(seconds: 12));
      userData = snapshot.data() ?? const <String, dynamic>{};
    } catch (_) {
      userData = const <String, dynamic>{};
    }

    final notificationSettings = _normalizeNotificationSettings(
      userData['emailNotificationSettings'],
    );
    final verification = _normalizeMap(userData['emailVerification']);
    final welcomeGuide = _normalizeMap(userData['welcomeGuide']);
    final locale = (userData['locale'] as String? ?? 'ar').trim();

    final result = <String, dynamic>{
      'uid': user.uid,
      'email': normalizedEmail,
      'locale': locale.isEmpty ? 'ar' : locale,
      'notificationSettings': notificationSettings,
      'emailVerification': <String, dynamic>{
        'isVerified':
            verification['isVerified'] == true || user.emailVerified == true,
        'verifiedAt': _toIsoString(verification['verifiedAt']),
      },
      'welcomeGuide': <String, dynamic>{
        'sentAt': _toIsoString(welcomeGuide['sentAt']),
      },
      'createdAt': _toIsoString(userData['createdAt']),
      'updatedAt': _toIsoString(userData['updatedAt']),
    };

    _cachedUserSnapshot = result;
    _cachedUserSnapshotAt = DateTime.now();
    return result;
  }

  Future<void> _saveRequestedCodeMetadata(
    String uid, {
    String? sentAtIso,
    String? expiresAtIso,
  }) async {
    final sentAt = _toDateTime(sentAtIso);
    final expiresAt = _toDateTime(expiresAtIso);

    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .set({
            'emailVerification': <String, dynamic>{
              'isVerified': false,
              'pendingCodeHash': null,
              'pendingCodeExpiresAt': expiresAt,
              'lastCodeSentAt': sentAt ?? FieldValue.serverTimestamp(),
            },
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true))
          .timeout(const Duration(seconds: 12));
    } catch (_) {
      // Metadata sync is best-effort; verification flow can continue.
    }
  }

  Future<void> _markEmailVerifiedInFirestore(
    String uid, {
    String? verifiedAtIso,
    String? welcomeSentAtIso,
  }) async {
    final verifiedAt = _toDateTime(verifiedAtIso);
    final welcomeSentAt = _toDateTime(welcomeSentAtIso);

    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .set({
            'emailVerification': <String, dynamic>{
              'isVerified': true,
              'pendingCodeHash': null,
              'pendingCodeExpiresAt': null,
              'lastCodeSentAt': null,
              'verifiedAt': verifiedAt ?? FieldValue.serverTimestamp(),
            },
            'welcomeGuide': <String, dynamic>{
              'sentAt':
                  welcomeSentAt ?? verifiedAt ?? FieldValue.serverTimestamp(),
            },
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true))
          .timeout(const Duration(seconds: 12));
    } on FirebaseException catch (e) {
      throw EmailNotificationFailure(_mapFirestoreError(e));
    } on TimeoutException {
      throw const EmailNotificationFailure(
        'تم التحقق من الرمز، لكن تعذر حفظ حالة الحساب بسبب بطء الشبكة. حاول مرة أخرى.',
      );
    }
  }

  User _requireCurrentUser() {
    final user = _auth.currentUser;
    if (user == null) {
      throw const EmailNotificationFailure('يجب تسجيل الدخول أولًا.');
    }
    return user;
  }

  bool get _isConfigured => AppsScriptEmailConfig.isConfigured;

  String? _configurationError() {
    if (_isConfigured) {
      return null;
    }
    return 'أكمل إعداد Google Apps Script أولًا داخل الملف lib/shared/config/apps_script_email_config.dart.';
  }

  String _extractMessage(
    Map<String, dynamic> data, {
    required String fallback,
  }) {
    final message = (data['message'] as String?)?.trim();
    return message?.isNotEmpty == true ? message! : fallback;
  }

  String _normalizeEmail(String email) => email.trim().toLowerCase();

  Future<Map<String, dynamic>?> _buildUserSnapshotWithFallback() async {
    try {
      return await _buildCurrentUserSnapshot();
    } catch (_) {
      final fallbackUser = _auth.currentUser;
      if (fallbackUser == null) {
        return null;
      }
      return <String, dynamic>{
        'uid': fallbackUser.uid,
        'email': _normalizeEmail(fallbackUser.email ?? ''),
        'locale': 'ar',
        'notificationSettings': _normalizeNotificationSettings(const {}),
        'emailVerification': <String, dynamic>{
          'isVerified': fallbackUser.emailVerified == true,
          'verifiedAt': null,
        },
        'welcomeGuide': <String, dynamic>{'sentAt': null},
        'createdAt': null,
        'updatedAt': null,
      };
    }
  }

  Map<String, dynamic> _normalizeNotificationSettings(Object? value) {
    final raw = _normalizeMap(value);
    return <String, dynamic>{
      'enabled': _toBool(raw['enabled'], fallback: true),
      'verification': _toBool(raw['verification'], fallback: true),
      'welcomeGuide': _toBool(raw['welcomeGuide'], fallback: true),
      'login': _toBool(raw['login'], fallback: true),
      'childActivity': _toBool(raw['childActivity'], fallback: true),
      'weeklyStats': _toBool(raw['weeklyStats'], fallback: true),
      'dailyWarnings': _toBool(raw['dailyWarnings'], fallback: true),
    };
  }

  String _mapFirestoreError(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return 'تم التحقق من الرمز لكن ليست لديك صلاحية لحفظ حالة الحساب في Firestore.';
      case 'unavailable':
        return 'تم التحقق من الرمز لكن خدمة قاعدة البيانات غير متاحة حاليًا.';
      default:
        return 'تم التحقق من الرمز لكن تعذر حفظ حالة الحساب محليًا في قاعدة البيانات.';
    }
  }

  Map<String, dynamic> _normalizeMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, value) => MapEntry(key.toString(), value));
    }
    return const <String, dynamic>{};
  }

  int _toInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value.trim()) ?? 0;
    }
    return 0;
  }

  bool _toBool(Object? value, {required bool fallback}) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1') {
        return true;
      }
      if (normalized == 'false' || normalized == '0') {
        return false;
      }
    }
    return fallback;
  }

  String? _toIsoString(Object? value) {
    if (value is Timestamp) {
      return value.toDate().toUtc().toIso8601String();
    }
    if (value is DateTime) {
      return value.toUtc().toIso8601String();
    }
    if (value is String) {
      final clean = value.trim();
      return clean.isEmpty ? null : clean;
    }
    return null;
  }

  DateTime? _toDateTime(Object? value) {
    if (value is DateTime) {
      return value;
    }
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is String) {
      final clean = value.trim();
      if (clean.isEmpty) {
        return null;
      }
      return DateTime.tryParse(clean)?.toLocal();
    }
    return null;
  }

  // ─── Fix: Local throttle helpers ─────────────────────────────────────
  // Prevents the same email event from being queued more than once
  // within _eventThrottleDuration (5 minutes). Safe in-memory only.

  static bool _isEventThrottled(String eventType, String childId) {
    try {
      _purgeExpiredThrottleEntries();
      final key = '${eventType.trim()}::${childId.trim()}';
      final lastSent = _recentlySentEvents[key];
      if (lastSent == null) return false;
      return DateTime.now().difference(lastSent) < _eventThrottleDuration;
    } catch (_) {
      // Throttle check must never block app flow
      return false;
    }
  }

  static void _markEventSent(String eventType, String childId) {
    try {
      final key = '${eventType.trim()}::${childId.trim()}';
      _recentlySentEvents[key] = DateTime.now();
    } catch (_) {
      // Best-effort
    }
  }

  static void _purgeExpiredThrottleEntries() {
    try {
      final now = DateTime.now();
      _recentlySentEvents.removeWhere(
        (_, sentAt) => now.difference(sentAt) > _eventThrottleDuration,
      );
    } catch (_) {
      // Best-effort cleanup
    }
  }
}

class EmailNotificationFailure implements Exception {
  const EmailNotificationFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
