import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:risha_v01/shared/services/child_local_state_service.dart';
import 'package:risha_v01/shared/services/email_notification_service.dart';
import 'package:risha_v01/shared/services/child_reward_service.dart';
import 'package:risha_v01/shared/services/selected_child_service.dart';

class ChildTaskIds {
  static const String quranReading = 'quran-reading';
  static const String brushTime = 'brush-time';
  static const String waterDrink = 'water-drink';
  static const String exercising = 'exercising';
  static const String shapeMatching = 'shape-matching';
  static const String sleepStory = 'sleep-story';
  static const String brushTimeMorning = 'brush-time-morning';
  static const String brushTimeNight = 'brush-time-night';
  static const String waterDrinkSlotPrefix = 'water-drink-slot-';
  static const String exerciseSlotPrefix = 'exercising-slot-';
  static const String customBehaviorSlotPrefix = 'custom-behavior-slot:';
  static const int maxWaterSlotsPerDay = 12;
  static const int maxExerciseSlotsPerDay = 6;
  static const int maxCustomBehaviorSlotsPerDay = 10;

  static String waterDrinkSlot(int slotNumber) =>
      '$waterDrinkSlotPrefix${slotNumber.clamp(1, maxWaterSlotsPerDay)}';

  static String exerciseSlot(int slotNumber) =>
      '$exerciseSlotPrefix${slotNumber.clamp(1, maxExerciseSlotsPerDay)}';

  static String customBehaviorSlot(String behaviorId, int slotNumber) =>
      '$customBehaviorSlotPrefix${behaviorId.trim()}:${slotNumber.clamp(1, maxCustomBehaviorSlotsPerDay)}';

  static final Set<String> all = <String>{
    quranReading,
    brushTime,
    waterDrink,
    exercising,
    shapeMatching,
    sleepStory,
    brushTimeMorning,
    brushTimeNight,
    ...List<String>.generate(
      maxWaterSlotsPerDay,
      (index) => waterDrinkSlot(index + 1),
    ),
    ...List<String>.generate(
      maxExerciseSlotsPerDay,
      (index) => exerciseSlot(index + 1),
    ),
  };

  static bool isSupported(String taskId) {
    final cleanTaskId = taskId.trim();
    return all.contains(cleanTaskId) || _isCustomBehaviorTask(cleanTaskId);
  }

  static bool _isCustomBehaviorTask(String taskId) {
    final cleanTaskId = taskId.trim();
    if (!cleanTaskId.startsWith(customBehaviorSlotPrefix)) {
      return false;
    }
    final remainder = cleanTaskId.substring(customBehaviorSlotPrefix.length);
    final separatorIndex = remainder.lastIndexOf(':');
    if (separatorIndex <= 0 || separatorIndex >= remainder.length - 1) {
      return false;
    }
    final behaviorId = remainder.substring(0, separatorIndex).trim();
    final slotNumber = int.tryParse(remainder.substring(separatorIndex + 1));
    return behaviorId.startsWith('custom_') &&
        slotNumber != null &&
        slotNumber >= 1 &&
        slotNumber <= maxCustomBehaviorSlotsPerDay;
  }
}

class ChildDailyTaskProgress {
  const ChildDailyTaskProgress({
    required this.dateKey,
    required this.completedTaskIds,
    this.totalTaskCount = 0,
    this.awardedCoinsByTaskId = const <String, int>{},
    this.plannedTaskIds = const <String>{},
    this.plannedTaskTitlesById = const <String, String>{},
  });

  final String dateKey;
  final Set<String> completedTaskIds;
  final int totalTaskCount;
  final Map<String, int> awardedCoinsByTaskId;
  final Set<String> plannedTaskIds;
  final Map<String, String> plannedTaskTitlesById;

  bool isCompleted(String taskId) => completedTaskIds.contains(taskId.trim());

  int get completedTaskCount => completedTaskIds.length;

  int get remainingTaskCount {
    final remaining = totalTaskCount - completedTaskCount;
    return remaining > 0 ? remaining : 0;
  }

  double get completionRatio {
    if (totalTaskCount <= 0) {
      return 0;
    }
    return completedTaskCount / totalTaskCount;
  }

  ChildDailyTaskProgress copyWith({
    Set<String>? completedTaskIds,
    int? totalTaskCount,
    Map<String, int>? awardedCoinsByTaskId,
    Set<String>? plannedTaskIds,
    Map<String, String>? plannedTaskTitlesById,
  }) {
    return ChildDailyTaskProgress(
      dateKey: dateKey,
      completedTaskIds: completedTaskIds ?? this.completedTaskIds,
      totalTaskCount: totalTaskCount ?? this.totalTaskCount,
      awardedCoinsByTaskId: awardedCoinsByTaskId ?? this.awardedCoinsByTaskId,
      plannedTaskIds: plannedTaskIds ?? this.plannedTaskIds,
      plannedTaskTitlesById:
          plannedTaskTitlesById ?? this.plannedTaskTitlesById,
    );
  }

  Map<String, dynamic> toMap() {
    final sortedTaskIds = completedTaskIds.toList(growable: false)..sort();
    final sortedPlannedTaskIds = plannedTaskIds.toList(growable: false)..sort();
    final rewardEntries = awardedCoinsByTaskId.entries.toList(growable: false)
      ..sort((a, b) => a.key.compareTo(b.key));
    final titleEntries = plannedTaskTitlesById.entries.toList(growable: false)
      ..sort((a, b) => a.key.compareTo(b.key));
    return <String, dynamic>{
      'dateKey': dateKey,
      'completedTaskIds': sortedTaskIds,
      'totalTaskCount': totalTaskCount,
      'awardedCoinsByTaskId': <String, int>{
        for (final entry in rewardEntries)
          if (sortedTaskIds.contains(entry.key)) entry.key: entry.value,
      },
      'plannedTaskIds': sortedPlannedTaskIds,
      'plannedTaskTitlesById': <String, String>{
        for (final entry in titleEntries)
          if (sortedPlannedTaskIds.contains(entry.key)) entry.key: entry.value,
      },
    };
  }
}

class ChildWeeklyTaskProgress {
  const ChildWeeklyTaskProgress({required this.days});

  final List<ChildDailyTaskProgress> days;

  bool get hasRecordedData =>
      days.any((day) => day.totalTaskCount > 0 || day.completedTaskCount > 0);
}

class ChildTaskCompletionResult {
  const ChildTaskCompletionResult({
    required this.progress,
    required this.coinsBalance,
    required this.awardedCoins,
    required this.alreadyCompletedToday,
    required this.levelState,
  });

  final ChildDailyTaskProgress progress;
  final int coinsBalance;
  final int awardedCoins;
  final bool alreadyCompletedToday;
  final ChildLevelState levelState;
}

class _TaskHistorySyncResult {
  const _TaskHistorySyncResult({
    required this.history,
    required this.coinsBalance,
    required this.levelState,
  });

  final Map<String, ChildDailyTaskProgress> history;
  final int coinsBalance;
  final ChildLevelState levelState;
}

class _AsyncFutureFailure {
  const _AsyncFutureFailure(this.error, this.stackTrace);

  final Object error;
  final StackTrace stackTrace;
}

// ignore: unused_element
class _TaskCompletionSaveResult {
  const _TaskCompletionSaveResult({
    required this.history,
    required this.completionResult,
  });

  final Map<String, ChildDailyTaskProgress> history;
  final ChildTaskCompletionResult completionResult;
}

class ChildTaskProgressService {
  ChildTaskProgressService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    SelectedChildService? selectedChildService,
    ChildLocalStateService? localStateService,
    EmailNotificationService? emailNotificationService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _selectedChildService =
           selectedChildService ??
           SelectedChildService(auth: auth ?? FirebaseAuth.instance),
       _localStateService =
           localStateService ?? ChildLocalStateService(auth: auth),
       _emailNotificationService =
           emailNotificationService ??
           EmailNotificationService(
             auth: auth ?? FirebaseAuth.instance,
             firestore: firestore ?? FirebaseFirestore.instance,
           );

  static const Duration _requestTimeout = Duration(seconds: 20);
  static const int _historyRetentionDays = 90;
  static final Object _requestTimeoutSentinel = Object();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final SelectedChildService _selectedChildService;
  final ChildLocalStateService _localStateService;
  final EmailNotificationService _emailNotificationService;
  final Set<String> _progressSyncInFlight = <String>{};

  Future<T?> _awaitOrNullOnTimeout<T>(Future<T> future) async {
    final result = await Future.any<Object?>(<Future<Object?>>[
      future
          .then<Object?>((value) => value)
          .catchError(
            (Object error, StackTrace stackTrace) =>
                _AsyncFutureFailure(error, stackTrace),
          ),
      Future<Object?>.delayed(
        _requestTimeout,
        () => _requestTimeoutSentinel,
      ),
    ]);
    if (identical(result, _requestTimeoutSentinel)) {
      return null;
    }
    if (result is _AsyncFutureFailure) {
      Error.throwWithStackTrace(result.error, result.stackTrace);
    }
    return result == null ? null : result as T;
  }

  Future<ChildDailyTaskProgress> getSelectedChildTaskProgress({
    bool forceRemoteFetch = false,
  }) async {
    final childId = await _selectedChildId();
    final todayKey = _todayKey();
    final localHistory = await _getLocalTaskHistory(childId);
    if (localHistory.isNotEmpty && !forceRemoteFetch) {
      final progress = localHistory[todayKey] ?? _emptyDailyProgress(todayKey);
      await _saveLocalTaskProgress(childId: childId, progress: progress);
      _schedulePendingTaskHistorySync(childId);
      return progress;
    }

    try {
      final snapshot = await _awaitOrNullOnTimeout(_childDocument(childId).get());
      if (snapshot == null) {
        return _getLocalCurrentProgress(childId: childId, todayKey: todayKey);
      }
      if (!snapshot.exists) {
        throw const ChildTaskProgressFailure('لم يتم العثور على ملف الطفل المحدد.');
      }

      final remoteHistory = _historyFromData(snapshot.data() ?? const <String, dynamic>{});
      final localHistory = await _getLocalTaskHistory(childId);
      final mergedHistory = _mergeHistoryMaps(remoteHistory, localHistory);
      await _saveLocalTaskHistory(childId, mergedHistory);

      _enqueueProgressHistorySync(childId, <String, ChildDailyTaskProgress>{
        todayKey: mergedHistory[todayKey] ?? _emptyDailyProgress(todayKey),
      });
      final progress = mergedHistory[todayKey] ?? _emptyDailyProgress(todayKey);
      await _saveLocalTaskProgress(childId: childId, progress: progress);
      return progress;
    } on FirebaseException catch (e) {
      if (_shouldUseLocalFallback(e)) {
        return _getLocalCurrentProgress(childId: childId, todayKey: todayKey);
      }
      throw ChildTaskProgressFailure(_mapFirebaseError(e));
    } on TimeoutException {
      return _getLocalCurrentProgress(childId: childId, todayKey: todayKey);
    }
  }

  Future<ChildWeeklyTaskProgress> getSelectedChildWeeklyProgress({
    int dayCount = 7,
  }) async {
    final childId = await _selectedChildId();
    final safeDayCount = dayCount.clamp(1, 30).toInt();
    final localHistory = await _getLocalTaskHistory(childId);
    if (localHistory.isNotEmpty) {
      _schedulePendingTaskHistorySync(childId);
      return ChildWeeklyTaskProgress(
        days: _buildRecentHistoryWindow(localHistory, dayCount: safeDayCount),
      );
    }

    try {
      final snapshot = await _awaitOrNullOnTimeout(_childDocument(childId).get());
      if (snapshot == null) {
        final localHistory = await _getLocalTaskHistory(childId);
        return ChildWeeklyTaskProgress(
          days: _buildRecentHistoryWindow(localHistory, dayCount: safeDayCount),
        );
      }
      if (!snapshot.exists) {
        throw const ChildTaskProgressFailure('لم يتم العثور على ملف الطفل المحدد.');
      }

      final remoteHistory = _historyFromData(snapshot.data() ?? const <String, dynamic>{});
      final localHistory = await _getLocalTaskHistory(childId);
      final mergedHistory = _mergeHistoryMaps(remoteHistory, localHistory);
      await _saveLocalTaskHistory(childId, mergedHistory);
      _enqueueProgressHistorySync(childId, mergedHistory);

      return ChildWeeklyTaskProgress(
        days: _buildRecentHistoryWindow(mergedHistory, dayCount: safeDayCount),
      );
    } on FirebaseException catch (e) {
      if (_shouldUseLocalFallback(e)) {
        final localHistory = await _getLocalTaskHistory(childId);
        return ChildWeeklyTaskProgress(
          days: _buildRecentHistoryWindow(localHistory, dayCount: safeDayCount),
        );
      }
      throw ChildTaskProgressFailure(_mapFirebaseError(e));
    } on TimeoutException {
      final localHistory = await _getLocalTaskHistory(childId);
      return ChildWeeklyTaskProgress(
        days: _buildRecentHistoryWindow(localHistory, dayCount: safeDayCount),
      );
    }
  }

  Future<void> updateSelectedChildDailyTaskPlan({
    required int totalTaskCount,
    Set<String> plannedTaskIds = const <String>{},
    Map<String, String> plannedTaskTitlesById = const <String, String>{},
  }) async {
    final childId = await _selectedChildId();
    final todayKey = _todayKey();
    final normalizedTotal = totalTaskCount < 0 ? 0 : totalTaskCount;
    final normalizedPlannedTaskIds = plannedTaskIds
        .map((taskId) => taskId.trim())
        .where(ChildTaskIds.isSupported)
        .toSet();
    final normalizedPlannedTaskTitlesById = <String, String>{
      for (final entry in plannedTaskTitlesById.entries)
        if (normalizedPlannedTaskIds.contains(entry.key.trim()) &&
            entry.value.trim().isNotEmpty)
          entry.key.trim(): entry.value.trim(),
    };

    final localHistory = await _getLocalTaskHistory(childId);
    final currentProgress = localHistory[todayKey] ?? _emptyDailyProgress(todayKey);
    final nextTotal = math.max(
      math.max(normalizedTotal, currentProgress.completedTaskCount),
      normalizedPlannedTaskIds.length,
    );
    if (nextTotal == currentProgress.totalTaskCount &&
        _stringSetEquals(
          currentProgress.plannedTaskIds,
          normalizedPlannedTaskIds,
        ) &&
        _stringMapEquals(
          currentProgress.plannedTaskTitlesById,
          normalizedPlannedTaskTitlesById,
        )) {
      _schedulePendingTaskHistorySync(childId);
      return;
    }

    final nextProgress = currentProgress.copyWith(
      totalTaskCount: nextTotal,
      plannedTaskIds: normalizedPlannedTaskIds,
      plannedTaskTitlesById: normalizedPlannedTaskTitlesById,
    );
    final nextHistory = _pruneHistory(<String, ChildDailyTaskProgress>{
      ...localHistory,
      todayKey: nextProgress,
    });

    await _saveLocalTaskHistory(childId, nextHistory);
    await _saveLocalTaskProgress(childId: childId, progress: nextProgress);
    await _savePendingTaskHistory(
      childId: childId,
      pendingHistory: <String, ChildDailyTaskProgress>{todayKey: nextProgress},
      mergeWithExisting: true,
    );
    _enqueueProgressHistorySync(childId, <String, ChildDailyTaskProgress>{
      todayKey: nextProgress,
    });
    _schedulePendingTaskHistorySync(childId);
  }

  Future<ChildTaskCompletionResult> completeSelectedChildTask({
    required String taskId,
    int rewardCoins = ChildRewardService.taskRewardCoins,
  }) async {
    final cleanTaskId = taskId.trim();
    if (!ChildTaskIds.isSupported(cleanTaskId)) {
      throw const ChildTaskProgressFailure('تعذر تحديد المهمة المطلوب حفظها.');
    }

    final childId = await _selectedChildId();
    final todayKey = _todayKey();
    final normalizedRewardCoins = rewardCoins.clamp(0, 999).toInt();
    final localResult = await _completeTaskLocally(
      childId: childId,
      taskId: cleanTaskId,
      todayKey: todayKey,
      rewardCoins: normalizedRewardCoins,
    );
    _schedulePendingTaskHistorySync(childId);
    return localResult;

/*
    await _trySyncPendingTaskHistory(childId);

    final localHistory = await _getLocalTaskHistory(childId);
    final localTodayProgress = localHistory[todayKey] ?? _emptyDailyProgress(todayKey);

    try {
      final result = await _firestore
          .runTransaction<_TaskCompletionSaveResult>((transaction) async {
            final snapshot = await transaction.get(_childDocument(childId));
            if (!snapshot.exists) {
              throw const ChildTaskProgressFailure(
                'لم يتم العثور على ملف الطفل المحدد.',
              );
            }

            final data = snapshot.data() ?? const <String, dynamic>{};
            final remoteHistory = _historyFromData(data);
            final currentProgress = _mergeDailyProgress(
              remoteHistory[todayKey] ?? _emptyDailyProgress(todayKey),
              localTodayProgress,
            );
            final alreadyCompleted = currentProgress.isCompleted(cleanTaskId);
            final awardedCoins = alreadyCompleted ? 0 : normalizedRewardCoins;
            final nextCompletedTaskIds = <String>{
              ...currentProgress.completedTaskIds,
              cleanTaskId,
            };
            final nextRewards = <String, int>{
              ...currentProgress.awardedCoinsByTaskId,
              if (!alreadyCompleted && awardedCoins > 0) cleanTaskId: awardedCoins,
            };
            final nextProgress = ChildDailyTaskProgress(
              dateKey: todayKey,
              completedTaskIds: nextCompletedTaskIds,
              totalTaskCount: math.max(
                currentProgress.totalTaskCount,
                nextCompletedTaskIds.length,
              ),
              awardedCoinsByTaskId: nextRewards,
            );
            final nextHistory = _pruneHistory(<String, ChildDailyTaskProgress>{
              ...remoteHistory,
              todayKey: nextProgress,
            });
            final currentCoins = ChildRewardService.parseCoinsValue(data['coins']);
            final nextCoins = currentCoins + awardedCoins;
            final currentLevelState = _levelStateFromChildData(
              data,
              fallbackTargetTasks: math.max(currentProgress.totalTaskCount, 1),
            );
            final nextLevelState = alreadyCompleted
                ? currentLevelState
                : _advanceLevelState(
                    currentLevelState,
                    fallbackTargetTasks: math.max(
                      currentProgress.totalTaskCount,
                      1,
                    ),
                  );

            transaction.set(_childDocument(childId), {
              'coins': nextCoins,
              'levelState': nextLevelState.toMap(),
              'dailyTaskProgress': _dailyTaskProgressMap(nextProgress),
              'taskProgressHistory': _historyMapToFirestore(nextHistory),
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));

            return _TaskCompletionSaveResult(
              history: nextHistory,
              completionResult: ChildTaskCompletionResult(
                progress: nextProgress,
                coinsBalance: nextCoins,
                awardedCoins: awardedCoins,
                alreadyCompletedToday: alreadyCompleted,
                levelState: nextLevelState,
              ),
            );
          })
          .timeout(_requestTimeout);

      await _saveLocalTaskHistory(childId, result.history);
      await _saveLocalTaskProgress(
        childId: childId,
        progress: result.completionResult.progress,
      );
      await _saveLocalWallet(
        childId: childId,
        coinsBalance: result.completionResult.coinsBalance,
        levelState: result.completionResult.levelState,
      );
      await _clearPendingTaskHistoryDays(
        childId: childId,
        dateKeys: <String>{todayKey},
      );
      _enqueueProgressHistorySync(childId, <String, ChildDailyTaskProgress>{
        todayKey: result.completionResult.progress,
      });
      return result.completionResult;
    } on ChildTaskProgressFailure {
      rethrow;
    } on FirebaseException catch (e) {
      if (_shouldUseLocalFallback(e)) {
        return _completeTaskLocally(
          childId: childId,
          taskId: cleanTaskId,
          todayKey: todayKey,
          rewardCoins: normalizedRewardCoins,
        );
      }
      throw ChildTaskProgressFailure(_mapFirebaseError(e));
    } on TimeoutException {
      return _completeTaskLocally(
        childId: childId,
        taskId: cleanTaskId,
        todayKey: todayKey,
        rewardCoins: normalizedRewardCoins,
      );
    }
*/
  }

  Future<_TaskHistorySyncResult?> _trySyncPendingTaskHistory(String childId) async {
    final pendingHistory = await _getPendingTaskHistory(childId);
    if (pendingHistory.isEmpty) {
      return null;
    }
    final localWallet = await _getLocalWallet(childId);

    try {
      final syncResult = await _awaitOrNullOnTimeout(_firestore
          .runTransaction<_TaskHistorySyncResult>((transaction) async {
            final snapshot = await transaction.get(_childDocument(childId));
            if (!snapshot.exists) {
              throw const ChildTaskProgressFailure(
                'لم يتم العثور على ملف الطفل المحدد.',
              );
            }

            final data = snapshot.data() ?? const <String, dynamic>{};
            final remoteHistory = _historyFromData(data);
            final nextHistory = _mergeHistoryMaps(remoteHistory, pendingHistory);
            final awardedCoinDelta = _calculateCoinDelta(
              remoteHistory: remoteHistory,
              pendingHistory: pendingHistory,
            );
            final currentCoins = ChildRewardService.parseCoinsValue(data['coins']);
            final nextCoins = currentCoins + awardedCoinDelta;
            final remoteLevelState = _levelStateFromChildData(
              data,
              fallbackTargetTasks: _latestProgressFromHistory(nextHistory)
                  .totalTaskCount,
            );
            final levelStateToPersist = _preferNewerLevelState(
              primary: localWallet.levelState,
              secondary: remoteLevelState,
            );

            transaction.set(_childDocument(childId), {
              'coins': nextCoins,
              'levelState': levelStateToPersist.toMap(),
              'dailyTaskProgress': _dailyTaskProgressMap(
                _latestProgressFromHistory(nextHistory),
              ),
              'taskProgressHistory': _historyMapToFirestore(nextHistory),
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));

            return _TaskHistorySyncResult(
              history: nextHistory,
              coinsBalance: nextCoins,
              levelState: levelStateToPersist,
            );
          }));
      if (syncResult == null) {
        return null;
      }

      await _saveLocalTaskHistory(childId, syncResult.history);
      await _saveLocalTaskProgress(
        childId: childId,
        progress: syncResult.history[_todayKey()] ?? _emptyDailyProgress(_todayKey()),
      );
      await _saveLocalWallet(
        childId: childId,
        coinsBalance: syncResult.coinsBalance,
        levelState: syncResult.levelState,
      );
      await _clearPendingTaskHistoryIfUnchanged(
        childId: childId,
        syncedPendingHistory: pendingHistory,
      );
      _enqueueProgressHistorySync(childId, pendingHistory);
      return syncResult;
    } on ChildTaskProgressFailure {
      return null;
    } on FirebaseException catch (e) {
      if (_shouldUseLocalFallback(e)) {
        return null;
      }
      return null;
    } on TimeoutException {
      return null;
    }
  }

  void _schedulePendingTaskHistorySync(String childId) {
    if (_progressSyncInFlight.contains(childId)) {
      return;
    }

    _progressSyncInFlight.add(childId);
    unawaited(() async {
      try {
        await _trySyncPendingTaskHistory(childId);
      } finally {
        _progressSyncInFlight.remove(childId);
      }
    }());
  }

  Future<ChildTaskCompletionResult> _completeTaskLocally({
    required String childId,
    required String taskId,
    required String todayKey,
    required int rewardCoins,
  }) async {
    final localHistory = await _getLocalTaskHistory(childId);
    final currentProgress = localHistory[todayKey] ?? _emptyDailyProgress(todayKey);
    final alreadyCompleted = currentProgress.isCompleted(taskId);
    final awardedCoins = alreadyCompleted ? 0 : rewardCoins;
    final nextCompletedTaskIds = <String>{
      ...currentProgress.completedTaskIds,
      taskId,
    };
    final nextRewards = <String, int>{
      ...currentProgress.awardedCoinsByTaskId,
      if (!alreadyCompleted && awardedCoins > 0) taskId: awardedCoins,
    };
    final nextProgress = ChildDailyTaskProgress(
      dateKey: todayKey,
      completedTaskIds: nextCompletedTaskIds,
      totalTaskCount: math.max(
        currentProgress.totalTaskCount,
        nextCompletedTaskIds.length,
      ),
      awardedCoinsByTaskId: nextRewards,
    );
    final nextHistory = _pruneHistory(<String, ChildDailyTaskProgress>{
      ...localHistory,
      todayKey: nextProgress,
    });
    final currentWallet = await _getLocalWallet(childId);
    final currentLevelState = _normalizeLevelState(
      currentWallet.levelState,
      fallbackTargetTasks: math.max(currentProgress.totalTaskCount, 1),
    );
    final nextLevelState = alreadyCompleted
        ? currentLevelState
        : _advanceLevelState(
            currentLevelState,
            fallbackTargetTasks: math.max(currentProgress.totalTaskCount, 1),
          );
    final nextCoins = currentWallet.coins + awardedCoins;

    await _saveLocalTaskHistory(childId, nextHistory);
    await _saveLocalTaskProgress(childId: childId, progress: nextProgress);
    await _saveLocalWallet(
      childId: childId,
      coinsBalance: nextCoins,
      levelState: nextLevelState,
    );
    await _savePendingTaskHistory(
      childId: childId,
      pendingHistory: <String, ChildDailyTaskProgress>{todayKey: nextProgress},
      mergeWithExisting: true,
    );
    _enqueueProgressHistorySync(childId, <String, ChildDailyTaskProgress>{
      todayKey: nextProgress,
    });

    return ChildTaskCompletionResult(
      progress: nextProgress,
      coinsBalance: nextCoins,
      awardedCoins: awardedCoins,
      alreadyCompletedToday: alreadyCompleted,
      levelState: nextLevelState,
    );
  }

  Future<ChildDailyTaskProgress> _getLocalCurrentProgress({
    required String childId,
    required String todayKey,
  }) async {
    final localHistory = await _getLocalTaskHistory(childId);
    final progress = localHistory[todayKey] ?? _emptyDailyProgress(todayKey);
    await _saveLocalTaskProgress(childId: childId, progress: progress);
    return progress;
  }

  Future<Map<String, ChildDailyTaskProgress>> _getLocalTaskHistory(
    String childId,
  ) async {
    final localHistoryData = await _localStateService.getTaskProgressHistoryMap(
      childId: childId,
    );
    final history = _historyFromRawMap(localHistoryData);
    if (history.isNotEmpty) {
      return history;
    }

    final legacyTodayData = await _localStateService.getDailyTaskProgressMap(
      childId: childId,
    );
    if (legacyTodayData == null || legacyTodayData.isEmpty) {
      return <String, ChildDailyTaskProgress>{};
    }

    final legacyProgress = _progressFromEntryMap(legacyTodayData);
    if (!_isValidDateKey(legacyProgress.dateKey)) {
      return <String, ChildDailyTaskProgress>{};
    }
    return <String, ChildDailyTaskProgress>{legacyProgress.dateKey: legacyProgress};
  }

  Future<Map<String, ChildDailyTaskProgress>> _getPendingTaskHistory(
    String childId,
  ) async {
    final rawPending = await _localStateService.getPendingTaskProgressSyncMap(
      childId: childId,
    );
    return _historyFromRawMap(rawPending);
  }

  Future<void> _saveLocalTaskHistory(
    String childId,
    Map<String, ChildDailyTaskProgress> history,
  ) async {
    await _localStateService.saveTaskProgressHistoryMap(
      childId: childId,
      data: _historyMapToFirestore(history),
    );
  }

  Future<void> _savePendingTaskHistory({
    required String childId,
    required Map<String, ChildDailyTaskProgress> pendingHistory,
    required bool mergeWithExisting,
  }) async {
    final nextPending = mergeWithExisting
        ? _mergeHistoryMaps(
            await _getPendingTaskHistory(childId),
            pendingHistory,
          )
        : pendingHistory;
    await _localStateService.savePendingTaskProgressSyncMap(
      childId: childId,
      data: _historyMapToFirestore(nextPending),
    );
  }

  // ignore: unused_element
  Future<void> _clearPendingTaskHistoryDays({
    required String childId,
    required Set<String> dateKeys,
  }) async {
    if (dateKeys.isEmpty) {
      return;
    }

    final pendingHistory = await _getPendingTaskHistory(childId);
    if (pendingHistory.isEmpty) {
      return;
    }

    final nextPending = <String, ChildDailyTaskProgress>{...pendingHistory}
      ..removeWhere((key, _) => dateKeys.contains(key));
    await _localStateService.savePendingTaskProgressSyncMap(
      childId: childId,
      data: _historyMapToFirestore(nextPending),
    );
  }

  Future<void> _clearPendingTaskHistoryIfUnchanged({
    required String childId,
    required Map<String, ChildDailyTaskProgress> syncedPendingHistory,
  }) async {
    final latestPendingHistory = await _getPendingTaskHistory(childId);
    if (!_historyMapsEqual(latestPendingHistory, syncedPendingHistory)) {
      return;
    }

    await _localStateService.savePendingTaskProgressSyncMap(
      childId: childId,
      data: const <String, dynamic>{},
    );
  }

  Map<String, ChildDailyTaskProgress> _historyFromData(Map<String, dynamic> data) {
    final history = _historyFromRawMap(data['taskProgressHistory']);
    final legacyProgress = _legacyProgressFromData(data);
    if (legacyProgress != null && _isValidDateKey(legacyProgress.dateKey)) {
      final existing = history[legacyProgress.dateKey];
      history[legacyProgress.dateKey] = existing == null
          ? legacyProgress
          : _mergeDailyProgress(existing, legacyProgress);
    }
    return _pruneHistory(history);
  }

  Map<String, ChildDailyTaskProgress> _historyFromRawMap(Object? rawHistory) {
    if (rawHistory is! Map) {
      return <String, ChildDailyTaskProgress>{};
    }

    final history = <String, ChildDailyTaskProgress>{};
    for (final entry in rawHistory.entries) {
      final dateKey = entry.key.toString().trim();
      if (!_isValidDateKey(dateKey) || entry.value is! Map) {
        continue;
      }
      history[dateKey] = _progressFromEntryMap(
        (entry.value as Map).map(
          (key, value) => MapEntry(key.toString(), value),
        ),
        fallbackDateKey: dateKey,
      );
    }
    return _pruneHistory(history);
  }

  ChildDailyTaskProgress? _legacyProgressFromData(Map<String, dynamic> data) {
    final rawProgress = data['dailyTaskProgress'];
    if (rawProgress is! Map) {
      return null;
    }
    final normalized = rawProgress.map(
      (key, value) => MapEntry(key.toString(), value),
    );
    final progress = _progressFromEntryMap(normalized);
    return _isValidDateKey(progress.dateKey) ? progress : null;
  }

  ChildDailyTaskProgress _progressFromEntryMap(
    Map<String, dynamic> data, {
    String? fallbackDateKey,
  }) {
    final dateKey = (data['dateKey'] as String? ?? fallbackDateKey ?? '').trim();
    final rawCompletedTaskIds = data['completedTaskIds'];
    final completedTaskIds = rawCompletedTaskIds is Iterable
        ? rawCompletedTaskIds
              .whereType<String>()
              .map((item) => item.trim())
              .where(ChildTaskIds.isSupported)
              .toSet()
        : <String>{};
    final rawRewardMap = data['awardedCoinsByTaskId'];
    final awardedCoinsByTaskId = <String, int>{};
    if (rawRewardMap is Map) {
      for (final entry in rawRewardMap.entries) {
        final taskId = entry.key.toString().trim();
        if (!completedTaskIds.contains(taskId)) {
          continue;
        }
        awardedCoinsByTaskId[taskId] = _toInt(entry.value, fallback: 0);
      }
    }

    final parsedTotalTaskCount = _toInt(
      data['totalTaskCount'],
      fallback: completedTaskIds.length,
    );
    final rawPlannedTaskIds = data['plannedTaskIds'];
    final plannedTaskIds = rawPlannedTaskIds is Iterable
        ? rawPlannedTaskIds
              .whereType<String>()
              .map((item) => item.trim())
              .where(ChildTaskIds.isSupported)
              .toSet()
        : <String>{};
    final rawPlannedTitles = data['plannedTaskTitlesById'];
    final plannedTaskTitlesById = <String, String>{};
    if (rawPlannedTitles is Map) {
      for (final entry in rawPlannedTitles.entries) {
        final taskId = entry.key.toString().trim();
        final title = entry.value.toString().trim();
        if (!plannedTaskIds.contains(taskId) || title.isEmpty) {
          continue;
        }
        plannedTaskTitlesById[taskId] = title;
      }
    }

    return ChildDailyTaskProgress(
      dateKey: dateKey,
      completedTaskIds: completedTaskIds,
      totalTaskCount: math.max(
        math.max(parsedTotalTaskCount, completedTaskIds.length),
        plannedTaskIds.length,
      ),
      awardedCoinsByTaskId: awardedCoinsByTaskId,
      plannedTaskIds: plannedTaskIds,
      plannedTaskTitlesById: plannedTaskTitlesById,
    );
  }

  Map<String, ChildDailyTaskProgress> _mergeHistoryMaps(
    Map<String, ChildDailyTaskProgress> primary,
    Map<String, ChildDailyTaskProgress> secondary,
  ) {
    final merged = <String, ChildDailyTaskProgress>{};
    final dateKeys = <String>{...primary.keys, ...secondary.keys};
    for (final dateKey in dateKeys) {
      final primaryValue = primary[dateKey];
      final secondaryValue = secondary[dateKey];
      if (primaryValue == null && secondaryValue != null) {
        merged[dateKey] = secondaryValue;
        continue;
      }
      if (secondaryValue == null && primaryValue != null) {
        merged[dateKey] = primaryValue;
        continue;
      }
      if (primaryValue != null && secondaryValue != null) {
        merged[dateKey] = _mergeDailyProgress(primaryValue, secondaryValue);
      }
    }
    return _pruneHistory(merged);
  }

  bool _historyMapsEqual(
    Map<String, ChildDailyTaskProgress> first,
    Map<String, ChildDailyTaskProgress> second,
  ) {
    return jsonEncode(_historyMapToFirestore(first)) ==
        jsonEncode(_historyMapToFirestore(second));
  }

  ChildDailyTaskProgress _mergeDailyProgress(
    ChildDailyTaskProgress primary,
    ChildDailyTaskProgress secondary,
  ) {
    final mergedTaskIds = <String>{
      ...primary.completedTaskIds,
      ...secondary.completedTaskIds,
    };
    final mergedRewards = <String, int>{
      ...primary.awardedCoinsByTaskId,
      ...secondary.awardedCoinsByTaskId,
    }..removeWhere((taskId, _) => !mergedTaskIds.contains(taskId));
    final mergedPlannedTaskIds = <String>{
      ...primary.plannedTaskIds,
      ...secondary.plannedTaskIds,
    };
    final mergedPlannedTaskTitlesById = <String, String>{
      ...primary.plannedTaskTitlesById,
      ...secondary.plannedTaskTitlesById,
    }..removeWhere((taskId, _) => !mergedPlannedTaskIds.contains(taskId));
    return ChildDailyTaskProgress(
      dateKey: primary.dateKey,
      completedTaskIds: mergedTaskIds,
      totalTaskCount: math.max(
        math.max(
          math.max(primary.totalTaskCount, secondary.totalTaskCount),
          mergedPlannedTaskIds.length,
        ),
        mergedTaskIds.length,
      ),
      awardedCoinsByTaskId: mergedRewards,
      plannedTaskIds: mergedPlannedTaskIds,
      plannedTaskTitlesById: mergedPlannedTaskTitlesById,
    );
  }

  Map<String, ChildDailyTaskProgress> _pruneHistory(
    Map<String, ChildDailyTaskProgress> history,
  ) {
    final sortedKeys = history.keys.toList(growable: false)
      ..sort((a, b) => b.compareTo(a));
    final retainedKeys = sortedKeys.take(_historyRetentionDays).toSet();
    final pruned = <String, ChildDailyTaskProgress>{};
    for (final dateKey in sortedKeys.reversed) {
      if (retainedKeys.contains(dateKey)) {
        pruned[dateKey] = history[dateKey]!;
      }
    }
    return pruned;
  }

  List<ChildDailyTaskProgress> _buildRecentHistoryWindow(
    Map<String, ChildDailyTaskProgress> history, {
    required int dayCount,
  }) {
    return List<ChildDailyTaskProgress>.generate(dayCount, (index) {
      final offset = dayCount - index - 1;
      final date = DateTime.now().subtract(Duration(days: offset));
      final dateKey = _dateKeyFor(date);
      return history[dateKey] ?? _emptyDailyProgress(dateKey);
    }, growable: false);
  }

  int _calculateCoinDelta({
    required Map<String, ChildDailyTaskProgress> remoteHistory,
    required Map<String, ChildDailyTaskProgress> pendingHistory,
  }) {
    var total = 0;
    for (final entry in pendingHistory.entries) {
      final remoteDay = remoteHistory[entry.key] ?? _emptyDailyProgress(entry.key);
      for (final taskId in entry.value.completedTaskIds) {
        if (remoteDay.completedTaskIds.contains(taskId)) {
          continue;
        }
        total += entry.value.awardedCoinsByTaskId[taskId] ?? 0;
      }
    }
    return total;
  }

  Map<String, dynamic> _historyMapToFirestore(
    Map<String, ChildDailyTaskProgress> history,
  ) {
    final sortedKeys = history.keys.toList(growable: false)..sort();
    return <String, dynamic>{
      for (final dateKey in sortedKeys) dateKey: history[dateKey]!.toMap(),
    };
  }

  Map<String, dynamic> _dailyTaskProgressMap(ChildDailyTaskProgress progress) {
    return progress.toMap();
  }

  ChildDailyTaskProgress _latestProgressFromHistory(
    Map<String, ChildDailyTaskProgress> history,
  ) {
    if (history.isEmpty) {
      return _emptyDailyProgress(_todayKey());
    }
    final latestKey = history.keys.reduce((a, b) => a.compareTo(b) >= 0 ? a : b);
    return history[latestKey]!;
  }

  ChildDailyTaskProgress _emptyDailyProgress(String dateKey) {
    return ChildDailyTaskProgress(
      dateKey: dateKey,
      completedTaskIds: const <String>{},
    );
  }

  bool _stringSetEquals(Set<String> first, Set<String> second) {
    if (first.length != second.length) {
      return false;
    }
    for (final value in first) {
      if (!second.contains(value)) {
        return false;
      }
    }
    return true;
  }

  bool _stringMapEquals(
    Map<String, String> first,
    Map<String, String> second,
  ) {
    if (first.length != second.length) {
      return false;
    }
    for (final entry in first.entries) {
      if (second[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }

  ChildLevelState _levelStateFromChildData(
    Map<String, dynamic> data, {
    required int fallbackTargetTasks,
  }) {
    return ChildLevelState.fromMap(
      data['levelState'],
      fallbackTargetTasks: fallbackTargetTasks < 1 ? 1 : fallbackTargetTasks,
    );
  }

  ChildLevelState _normalizeLevelState(
    ChildLevelState levelState, {
    required int fallbackTargetTasks,
  }) {
    final safeFallbackTarget = fallbackTargetTasks < 1 ? 1 : fallbackTargetTasks;
    if (levelState.targetTasks > 0) {
      final shouldRebaseFirstLevel =
          levelState.level == 0 &&
          levelState.progressTasks == 0 &&
          !levelState.hasPendingReward &&
          levelState.targetTasks == 1 &&
          safeFallbackTarget != 1;
      if (!shouldRebaseFirstLevel) {
        return levelState;
      }
    }
    return ChildLevelState(
      level: levelState.level < 0 ? 0 : levelState.level,
      progressTasks: levelState.progressTasks < 0 ? 0 : levelState.progressTasks,
      targetTasks: safeFallbackTarget,
      pendingRewardLevels: levelState.pendingRewardLevels,
    );
  }

  int _nextLevelTarget(int currentTarget) {
    final safeTarget = currentTarget < 1 ? 1 : currentTarget;
    return ((safeTarget * 4) / 3).ceil();
  }

  ChildLevelState _advanceLevelState(
    ChildLevelState levelState, {
    required int fallbackTargetTasks,
  }) {
    final normalized = _normalizeLevelState(
      levelState,
      fallbackTargetTasks: fallbackTargetTasks,
    );
    var nextLevel = normalized.level;
    var nextProgressTasks = normalized.progressTasks + 1;
    var nextTargetTasks = normalized.targetTasks;
    final nextPendingLevels = List<int>.from(normalized.pendingRewardLevels);

    while (nextProgressTasks >= nextTargetTasks) {
      nextProgressTasks -= nextTargetTasks;
      nextLevel += 1;
      nextPendingLevels.add(nextLevel);
      nextTargetTasks = _nextLevelTarget(nextTargetTasks);
    }

    return ChildLevelState(
      level: nextLevel,
      progressTasks: nextProgressTasks,
      targetTasks: nextTargetTasks,
      pendingRewardLevels: nextPendingLevels,
    );
  }

  ChildLevelState _preferNewerLevelState({
    required ChildLevelState primary,
    required ChildLevelState secondary,
  }) {
    if (primary.level != secondary.level) {
      return primary.level > secondary.level ? primary : secondary;
    }
    if (primary.progressTasks != secondary.progressTasks) {
      return primary.progressTasks > secondary.progressTasks
          ? primary
          : secondary;
    }
    if (primary.pendingRewardLevels.length != secondary.pendingRewardLevels.length) {
      return primary.pendingRewardLevels.length >
              secondary.pendingRewardLevels.length
          ? primary
          : secondary;
    }
    return primary.targetTasks >= secondary.targetTasks ? primary : secondary;
  }

  Future<String> _selectedChildId() async {
    final childId = await _selectedChildService.getSelectedChildId();
    if (childId == null || childId.trim().isEmpty) {
      throw const ChildTaskProgressFailure('الرجاء اختيار الطفل أولًا.');
    }
    return childId.trim();
  }

  DocumentReference<Map<String, dynamic>> _childDocument(String childId) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw const ChildTaskProgressFailure('يجب تسجيل الدخول أولًا.');
    }

    return _firestore.collection('users').doc(uid).collection('children').doc(
      childId,
    );
  }

  Future<void> _saveLocalTaskProgress({
    required String childId,
    required ChildDailyTaskProgress progress,
  }) async {
    await _localStateService.saveDailyTaskProgressMap(
      childId: childId,
      data: <String, dynamic>{
        'dateKey': progress.dateKey,
        'completedTaskIds': progress.completedTaskIds.toList(growable: false)
          ..sort(),
      },
    );
  }

  Future<ChildWalletState> _getLocalWallet(String childId) async {
    final localData = await _localStateService.getWalletMap(childId: childId);
    if (localData == null || localData.isEmpty) {
      return const ChildWalletState(
        coins: ChildRewardService.defaultCoins,
        ownedMarketItemAssetPaths: <String>[],
      );
    }
    return ChildWalletState.fromMap(localData);
  }

  Future<void> _saveLocalWallet({
    required String childId,
    required int coinsBalance,
    ChildLevelState? levelState,
  }) async {
    final currentWallet = await _getLocalWallet(childId);
    final nextWallet = currentWallet.copyWith(
      coins: coinsBalance,
      levelState: levelState ?? currentWallet.levelState,
    );
    await _localStateService.saveWalletMap(
      childId: childId,
      data: nextWallet.toMap(),
    );
  }

  bool _shouldUseLocalFallback(FirebaseException e) {
    final message = e.message ?? '';
    final normalizedCode = e.code.trim().toLowerCase();
    final normalizedMessage = message.toLowerCase();
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
        normalizedMessage.contains('deadline exceeded') ||
        normalizedMessage.contains('deadline-exceeded') ||
        normalizedMessage.contains('timed out') ||
        normalizedMessage.contains('timeout') ||
        normalizedMessage.contains('network') ||
        normalizedMessage.contains('unable to resolve host');
  }

  String _todayKey([DateTime? now]) => _dateKeyFor(now ?? DateTime.now());

  String _dateKeyFor(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  bool _isValidDateKey(String value) {
    return RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value);
  }

  int _toInt(Object? value, {required int fallback}) {
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

  String _mapFirebaseError(FirebaseException e) {
    final message = e.message ?? '';
    if (message.contains('Cloud Firestore API has not been used')) {
      return 'خدمة Firestore غير مفعلة في مشروع Firebase. فعّل Firestore Database ثم أعد المحاولة.';
    }

    switch (e.code) {
      case 'permission-denied':
        return 'ليس لديك صلاحية للوصول إلى قاعدة البيانات. تحقق من قواعد Firestore.';
      case 'unavailable':
        return 'خدمة قاعدة البيانات غير متاحة حاليًا. حاول بعد قليل.';
      case 'resource-exhausted':
        return 'تم تجاوز حصة Firestore الحالية. سيستخدم التطبيق تقدم المهام المحلي ويحاول المزامنة لاحقًا.';
      default:
        return 'تعذر حفظ تقدم المهمة حاليًا. حاول مرة أخرى.';
    }
  }

  void _enqueueProgressHistorySync(
    String childId,
    Map<String, ChildDailyTaskProgress> history,
  ) {
    if (history.isEmpty) {
      return;
    }

    unawaited(
      _emailNotificationService.syncChildProgressHistory(
        childId: childId,
        progressHistory: _historyMapToFirestore(history),
      ),
    );
  }
}

class ChildTaskProgressFailure implements Exception {
  const ChildTaskProgressFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
