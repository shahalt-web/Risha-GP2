import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:risha_v01/shared/config/feature_flags.dart';
import 'package:risha_v01/shared/services/child_behavior_service.dart';
import 'package:risha_v01/shared/services/child_reward_service.dart';
import 'package:risha_v01/shared/services/selected_child_service.dart';
import 'package:risha_v01/shared/services/child_task_progress_service.dart';
import 'package:risha_v01/shared/widgets/child_mascot_avatar.dart';

import 'package:just_audio/just_audio.dart';

class ChildDailyHomeScreen extends StatefulWidget {
  const ChildDailyHomeScreen({super.key});

  @override
  State<ChildDailyHomeScreen> createState() => _ChildDailyHomeScreenState();
}

class _ChildDailyHomeScreenState extends State<ChildDailyHomeScreen>
    with WidgetsBindingObserver {
  static const int _morningUnlockMinutes = 6 * 60;
  static const int _wakeSectionEndMinutes = 11 * 60;
  static const int _sleepSectionStartMinutes = 20 * 60;
  static const int _defaultSleepTimeMinutes = 21 * 60;
  static const int _defaultWaterWindowStartMinutes = 8 * 60;
  static const int _defaultWaterWindowEndMinutes = 20 * 60;
  static const Duration _rewardListenerInitialDelay = Duration(seconds: 10);
  static const Duration _rewardListenerWindowDuration = Duration(minutes: 5);
  static const Duration _rewardListenerShortRetryDelay = Duration(minutes: 1);
  static const Duration _rewardListenerLongRetryDelay = Duration(minutes: 5);
  static const int _rewardListenerShortRetryLimit = 5;

  String? _equippedOutfitAssetPath;
  String? _equippedAccessoryAssetPath;

  final _selectedChildService = SelectedChildService();
  final _childBehaviorService = ChildBehaviorService();
  final _childRewardService = ChildRewardService();
  final _childTaskProgressService = ChildTaskProgressService();

  StreamSubscription<ChildWalletState>? _walletSubscription;
  final Set<String> _sessionNotifiedRewardKeys = <String>{};
  Timer? _sleepStateTimer;
  Timer? _rewardListenerStartTimer;
  Timer? _rewardListenerWindowTimer;
  int _rewardListenerShortRetryCount = 0;
  bool _sleepRoutineConfigured = false;
  bool _sleepNotificationsEnabled = true;
  int? _sleepTimeMinutes;
  bool _isSleepOverlayVisible = false;
  ChildWalletState? _walletState;
  int? _coinsBalance;
  bool _isLoadingCoins = true;
  bool _isLoadingBehaviorConfig = true;
  bool _isLoadingTaskProgress = true;
  bool _isLevelRewardDialogVisible = false;
  Set<String> _completedTaskIds = <String>{};
  Set<String> _pendingVerificationTaskIds = <String>{};
  Set<String> _enabledBehaviorIds = <String>{};
  int _waterCupsCount = 2;
  List<int> _waterReminderTimesMinutes = const <int>[10 * 60, 15 * 60];
  List<int> _sportSessionTimesMinutes = const <int>[8 * 60];
  List<CustomBehaviorConfig> _customBehaviors = const <CustomBehaviorConfig>[];

  bool get _showSleepOverlay =>
      !FeatureFlags.disableSleepLockTemporarily && _isSleepOverlayVisible;
  bool get _keepDailyCardsEnabled =>
      FeatureFlags.keepDailyCardsEnabledTemporarily ||
      FeatureFlags.bypassDailyTaskCompletionRestrictionsTemporarily;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sleepStateTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      final wasVisible = _isSleepOverlayVisible;
      _refreshSleepOverlayState();
      if (_isSleepOverlayVisible != wasVisible) {
        setState(() {});
      }
    });
    unawaited(_loadCoinsBalance());
    unawaited(_loadBehaviorConfigState());
    unawaited(_loadTaskProgress());
  }

  void _startRewardListenerWindow() {
    if (!mounted || !_shouldListenForRewards(_walletState)) {
      _stopRewardListenerOrchestration();
      return;
    }

    _rewardListenerStartTimer?.cancel();
    _rewardListenerWindowTimer?.cancel();
    _walletSubscription?.cancel();
    _walletSubscription = _childRewardService.watchSelectedChildWallet().listen(
      (wallet) {
        if (!mounted) return;

        setState(() {
          _walletState = wallet;
          _coinsBalance = wallet.coins;
          _isLoadingCoins = false;
          _equippedOutfitAssetPath = wallet.equippedOutfitAssetPath;
          _equippedAccessoryAssetPath = wallet.equippedAccessoryAssetPath;
          _pendingVerificationTaskIds = _pendingTaskIdsFromWallet(wallet);
        });

        _checkProcessedRewards(wallet);
        _showPendingLevelRewardIfNeeded(wallet);
        if (_hasProcessedRewardResults(wallet)) {
          final hasPendingRewards = _shouldListenForRewards(wallet);
          _stopRewardListenerOrchestration();
          if (hasPendingRewards) {
            _syncRewardListenerForWallet(wallet, resetBackoff: true);
          }
        }
      },
      onError: (error) {
        debugPrint('Wallet stream error: $error');
        _stopRewardListenerOrchestration(resetBackoff: false);
        _scheduleNextRewardListenerWindow();
      },
    );

    _rewardListenerWindowTimer = Timer(_rewardListenerWindowDuration, () {
      _walletSubscription?.cancel();
      _walletSubscription = null;
      _rewardListenerWindowTimer = null;
      _scheduleNextRewardListenerWindow();
    });
  }

  void _scheduleRewardListenerInitialWindow() {
    if (!mounted || !_shouldListenForRewards(_walletState)) {
      _stopRewardListenerOrchestration();
      return;
    }

    _rewardListenerStartTimer?.cancel();
    _rewardListenerWindowTimer?.cancel();
    _walletSubscription?.cancel();
    _walletSubscription = null;
    _rewardListenerShortRetryCount = 0;
    _rewardListenerStartTimer = Timer(_rewardListenerInitialDelay, () {
      _rewardListenerStartTimer = null;
      _startRewardListenerWindow();
    });
  }

  void _scheduleNextRewardListenerWindow() {
    if (!mounted || !_shouldListenForRewards(_walletState)) {
      _stopRewardListenerOrchestration();
      return;
    }
    if (_rewardListenerStartTimer?.isActive ?? false) {
      return;
    }
    if (_rewardListenerWindowTimer?.isActive ??
        false || _walletSubscription != null) {
      return;
    }

    final useShortDelay =
        _rewardListenerShortRetryCount < _rewardListenerShortRetryLimit;
    if (useShortDelay) {
      _rewardListenerShortRetryCount += 1;
    }
    final delay = useShortDelay
        ? _rewardListenerShortRetryDelay
        : _rewardListenerLongRetryDelay;
    _rewardListenerStartTimer = Timer(delay, () {
      _rewardListenerStartTimer = null;
      _startRewardListenerWindow();
    });
  }

  void _syncRewardListenerForWallet(
    ChildWalletState? wallet, {
    bool resetBackoff = false,
  }) {
    if (!mounted) {
      return;
    }

    if (!_shouldListenForRewards(wallet)) {
      _stopRewardListenerOrchestration();
      return;
    }

    if (resetBackoff) {
      _scheduleRewardListenerInitialWindow();
      return;
    }

    if (_walletSubscription != null ||
        (_rewardListenerStartTimer?.isActive ?? false) ||
        (_rewardListenerWindowTimer?.isActive ?? false)) {
      return;
    }

    _scheduleNextRewardListenerWindow();
  }

  void _stopRewardListenerOrchestration({bool resetBackoff = true}) {
    _rewardListenerStartTimer?.cancel();
    _rewardListenerStartTimer = null;
    _rewardListenerWindowTimer?.cancel();
    _rewardListenerWindowTimer = null;
    _walletSubscription?.cancel();
    _walletSubscription = null;
    if (resetBackoff) {
      _rewardListenerShortRetryCount = 0;
    }
  }

  bool _shouldListenForRewards(ChildWalletState? wallet) {
    if (wallet == null) return false;
    final hasPending = wallet.pendingRewards.any(
      (reward) => reward.status == PendingRewardStatus.pending,
    );
    if (hasPending) return true;

    return wallet.pendingRewards.any((reward) {
      if (reward.status == PendingRewardStatus.pending) return false;
      final rewardKey = '${reward.id}:${reward.status.name}';
      return !_sessionNotifiedRewardKeys.contains(rewardKey);
    });
  }

  Set<String> _pendingTaskIdsFromWallet(ChildWalletState? wallet) {
    if (wallet == null) return <String>{};

    return wallet.pendingRewards
        .where((reward) {
          if (reward.status != PendingRewardStatus.pending) return false;
          if (reward.rewardType.trim() != 'task_completion') return false;

          // Unblock the UI for tasks pending for more than 5 minutes
          final age = DateTime.now().difference(reward.requestedAt);
          if (age.inMinutes >= 5) return false;

          return true;
        })
        .map((reward) => reward.taskId?.trim() ?? '')
        .where((taskId) => taskId.isNotEmpty)
        .toSet();
  }

  bool _hasProcessedRewardResults(ChildWalletState wallet) {
    return wallet.pendingRewards.any(
      (reward) => reward.status != PendingRewardStatus.pending,
    );
  }

  bool _isShowingRewardDialog = false;

  void _checkProcessedRewards(ChildWalletState wallet) {
    if (_isShowingRewardDialog) return;

    for (final reward in wallet.pendingRewards) {
      if (reward.status == PendingRewardStatus.pending) continue;
      final rewardKey = '${reward.id}:${reward.status.name}';
      if (_sessionNotifiedRewardKeys.contains(rewardKey)) continue;

      _sessionNotifiedRewardKeys.add(rewardKey);

      if (reward.status == PendingRewardStatus.expired) {
        unawaited(_childRewardService.acknowledgeRewardResult(reward.id));
      } else {
        if (reward.status == PendingRewardStatus.approved &&
            reward.rewardType == 'task_completion') {
          unawaited(_loadTaskProgress(forceRemoteFetch: true));
        }
        _showRewardResultDialog(reward);
        // Break after one dialog to let it show; the stream will trigger again for the next one
        // once this one is acknowledged and removed from Firestore.
        break;
      }
    }
  }

  void _showRewardResultDialog(PendingReward reward) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _isShowingRewardDialog) return;

      setState(() => _isShowingRewardDialog = true);
      final isApproved = reward.status == PendingRewardStatus.approved;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => _RewardResultDialog(
          isApproved: isApproved,
          description: reward.description,
          onClose: () {
            if (context.mounted) Navigator.of(context).pop();
            unawaited(_childRewardService.acknowledgeRewardResult(reward.id));
            if (isApproved && reward.rewardType == 'task_completion') {
              unawaited(_loadTaskProgress(forceRemoteFetch: true));
            }
          },
        ),
      );

      if (mounted) {
        setState(() => _isShowingRewardDialog = false);
        // After closing one, check if there are others in the wallet
        if (_walletState != null) {
          _checkProcessedRewards(_walletState!);
        }
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_loadCoinsBalance());
      unawaited(_loadBehaviorConfigState());
      unawaited(_loadTaskProgress(forceRemoteFetch: true));
      return;
    }

    _stopRewardListenerOrchestration(resetBackoff: false);
  }

  Future<void> _loadCoinsBalance() async {
    if (mounted) {
      setState(() {
        _isLoadingCoins = true;
        _walletState = null;
        _coinsBalance = null;
        _equippedOutfitAssetPath = null;
        _equippedAccessoryAssetPath = null;
      });
    }
    try {
      final wallet = await _childRewardService.getSelectedChildWallet();
      if (!mounted) {
        return;
      }

      setState(() {
        _walletState = wallet;
        _coinsBalance = wallet.coins;
        _isLoadingCoins = false;
        _equippedOutfitAssetPath = wallet.equippedOutfitAssetPath;
        _equippedAccessoryAssetPath = wallet.equippedAccessoryAssetPath;
        _pendingVerificationTaskIds = _pendingTaskIdsFromWallet(wallet);
      });
      _checkProcessedRewards(wallet);
      _showPendingLevelRewardIfNeeded(wallet);
      _syncRewardListenerForWallet(wallet, resetBackoff: true);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _walletState = null;
        _coinsBalance = null;
        _isLoadingCoins = false;
        _pendingVerificationTaskIds = <String>{};
      });
      _stopRewardListenerOrchestration(resetBackoff: false);
    }
  }

  Future<void> _ensureLevelStateInitialized(int plannedTaskCount) async {
    if (plannedTaskCount < 1) {
      return;
    }
    try {
      final wallet = await _childRewardService
          .ensureSelectedChildLevelInitialized(
            baseTargetTasks: plannedTaskCount,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _walletState = wallet;
        _coinsBalance = wallet.coins;
        _pendingVerificationTaskIds = _pendingTaskIdsFromWallet(wallet);
      });
      _showPendingLevelRewardIfNeeded(wallet);
    } catch (_) {
      // Non-blocking: the screen still works if level initialization fails.
    }
  }

  void _showPendingLevelRewardIfNeeded(ChildWalletState wallet) {
    final pendingLevel = wallet.levelState.nextPendingRewardLevel;
    if (!mounted || pendingLevel == null || _isLevelRewardDialogVisible) {
      return;
    }
    _isLevelRewardDialogVisible = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        _isLevelRewardDialogVisible = false;
        return;
      }

      final updatedWallet = await showDialog<ChildWalletState>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return _LevelRewardDialog(
            level: pendingLevel,
            onContinue: () async {
              return _childRewardService.claimSelectedChildLevelReward();
            },
          );
        },
      );

      if (!mounted) {
        return;
      }
      _isLevelRewardDialogVisible = false;
      if (updatedWallet != null) {
        setState(() {
          _walletState = updatedWallet;
          _coinsBalance = updatedWallet.coins;
        });
        if (updatedWallet.levelState.hasPendingReward) {
          _showPendingLevelRewardIfNeeded(updatedWallet);
        }
      }
    });
  }

  Future<void> _loadTaskProgress({bool forceRemoteFetch = false}) async {
    try {
      final progress = await _childTaskProgressService
          .getSelectedChildTaskProgress(forceRemoteFetch: forceRemoteFetch);
      if (!mounted) {
        return;
      }

      setState(() {
        _completedTaskIds = progress.completedTaskIds;
        _isLoadingTaskProgress = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoadingTaskProgress = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sleepStateTimer?.cancel();
    _stopRewardListenerOrchestration();
    super.dispose();
  }

  Future<void> _loadBehaviorConfigState() async {
    if (mounted) {
      setState(() => _isLoadingBehaviorConfig = true);
    }
    try {
      final childId = await _selectedChildService.getSelectedChildId();
      if (!mounted) {
        return;
      }

      if (childId == null || childId.isEmpty) {
        setState(() {
          _sleepRoutineConfigured = false;
          _sleepTimeMinutes = null;
          _isSleepOverlayVisible = false;
          _enabledBehaviorIds = <String>{};
          _waterCupsCount = 2;
          _waterReminderTimesMinutes = const <int>[10 * 60, 15 * 60];
          _sportSessionTimesMinutes = const <int>[8 * 60];
          _customBehaviors = const <CustomBehaviorConfig>[];
          _isLoadingBehaviorConfig = false;
        });
        return;
      }

      final config = await _childBehaviorService.getChildBehaviorConfig(
        childId: childId,
      );
      if (!mounted) {
        return;
      }

      final sleepTimeMinutes = (config.sleepHour * 60) + config.sleepMinute;
      final enabledBehaviorIds = config.selectedBehaviorIds.toSet();
      final plannedTaskSnapshot = _plannedTaskSnapshotForEnabledBehaviors(
        enabledBehaviorIds: enabledBehaviorIds,
        waterCupsCount: config.waterCupsCount,
        waterReminderTimesMinutes: config.waterReminderTimesMinutes,
        sportSessionTimesMinutes: config.sportSessionTimesMinutes,
        customBehaviors: config.customBehaviors,
      );
      final plannedTaskCount = plannedTaskSnapshot.length;
      final overlayVisible = _shouldShowSleepOverlay(
        now: DateTime.now(),
        sleepTimeMinutes: sleepTimeMinutes,
        configured: config.sleepRoutineConfigured,
        notificationsEnabled: config.sleepNotificationsEnabled,
      );

      setState(() {
        _sleepRoutineConfigured = config.sleepRoutineConfigured;
        _sleepNotificationsEnabled = config.sleepNotificationsEnabled;
        _sleepTimeMinutes = sleepTimeMinutes;
        _isSleepOverlayVisible = overlayVisible;
        _enabledBehaviorIds = enabledBehaviorIds;
        _waterCupsCount = config.waterCupsCount;
        _waterReminderTimesMinutes = List<int>.from(
          config.waterReminderTimesMinutes,
        );
        _sportSessionTimesMinutes = List<int>.from(
          config.sportSessionTimesMinutes,
        );
        _customBehaviors = List<CustomBehaviorConfig>.from(
          config.customBehaviors,
        );
        _isLoadingBehaviorConfig = false;
      });
      unawaited(
        _childTaskProgressService.updateSelectedChildDailyTaskPlan(
          totalTaskCount: plannedTaskCount,
          plannedTaskIds: plannedTaskSnapshot.keys.toSet(),
          plannedTaskTitlesById: plannedTaskSnapshot,
        ),
      );
      unawaited(
        _childBehaviorService.syncDeviceSleepLockForChild(childId: childId),
      );
      unawaited(_ensureLevelStateInitialized(plannedTaskCount));
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _enabledBehaviorIds = <String>{};
        _waterCupsCount = 2;
        _waterReminderTimesMinutes = const <int>[10 * 60, 15 * 60];
        _sportSessionTimesMinutes = const <int>[8 * 60];
        _customBehaviors = const <CustomBehaviorConfig>[];
        _isLoadingBehaviorConfig = false;
      });
      _refreshSleepOverlayState();
    }
  }

  void _refreshSleepOverlayState() {
    if (!mounted) {
      return;
    }

    final nextState = _shouldShowSleepOverlay(
      now: DateTime.now(),
      sleepTimeMinutes: _sleepTimeMinutes,
      configured: _sleepRoutineConfigured,
      notificationsEnabled: _sleepNotificationsEnabled,
    );
    if (nextState == _isSleepOverlayVisible) {
      return;
    }

    setState(() => _isSleepOverlayVisible = nextState);
  }

  bool _shouldShowSleepOverlay({
    required DateTime now,
    required int? sleepTimeMinutes,
    required bool configured,
    required bool notificationsEnabled,
  }) {
    if (FeatureFlags.disableSleepLockTemporarily) {
      return false;
    }

    if (!configured || !notificationsEnabled || sleepTimeMinutes == null) {
      return false;
    }

    if (sleepTimeMinutes == _morningUnlockMinutes) {
      return false;
    }

    final currentMinutes = (now.hour * 60) + now.minute;
    if (sleepTimeMinutes < _morningUnlockMinutes) {
      return currentMinutes >= sleepTimeMinutes &&
          currentMinutes < _morningUnlockMinutes;
    }

    return currentMinutes >= sleepTimeMinutes ||
        currentMinutes < _morningUnlockMinutes;
  }

  bool _isTaskCompleted(String? taskId) {
    if (taskId == null || taskId.isEmpty) {
      return false;
    }
    return _completedTaskIds.contains(taskId);
  }

  bool _isTaskPendingVerification(String? taskId) {
    final cleanTaskId = taskId?.trim() ?? '';
    if (cleanTaskId.isEmpty) {
      return false;
    }
    return _pendingVerificationTaskIds.contains(cleanTaskId);
  }

  String? _pendingVerificationBadgeText(String? taskId) {
    return _isTaskPendingVerification(taskId) ? 'يتم التحقق' : null;
  }

  _DailyCardData _setPendingVerificationBadge(_DailyCardData item) {
    final pendingMessage = _pendingVerificationBadgeText(item.taskId);
    if (pendingMessage == null) {
      return item;
    }

    return _DailyCardData(
      title: item.title,
      imagePath: item.imagePath,
      route: item.route,
      taskId: item.taskId,
      behaviorId: item.behaviorId,
      availableNow: item.availableNow,
      availabilityMessage: pendingMessage,
      availabilityHighlightsActivation: false,
      availabilityIsMissed: false,
    );
  }

  bool _isTaskCompletedForCardDisplay(String? taskId) {
    if (_keepDailyCardsEnabled) {
      return false;
    }
    return _isTaskCompleted(taskId);
  }

  bool _isBehaviorEnabled(String? behaviorId) {
    if (behaviorId == null || behaviorId.isEmpty) {
      return true;
    }
    return _enabledBehaviorIds.contains(behaviorId);
  }

  bool _isBehaviorEnabledInSet(
    Set<String> enabledBehaviorIds,
    String? behaviorId,
  ) {
    if (behaviorId == null || behaviorId.isEmpty) {
      return true;
    }
    return enabledBehaviorIds.contains(behaviorId);
  }

  Set<String> _plannedTaskIdsForEnabledBehaviors({
    required Set<String> enabledBehaviorIds,
    required int waterCupsCount,
    required List<int> waterReminderTimesMinutes,
    required List<int> sportSessionTimesMinutes,
    required List<CustomBehaviorConfig> customBehaviors,
  }) {
    return _plannedTaskSnapshotForEnabledBehaviors(
      enabledBehaviorIds: enabledBehaviorIds,
      waterCupsCount: waterCupsCount,
      waterReminderTimesMinutes: waterReminderTimesMinutes,
      sportSessionTimesMinutes: sportSessionTimesMinutes,
      customBehaviors: customBehaviors,
    ).keys.toSet();
  }

  Map<String, String> _plannedTaskSnapshotForEnabledBehaviors({
    required Set<String> enabledBehaviorIds,
    required int waterCupsCount,
    required List<int> waterReminderTimesMinutes,
    required List<int> sportSessionTimesMinutes,
    required List<CustomBehaviorConfig> customBehaviors,
  }) {
    final plannedTaskIds = <String, String>{};

    if (_isBehaviorEnabledInSet(enabledBehaviorIds, 'morning_athkar')) {
      plannedTaskIds[ChildTaskIds.quranReading] = 'أذكار الصباح والقراءة';
    }
    if (_isBehaviorEnabledInSet(enabledBehaviorIds, 'brush_teeth')) {
      plannedTaskIds[ChildTaskIds.brushTimeMorning] = 'تنظيف الأسنان صباحًا';
      plannedTaskIds[ChildTaskIds.brushTimeNight] = 'تنظيف الأسنان مساءً';
    }
    if (_isBehaviorEnabledInSet(enabledBehaviorIds, 'drink_water')) {
      final waterSlots = _normalizedWaterSlotMinutes(
        waterCupsCount: waterCupsCount,
        reminderTimesMinutes: waterReminderTimesMinutes,
      );
      for (var i = 0; i < waterSlots.length; i++) {
        plannedTaskIds[ChildTaskIds.waterDrinkSlot(i + 1)] =
            'شرب الماء ${i + 1}';
      }
    }
    if (_isBehaviorEnabledInSet(enabledBehaviorIds, 'solve_puzzle')) {
      plannedTaskIds[ChildTaskIds.shapeMatching] = 'تمرين التفكير';
    }
    if (_isBehaviorEnabledInSet(enabledBehaviorIds, 'sport_activity')) {
      final sportSlotsCount =
          (sportSessionTimesMinutes.isEmpty
                  ? 1
                  : sportSessionTimesMinutes.length)
              .clamp(1, ChildTaskIds.maxExerciseSlotsPerDay)
              .toInt();
      for (var i = 0; i < sportSlotsCount; i++) {
        plannedTaskIds[ChildTaskIds.exerciseSlot(i + 1)] =
            'النشاط الرياضي ${i + 1}';
      }
    }
    if (_isBehaviorEnabledInSet(enabledBehaviorIds, 'read_story')) {
      plannedTaskIds[ChildTaskIds.sleepStory] = 'قصة النوم';
    }
    for (final behavior in customBehaviors) {
      if (!_isBehaviorEnabledInSet(enabledBehaviorIds, behavior.id)) {
        continue;
      }
      final customSlots = _normalizedCustomReminderTimes(behavior);
      for (var i = 0; i < customSlots.length; i++) {
        plannedTaskIds[ChildTaskIds.customBehaviorSlot(behavior.id, i + 1)] =
            '${behavior.title} ${i + 1}';
      }
    }

    return plannedTaskIds;
  }

  int _currentMinutesOfDay() {
    final now = DateTime.now();
    return (now.hour * 60) + now.minute;
  }

  int _effectiveSleepTimeMinutes() {
    if (_sleepRoutineConfigured && _sleepTimeMinutes != null) {
      return _sleepTimeMinutes!;
    }
    return _defaultSleepTimeMinutes;
  }

  int _sleepPreparationStartMinutes() {
    return _sleepSectionStartMinutes;
  }

  bool _isWithinTimeWindow({
    required int currentMinutes,
    required int startMinutes,
    required int endMinutes,
  }) {
    if (startMinutes == endMinutes) {
      return true;
    }
    if (startMinutes < endMinutes) {
      return currentMinutes >= startMinutes && currentMinutes < endMinutes;
    }
    return currentMinutes >= startMinutes || currentMinutes < endMinutes;
  }

  bool _isWakeSectionAvailable(int currentMinutes) {
    return _isWithinTimeWindow(
      currentMinutes: currentMinutes,
      startMinutes: _morningUnlockMinutes,
      endMinutes: _wakeSectionEndMinutes,
    );
  }

  bool _isSleepSectionAvailable(int currentMinutes) {
    return _isWithinTimeWindow(
      currentMinutes: currentMinutes,
      startMinutes: _sleepPreparationStartMinutes(),
      endMinutes: _effectiveSleepTimeMinutes(),
    );
  }

  bool _isPuzzleSectionAvailable(int currentMinutes) {
    final sleepStart = _sleepPreparationStartMinutes();
    final endMinutes = sleepStart > _wakeSectionEndMinutes
        ? sleepStart
        : _defaultWaterWindowEndMinutes;
    return _isWithinTimeWindow(
      currentMinutes: currentMinutes,
      startMinutes: _wakeSectionEndMinutes,
      endMinutes: endMinutes,
    );
  }

  List<int> _defaultWaterSlotMinutes(int cupCount) {
    final safeCupCount = cupCount
        .clamp(1, ChildTaskIds.maxWaterSlotsPerDay)
        .toInt();
    final sleepStart = _sleepPreparationStartMinutes();
    var endMinutes = sleepStart > _defaultWaterWindowStartMinutes + 60
        ? sleepStart
        : _defaultWaterWindowEndMinutes;
    if (endMinutes <= _defaultWaterWindowStartMinutes) {
      endMinutes = _defaultWaterWindowEndMinutes;
    }

    final span = endMinutes - _defaultWaterWindowStartMinutes;
    if (span <= 0) {
      return <int>[_defaultWaterWindowStartMinutes];
    }

    final interval = span / (safeCupCount + 1);
    return List<int>.generate(safeCupCount, (index) {
      return (_defaultWaterWindowStartMinutes + (interval * (index + 1)))
          .round();
    });
  }

  List<int> _normalizedWaterSlotMinutes({
    required int waterCupsCount,
    required List<int> reminderTimesMinutes,
  }) {
    final cupCount = waterCupsCount
        .clamp(1, ChildTaskIds.maxWaterSlotsPerDay)
        .toInt();
    final cleaned = List<int>.from(reminderTimesMinutes)
      ..sort((a, b) => a.compareTo(b));
    if (cleaned.isEmpty) {
      return _defaultWaterSlotMinutes(cupCount);
    }
    return cleaned
        .take(cupCount)
        .map((minutes) => minutes.clamp(0, 1439).toInt())
        .toList(growable: false);
  }

  List<int> _derivedWaterSlotMinutes() {
    return _normalizedWaterSlotMinutes(
      waterCupsCount: _waterCupsCount,
      reminderTimesMinutes: _waterReminderTimesMinutes,
    );
  }

  List<int> _normalizedSportSlotMinutes() {
    final cleaned = List<int>.from(_sportSessionTimesMinutes)
      ..sort((a, b) => a.compareTo(b));
    if (cleaned.isEmpty) {
      return const <int>[8 * 60];
    }
    return cleaned
        .take(ChildTaskIds.maxExerciseSlotsPerDay)
        .map((minutes) => minutes.clamp(0, 1439).toInt())
        .toList(growable: false);
  }

  List<int> _normalizedCustomReminderTimes(CustomBehaviorConfig behavior) {
    final slotCount = behavior.repeatCount
        .clamp(1, ChildTaskIds.maxCustomBehaviorSlotsPerDay)
        .toInt();
    final cleaned = List<int>.from(behavior.reminderTimesMinutes)
      ..sort((a, b) => a.compareTo(b));
    if (cleaned.isEmpty) {
      return List<int>.generate(
        slotCount,
        (index) => ((8 * 60) + ((index + 1) * 60)) % Duration.minutesPerDay,
        growable: false,
      );
    }
    return cleaned
        .take(slotCount)
        .map((minutes) => minutes.clamp(0, 1439).toInt())
        .toList(growable: false);
  }

  bool _belongsToWakeSection(CustomBehaviorConfig behavior) {
    return behavior.periods.contains('عند الاستيقاظ');
  }

  bool _belongsToSleepSection(CustomBehaviorConfig behavior) {
    return behavior.periods.contains('قبل النوم');
  }

  bool _belongsToPlaySection(CustomBehaviorConfig behavior) {
    return behavior.periods.isEmpty ||
        behavior.periods.contains('خلال اليوم') ||
        (!_belongsToWakeSection(behavior) && !_belongsToSleepSection(behavior));
  }

  String _customBehaviorRoute({required String title, required String taskId}) {
    return Uri(
      path: '/child-home/custom-behavior',
      queryParameters: <String, String>{'task': taskId, 'title': title},
    ).toString();
  }

  _DailyCardData _buildCustomBehaviorCard({
    required DateTime now,
    required CustomBehaviorConfig behavior,
  }) {
    final availability = _resolvedScheduledTaskAvailability(
      now: now,
      slotMinutes: _normalizedCustomReminderTimes(behavior),
      taskIdBuilder: (slotNumber) =>
          ChildTaskIds.customBehaviorSlot(behavior.id, slotNumber),
    );
    final routeTaskId = _resolveCardTaskId(
      currentTaskId: availability.taskId,
      fallbackTaskId: ChildTaskIds.customBehaviorSlot(behavior.id, 1),
    );
    return _DailyCardData(
      title: behavior.title,
      imagePath: 'assets/risha/risha_normal.png',
      route: routeTaskId == null
          ? null
          : _customBehaviorRoute(title: behavior.title, taskId: routeTaskId),
      taskId: routeTaskId,
      behaviorId: behavior.id,
      availableNow: availability.availableNow,
      availabilityMessage: availability.badgeText,
      availabilityHighlightsActivation: availability.badgeHighlightsActivation,
      availabilityIsMissed: availability.badgeIsMissed,
    );
  }

  String _routeWithTask(String baseRoute, String taskId) {
    return Uri(
      path: baseRoute,
      queryParameters: <String, String>{'task': taskId},
    ).toString();
  }

  ChildLevelState _effectiveLevelStateForDisplay(int plannedTaskCount) {
    final fallbackTarget = plannedTaskCount < 1 ? 1 : plannedTaskCount;
    final walletState = _walletState;
    if (walletState == null) {
      return ChildLevelState.defaults(targetTasks: fallbackTarget);
    }

    final levelState = walletState.levelState;
    final shouldRebase =
        levelState.level == 0 &&
        levelState.progressTasks == 0 &&
        !levelState.hasPendingReward &&
        levelState.targetTasks == 1 &&
        fallbackTarget != 1;
    if (shouldRebase) {
      return ChildLevelState.defaults(targetTasks: fallbackTarget);
    }
    return levelState.targetTasks < 1
        ? levelState.copyWith(targetTasks: fallbackTarget)
        : levelState;
  }

  String _formatClockLabel(int minutes) {
    final normalizedMinutes =
        ((minutes % Duration.minutesPerDay) + Duration.minutesPerDay) %
        Duration.minutesPerDay;
    final hour = normalizedMinutes ~/ 60;
    final minute = normalizedMinutes % 60;
    final period = hour >= 12 ? 'م' : 'ص';
    final hour12 = hour % 12 == 0 ? 12 : hour % 12;
    return '$hour12:${minute.toString().padLeft(2, '0')} $period';
  }

  DateTime _nextDateTimeForMinutes(DateTime now, int minutes) {
    final normalizedMinutes =
        ((minutes % Duration.minutesPerDay) + Duration.minutesPerDay) %
        Duration.minutesPerDay;
    final candidate = DateTime(
      now.year,
      now.month,
      now.day,
      normalizedMinutes ~/ 60,
      normalizedMinutes % 60,
    );
    if (candidate.isAfter(now)) {
      return candidate;
    }
    return candidate.add(const Duration(days: 1));
  }

  String _formatCountdown(Duration duration) {
    final totalMinutes = duration.inMinutes;
    if (totalMinutes <= 0) {
      return 'أقل من دقيقة';
    }
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (hours <= 0) {
      return '$minutes دقيقة';
    }
    if (minutes == 0) {
      return hours == 1 ? 'ساعة واحدة' : '$hours ساعات';
    }
    if (hours == 1) {
      return 'ساعة و$minutes دقيقة';
    }
    return '$hours ساعة و$minutes دقيقة';
  }

  String _buildActivationBadgeText({
    required DateTime now,
    required DateTime target,
    required bool reactivating,
  }) {
    final remaining = target.difference(now);
    if (remaining.inMinutes <= 90) {
      return '${reactivating ? 'يتفعل من جديد بعد ' : 'يتفعل بعد '}${_formatCountdown(remaining)}';
    }

    final today = DateTime(now.year, now.month, now.day);
    final targetDay = DateTime(target.year, target.month, target.day);
    final isTomorrow = targetDay.difference(today).inDays == 1;
    final prefix = reactivating
        ? (isTomorrow ? 'يتفعل من جديد غدًا ' : 'يتفعل من جديد ')
        : (isTomorrow ? 'يتفعل غدًا ' : 'يتفعل ');
    return '$prefix${_formatClockLabel(target.hour * 60 + target.minute)}';
  }

  String _buildReopenBadgeText(int minutes) {
    return 'إعادة فتح ${_formatClockLabel(minutes)}';
  }

  int _countCompletedScheduledSlots({
    required int totalSlots,
    required String Function(int slotNumber) taskIdBuilder,
  }) {
    var completedCount = 0;
    for (var i = 0; i < totalSlots; i++) {
      if (_isTaskCompleted(taskIdBuilder(i + 1))) {
        completedCount++;
      }
    }
    return completedCount;
  }

  String _windowAvailabilityBadgeText({
    required DateTime now,
    required int startMinutes,
  }) {
    final target = _nextDateTimeForMinutes(now, startMinutes);
    return _buildActivationBadgeText(
      now: now,
      target: target,
      reactivating: false,
    );
  }

  _ScheduledTaskAvailabilityState _fixedWindowTaskAvailability({
    required DateTime now,
    required int currentMinutes,
    required int startMinutes,
    required int endMinutes,
  }) {
    final availableNow = _isWithinTimeWindow(
      currentMinutes: currentMinutes,
      startMinutes: startMinutes,
      endMinutes: endMinutes,
    );
    if (availableNow) {
      return const _ScheduledTaskAvailabilityState(availableNow: true);
    }

    if (currentMinutes < startMinutes) {
      return _ScheduledTaskAvailabilityState(
        availableNow: false,
        badgeText: _windowAvailabilityBadgeText(
          now: now,
          startMinutes: startMinutes,
        ),
        badgeHighlightsActivation: true,
      );
    }

    return const _ScheduledTaskAvailabilityState(
      availableNow: false,
      badgeText: 'تم تفويت هذا السلوك',
      badgeIsMissed: true,
    );
  }

  // ignore: unused_element
  _ScheduledTaskAvailabilityState _scheduledTaskAvailability({
    required DateTime now,
    required List<int> slotMinutes,
    required String Function(int slotNumber) taskIdBuilder,
  }) {
    final currentMinutes = (now.hour * 60) + now.minute;
    final sortedSlots = List<int>.from(slotMinutes)
      ..sort((a, b) => a.compareTo(b));
    var hadCompletedEarlierSlot = false;

    for (var i = 0; i < sortedSlots.length; i++) {
      final taskId = taskIdBuilder(i + 1);
      final slotMinute = sortedSlots[i];
      final completed = _isTaskCompleted(taskId);
      if (slotMinute <= currentMinutes) {
        if (!completed) {
          return _ScheduledTaskAvailabilityState(
            taskId: taskId,
            availableNow: true,
          );
        }
        hadCompletedEarlierSlot = true;
        continue;
      }

      return _ScheduledTaskAvailabilityState(
        taskId: taskId,
        availableNow: false,
        badgeText: _buildReopenBadgeText(slotMinute),
        badgeHighlightsActivation: true,
      );
    }

    if (hadCompletedEarlierSlot) {
      return const _ScheduledTaskAvailabilityState(
        availableNow: false,
        badgeText: 'اكتمل لليوم',
      );
    }

    return const _ScheduledTaskAvailabilityState(
      availableNow: false,
      badgeText: 'غير مفعل الآن',
    );
  }

  _ScheduledTaskAvailabilityState _resolvedScheduledTaskAvailability({
    required DateTime now,
    required List<int> slotMinutes,
    required String Function(int slotNumber) taskIdBuilder,
  }) {
    final currentMinutes = (now.hour * 60) + now.minute;
    final sortedSlots = List<int>.from(slotMinutes)
      ..sort((a, b) => a.compareTo(b));
    var hadCompletedEarlierSlot = false;

    for (var i = 0; i < sortedSlots.length; i++) {
      final taskId = taskIdBuilder(i + 1);
      final slotMinute = sortedSlots[i];
      final completed = _isTaskCompleted(taskId);
      if (slotMinute <= currentMinutes) {
        if (!completed) {
          return _ScheduledTaskAvailabilityState(
            taskId: taskId,
            availableNow: true,
          );
        }
        hadCompletedEarlierSlot = true;
        continue;
      }

      return _ScheduledTaskAvailabilityState(
        taskId: taskId,
        availableNow: false,
        badgeText: _buildReopenBadgeText(slotMinute),
        badgeHighlightsActivation: true,
      );
    }

    if (hadCompletedEarlierSlot && sortedSlots.isNotEmpty) {
      return const _ScheduledTaskAvailabilityState(
        availableNow: false,
        badgeText: 'تم الإنجاز لليوم',
      );
    }

    return const _ScheduledTaskAvailabilityState(
      availableNow: false,
      badgeText: 'غير مفعل الآن',
    );
  }

  _ScheduledTaskAvailabilityState _waterTaskAvailability(DateTime now) {
    final slotMinutes = _derivedWaterSlotMinutes();
    final totalCount = slotMinutes.length;
    final completedCount = _countCompletedScheduledSlots(
      totalSlots: totalCount,
      taskIdBuilder: ChildTaskIds.waterDrinkSlot,
    );
    final resolvedState = _resolvedScheduledTaskAvailability(
      now: now,
      slotMinutes: slotMinutes,
      taskIdBuilder: ChildTaskIds.waterDrinkSlot,
    );

    if (totalCount <= 0) {
      return const _ScheduledTaskAvailabilityState(
        availableNow: false,
        badgeText: 'غير مفعل الآن',
      );
    }

    if (completedCount >= totalCount) {
      return const _ScheduledTaskAvailabilityState(
        availableNow: false,
        badgeText: 'تم الإنجاز لليوم',
      );
    }

    return _ScheduledTaskAvailabilityState(
      taskId: resolvedState.taskId,
      availableNow: resolvedState.availableNow,
      badgeText: '$completedCount/$totalCount',
    );
  }

  // ignore: unused_element
  Set<String> _visibleTaskIdsForEnabledBehaviors(
    Set<String> enabledBehaviorIds,
  ) {
    final visibleItems = <_DailyCardData>[
      const _DailyCardData(
        title: 'صباح جميل',
        imagePath: 'assets/risha/risha_reading.png',
        route: '/child-home/quran-reading',
        taskId: ChildTaskIds.quranReading,
        behaviorId: 'morning_athkar',
      ),
      const _DailyCardData(
        title: 'ابتسامة لامعة',
        imagePath: 'assets/risha/risha_brushing.png',
        route: '/child-home/brush-time',
        taskId: ChildTaskIds.brushTime,
        behaviorId: 'brush_teeth',
      ),
      const _DailyCardData(
        title: 'وقت كوب الماء',
        imagePath: 'assets/risha/risha_drink.png',
        route: '/child-home/water-drink',
        taskId: ChildTaskIds.waterDrink,
        behaviorId: 'drink_water',
      ),
      const _DailyCardData(
        title: 'ريشة تفكر',
        imagePath: 'assets/risha/risha_thinking.png',
        route: '/child-home/shape-matching',
        taskId: ChildTaskIds.shapeMatching,
        behaviorId: 'solve_puzzle',
      ),
      const _DailyCardData(
        title: 'رفرفة صغيرة',
        imagePath: 'assets/risha/risha_athlete.png',
        route: '/child-home/exercising',
        taskId: ChildTaskIds.exercising,
        behaviorId: 'sport_activity',
      ),
      const _DailyCardData(
        title: 'قصة النوم',
        imagePath: 'assets/risha/risha_read_blue_book.png',
        route: '/child-home/sleep-story',
        taskId: ChildTaskIds.sleepStory,
        behaviorId: 'read_story',
      ),
      const _DailyCardData(
        title: 'ابتسامة دافئة',
        imagePath: 'assets/risha/risha_brushing.png',
        route: '/child-home/brush-time',
        taskId: ChildTaskIds.brushTime,
        behaviorId: 'brush_teeth',
      ),
    ];

    return visibleItems
        .where(
          (item) =>
              _isBehaviorEnabledInSet(enabledBehaviorIds, item.behaviorId),
        )
        .map((item) => item.taskId)
        .whereType<String>()
        .where((taskId) => taskId.trim().isNotEmpty)
        .toSet();
  }

  // ignore: unused_element
  double _calculateVisibleProgress(List<_DailyCardData> items) {
    final visibleTaskIds = items
        .map((item) => item.taskId)
        .whereType<String>()
        .where((taskId) => taskId.trim().isNotEmpty)
        .toSet();
    if (visibleTaskIds.isEmpty) {
      return 0;
    }

    final completedVisibleTasks = visibleTaskIds
        .where(_completedTaskIds.contains)
        .length;
    return completedVisibleTasks / visibleTaskIds.length;
  }

  String? _resolveCardTaskId({
    required String? currentTaskId,
    required String fallbackTaskId,
  }) {
    if (currentTaskId != null && currentTaskId.trim().isNotEmpty) {
      return currentTaskId;
    }
    if (_keepDailyCardsEnabled) {
      return fallbackTaskId;
    }
    return null;
  }

  _DailyCardData _applyCardAvailabilityOverride(_DailyCardData item) {
    if (!_keepDailyCardsEnabled) {
      return item;
    }

    return _DailyCardData(
      title: item.title,
      imagePath: item.imagePath,
      route: item.route,
      taskId: item.taskId,
      behaviorId: item.behaviorId,
      availableNow: item.route != null,
      availabilityMessage: null,
      availabilityHighlightsActivation: false,
      availabilityIsMissed: false,
    );
  }

  List<_DailyCardData> _applyCardAvailabilityOverrides(
    List<_DailyCardData> items,
  ) {
    if (!_keepDailyCardsEnabled) {
      return items;
    }
    return items.map(_applyCardAvailabilityOverride).toList(growable: false);
  }

  VoidCallback? _buildTaskTapHandler(_DailyCardData item) {
    if (item.route == null) {
      return null;
    }
    if (_isTaskPendingVerification(item.taskId)) {
      return null;
    }
    if (!_keepDailyCardsEnabled &&
        (_isLoadingTaskProgress ||
            _isTaskCompleted(item.taskId) ||
            !item.availableNow)) {
      return null;
    }
    return () => context.go(item.route!);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final currentMinutes = _currentMinutesOfDay();
    final wakeSectionAvailable = _isWakeSectionAvailable(currentMinutes);
    final sleepSectionAvailable = _isSleepSectionAvailable(currentMinutes);
    final puzzleAvailable = _isPuzzleSectionAvailable(currentMinutes);
    final wakeSectionStatus = _fixedWindowTaskAvailability(
      now: now,
      currentMinutes: currentMinutes,
      startMinutes: _morningUnlockMinutes,
      endMinutes: _wakeSectionEndMinutes,
    );
    final puzzleSectionStatus = _fixedWindowTaskAvailability(
      now: now,
      currentMinutes: currentMinutes,
      startMinutes: _wakeSectionEndMinutes,
      endMinutes: _sleepPreparationStartMinutes(),
    );
    final sleepSectionStatus = _fixedWindowTaskAvailability(
      now: now,
      currentMinutes: currentMinutes,
      startMinutes: _sleepPreparationStartMinutes(),
      endMinutes: _effectiveSleepTimeMinutes(),
    );
    final plannedTaskIds = _plannedTaskIdsForEnabledBehaviors(
      enabledBehaviorIds: _enabledBehaviorIds,
      waterCupsCount: _waterCupsCount,
      waterReminderTimesMinutes: _waterReminderTimesMinutes,
      sportSessionTimesMinutes: _sportSessionTimesMinutes,
      customBehaviors: _customBehaviors,
    );
    final waterAvailability = _waterTaskAvailability(now);
    final sportAvailability = _resolvedScheduledTaskAvailability(
      now: now,
      slotMinutes: _normalizedSportSlotMinutes(),
      taskIdBuilder: ChildTaskIds.exerciseSlot,
    );
    final waterTaskId = _resolveCardTaskId(
      currentTaskId: waterAvailability.taskId,
      fallbackTaskId: ChildTaskIds.waterDrinkSlot(1),
    );
    final sportTaskId = _resolveCardTaskId(
      currentTaskId: sportAvailability.taskId,
      fallbackTaskId: ChildTaskIds.exerciseSlot(1),
    );
    final levelState = _effectiveLevelStateForDisplay(plannedTaskIds.length);
    final enabledCustomBehaviors = _customBehaviors
        .where((behavior) => _isBehaviorEnabled(behavior.id))
        .toList(growable: false);
    final customWakeItems = enabledCustomBehaviors
        .where(_belongsToWakeSection)
        .map(
          (behavior) => _buildCustomBehaviorCard(now: now, behavior: behavior),
        )
        .toList(growable: false);
    final customPlayItems = enabledCustomBehaviors
        .where(_belongsToPlaySection)
        .map(
          (behavior) => _buildCustomBehaviorCard(now: now, behavior: behavior),
        )
        .toList(growable: false);
    final customSleepItems = enabledCustomBehaviors
        .where(_belongsToSleepSection)
        .map(
          (behavior) => _buildCustomBehaviorCard(now: now, behavior: behavior),
        )
        .toList(growable: false);
    final rawWakeUpItems =
        <_DailyCardData>[
              const _DailyCardData(
                title: 'صباح جميل',
                imagePath: 'assets/risha/risha_reading.png',
                route: '/child-home/quran-reading',
                taskId: ChildTaskIds.quranReading,
                behaviorId: 'morning_athkar',
              ),
              const _DailyCardData(
                title: 'ابتسامة لامعة',
                imagePath: 'assets/risha/risha_brushing.png',
                route: '/child-home/brush-time',
                taskId: ChildTaskIds.brushTime,
                behaviorId: 'brush_teeth',
              ),
            ]
            .where((item) => _isBehaviorEnabled(item.behaviorId))
            .toList(growable: false);

    final rawPlayItems =
        <_DailyCardData>[
              const _DailyCardData(
                title: 'وقت كوب الماء',
                imagePath: 'assets/risha/risha_drink.png',
                route: '/child-home/water-drink',
                taskId: ChildTaskIds.waterDrink,
                behaviorId: 'drink_water',
              ),
              const _DailyCardData(
                title: 'ريشة تفكر',
                imagePath: 'assets/risha/risha_thinking.png',
                route: '/child-home/shape-matching',
                taskId: ChildTaskIds.shapeMatching,
                behaviorId: 'solve_puzzle',
              ),
              const _DailyCardData(
                title: 'رفرفة صغيرة',
                imagePath: 'assets/risha/risha_athlete.png',
                route: '/child-home/exercising',
                taskId: ChildTaskIds.exercising,
                behaviorId: 'sport_activity',
              ),
            ]
            .where((item) => _isBehaviorEnabled(item.behaviorId))
            .toList(growable: false);

    final rawSleepItems =
        <_DailyCardData>[
              const _DailyCardData(
                title: 'قصة النوم',
                imagePath: 'assets/risha/risha_read_blue_book.png',
                route: '/child-home/sleep-story',
                taskId: ChildTaskIds.sleepStory,
                behaviorId: 'read_story',
              ),
              const _DailyCardData(
                title: 'ابتسامة دافئة',
                imagePath: 'assets/risha/risha_brushing.png',
                route: '/child-home/brush-time',
                taskId: ChildTaskIds.brushTime,
                behaviorId: 'brush_teeth',
              ),
            ]
            .where((item) => _isBehaviorEnabled(item.behaviorId))
            .toList(growable: false);
    final wakeUpItems = <_DailyCardData>[
      if (rawWakeUpItems.isNotEmpty)
        _DailyCardData(
          title: rawWakeUpItems[0].title,
          imagePath: rawWakeUpItems[0].imagePath,
          route: rawWakeUpItems[0].route,
          taskId: ChildTaskIds.quranReading,
          behaviorId: rawWakeUpItems[0].behaviorId,
          availableNow: wakeSectionAvailable,
        ),
      if (rawWakeUpItems.length > 1)
        _DailyCardData(
          title: rawWakeUpItems[1].title,
          imagePath: rawWakeUpItems[1].imagePath,
          route: _routeWithTask(
            '/child-home/brush-time',
            ChildTaskIds.brushTimeMorning,
          ),
          taskId: ChildTaskIds.brushTimeMorning,
          behaviorId: rawWakeUpItems[1].behaviorId,
          availableNow: wakeSectionAvailable,
        ),
    ];
    final playItems = <_DailyCardData>[
      if (rawPlayItems.isNotEmpty)
        _DailyCardData(
          title: rawPlayItems[0].title,
          imagePath: rawPlayItems[0].imagePath,
          route: waterTaskId == null
              ? null
              : _routeWithTask('/child-home/water-drink', waterTaskId),
          taskId: waterTaskId,
          behaviorId: rawPlayItems[0].behaviorId,
          availableNow: waterTaskId != null,
        ),
      if (rawPlayItems.length > 1)
        _DailyCardData(
          title: rawPlayItems[1].title,
          imagePath: rawPlayItems[1].imagePath,
          route: rawPlayItems[1].route,
          taskId: ChildTaskIds.shapeMatching,
          behaviorId: rawPlayItems[1].behaviorId,
          availableNow: puzzleAvailable,
        ),
      if (rawPlayItems.length > 2)
        _DailyCardData(
          title: rawPlayItems[2].title,
          imagePath: rawPlayItems[2].imagePath,
          route: sportTaskId == null
              ? null
              : _routeWithTask('/child-home/exercising', sportTaskId),
          taskId: sportTaskId,
          behaviorId: rawPlayItems[2].behaviorId,
          availableNow: sportTaskId != null,
        ),
    ];
    final sleepItems = <_DailyCardData>[
      if (rawSleepItems.isNotEmpty)
        _DailyCardData(
          title: rawSleepItems[0].title,
          imagePath: rawSleepItems[0].imagePath,
          route: rawSleepItems[0].route,
          taskId: ChildTaskIds.sleepStory,
          behaviorId: rawSleepItems[0].behaviorId,
          availableNow: sleepSectionAvailable,
        ),
      if (rawSleepItems.length > 1)
        _DailyCardData(
          title: rawSleepItems[1].title,
          imagePath: rawSleepItems[1].imagePath,
          route: _routeWithTask(
            '/child-home/brush-time',
            ChildTaskIds.brushTimeNight,
          ),
          taskId: ChildTaskIds.brushTimeNight,
          behaviorId: rawSleepItems[1].behaviorId,
          availableNow: sleepSectionAvailable,
        ),
    ];
    final effectiveWakeUpItems =
        _applyCardAvailabilityOverrides(<_DailyCardData>[
          if (_isBehaviorEnabled('morning_athkar'))
            _DailyCardData(
              title: 'صباح جميل',
              imagePath: 'assets/risha/risha_reading.png',
              route: '/child-home/quran-reading',
              taskId: ChildTaskIds.quranReading,
              behaviorId: 'morning_athkar',
              availableNow: wakeSectionAvailable,
              availabilityMessage: wakeSectionStatus.badgeText,
              availabilityHighlightsActivation:
                  wakeSectionStatus.badgeHighlightsActivation,
              availabilityIsMissed: wakeSectionStatus.badgeIsMissed,
            ),
          if (_isBehaviorEnabled('brush_teeth'))
            _DailyCardData(
              title: 'ابتسامة لامعة',
              imagePath: 'assets/risha/risha_brushing.png',
              route: _routeWithTask(
                '/child-home/brush-time',
                ChildTaskIds.brushTimeMorning,
              ),
              taskId: ChildTaskIds.brushTimeMorning,
              behaviorId: 'brush_teeth',
              availableNow: wakeSectionAvailable,
              availabilityMessage: wakeSectionStatus.badgeText,
              availabilityHighlightsActivation:
                  wakeSectionStatus.badgeHighlightsActivation,
              availabilityIsMissed: wakeSectionStatus.badgeIsMissed,
            ),
          ...customWakeItems,
        ]).map(_setPendingVerificationBadge).toList(growable: false);
    final effectivePlayItems = _applyCardAvailabilityOverrides(<_DailyCardData>[
      if (_isBehaviorEnabled('drink_water'))
        _DailyCardData(
          title: 'وقت كوب الماء',
          imagePath: 'assets/risha/risha_drink.png',
          route: waterTaskId == null
              ? null
              : _routeWithTask('/child-home/water-drink', waterTaskId),
          taskId: waterTaskId,
          behaviorId: 'drink_water',
          availableNow: waterAvailability.availableNow,
          availabilityMessage: waterAvailability.badgeText,
          availabilityHighlightsActivation:
              waterAvailability.badgeHighlightsActivation,
          availabilityIsMissed: waterAvailability.badgeIsMissed,
        ),
      if (_isBehaviorEnabled('solve_puzzle'))
        _DailyCardData(
          title: 'ريشة تفكر',
          imagePath: 'assets/risha/risha_thinking.png',
          route: '/child-home/shape-matching',
          taskId: ChildTaskIds.shapeMatching,
          behaviorId: 'solve_puzzle',
          availableNow: puzzleAvailable,
          availabilityMessage: puzzleSectionStatus.badgeText,
          availabilityHighlightsActivation:
              puzzleSectionStatus.badgeHighlightsActivation,
          availabilityIsMissed: puzzleSectionStatus.badgeIsMissed,
        ),
      if (_isBehaviorEnabled('sport_activity'))
        _DailyCardData(
          title: 'رفرفة صغيرة',
          imagePath: 'assets/risha/risha_athlete.png',
          route: sportTaskId == null
              ? null
              : _routeWithTask('/child-home/exercising', sportTaskId),
          taskId: sportTaskId,
          behaviorId: 'sport_activity',
          availableNow: sportAvailability.availableNow,
          availabilityMessage: sportAvailability.badgeText,
          availabilityHighlightsActivation:
              sportAvailability.badgeHighlightsActivation,
          availabilityIsMissed: sportAvailability.badgeIsMissed,
        ),
      ...customPlayItems,
    ]).map(_setPendingVerificationBadge).toList(growable: false);
    final effectiveSleepItems =
        _applyCardAvailabilityOverrides(<_DailyCardData>[
          if (_isBehaviorEnabled('read_story'))
            _DailyCardData(
              title: 'قصة النوم',
              imagePath: 'assets/risha/risha_read_blue_book.png',
              route: '/child-home/sleep-story',
              taskId: ChildTaskIds.sleepStory,
              behaviorId: 'read_story',
              availableNow: sleepSectionAvailable,
              availabilityMessage: sleepSectionStatus.badgeText,
              availabilityHighlightsActivation:
                  sleepSectionStatus.badgeHighlightsActivation,
              availabilityIsMissed: sleepSectionStatus.badgeIsMissed,
            ),
          if (_isBehaviorEnabled('brush_teeth'))
            _DailyCardData(
              title: 'ابتسامة دافئة',
              imagePath: 'assets/risha/risha_brushing.png',
              route: _routeWithTask(
                '/child-home/brush-time',
                ChildTaskIds.brushTimeNight,
              ),
              taskId: ChildTaskIds.brushTimeNight,
              behaviorId: 'brush_teeth',
              availableNow: sleepSectionAvailable,
              availabilityMessage: sleepSectionStatus.badgeText,
              availabilityHighlightsActivation:
                  sleepSectionStatus.badgeHighlightsActivation,
              availabilityIsMissed: sleepSectionStatus.badgeIsMissed,
            ),
          ...customSleepItems,
        ]).map(_setPendingVerificationBadge).toList(growable: false);
    assert(() {
      return rawWakeUpItems.length +
              rawPlayItems.length +
              rawSleepItems.length +
              wakeUpItems.length +
              playItems.length +
              sleepItems.length >=
          0;
    }());
    final isProgressLoading =
        _isLoadingBehaviorConfig || _isLoadingTaskProgress;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || _showSleepOverlay) {
          return;
        }
        context.go('/child-home/profiles');
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFEBCF99),
        body: SafeArea(
          child: Stack(
            children: [
              IgnorePointer(
                ignoring: _showSleepOverlay,
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            _TopSkySection(
                              coins: _coinsBalance,
                              isLoadingCoins: _isLoadingCoins,
                              level: levelState.level,
                              outfitAssetPath: _equippedOutfitAssetPath,
                              accessoryAssetPath: _equippedAccessoryAssetPath,
                            ),

                            Transform.translate(
                              offset: const Offset(0, -14),
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: _WakeupCard(
                                  levelState: levelState,
                                  completedTasks: levelState.progressTasks,
                                  totalTasks: levelState.targetTasks,
                                  isLoading: isProgressLoading,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
                              child: Column(
                                children: [
                                  if (_isLoadingBehaviorConfig)
                                    const Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 28,
                                      ),
                                      child: CircularProgressIndicator(),
                                    )
                                  else ...[
                                    if (effectiveWakeUpItems.isNotEmpty) ...[
                                      const _GroupTitle(
                                        title: 'وقت الاستيقاظ',
                                        iconPath: 'assets/icons/sun_icon.png',
                                      ),
                                      const SizedBox(height: 8),
                                      for (
                                        var i = 0;
                                        i < effectiveWakeUpItems.length;
                                        i++
                                      ) ...[
                                        _DailyTaskCard(
                                          data: effectiveWakeUpItems[i],
                                          completed:
                                              _isTaskCompletedForCardDisplay(
                                                effectiveWakeUpItems[i].taskId,
                                              ),
                                          onTap: _buildTaskTapHandler(
                                            effectiveWakeUpItems[i],
                                          ),
                                        ),
                                        if (i < effectiveWakeUpItems.length - 1)
                                          const SizedBox(height: 8),
                                      ],
                                      const SizedBox(height: 12),
                                    ],
                                    if (effectivePlayItems.isNotEmpty) ...[
                                      const _GroupTitle(
                                        iconPath: 'assets/icons/have_fun.png',
                                        title: 'لنمرح معًا',
                                      ),
                                      const SizedBox(height: 8),
                                      for (
                                        var i = 0;
                                        i < effectivePlayItems.length;
                                        i++
                                      ) ...[
                                        _DailyTaskCard(
                                          data: effectivePlayItems[i],
                                          completed:
                                              _isTaskCompletedForCardDisplay(
                                                effectivePlayItems[i].taskId,
                                              ),
                                          onTap: _buildTaskTapHandler(
                                            effectivePlayItems[i],
                                          ),
                                        ),
                                        if (i < effectivePlayItems.length - 1)
                                          const SizedBox(height: 8),
                                      ],
                                      const SizedBox(height: 12),
                                    ],
                                    if (effectiveSleepItems.isNotEmpty) ...[
                                      const _GroupTitle(
                                        iconPath:
                                            'assets/icons/ready_to_sleep.png',
                                        title: 'الاستعداد للنوم',
                                      ),
                                      const SizedBox(height: 8),
                                      for (
                                        var i = 0;
                                        i < effectiveSleepItems.length;
                                        i++
                                      ) ...[
                                        _DailyTaskCard(
                                          data: effectiveSleepItems[i],
                                          completed:
                                              _isTaskCompletedForCardDisplay(
                                                effectiveSleepItems[i].taskId,
                                              ),
                                          onTap: _buildTaskTapHandler(
                                            effectiveSleepItems[i],
                                          ),
                                        ),
                                        if (i < effectiveSleepItems.length - 1)
                                          const SizedBox(height: 8),
                                      ],
                                    ],
                                    if (effectiveWakeUpItems.isEmpty &&
                                        effectivePlayItems.isEmpty &&
                                        effectiveSleepItems.isEmpty)
                                      const Padding(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 28,
                                        ),
                                        child: Text(
                                          'لا توجد سلوكيات مفعلة لهذا الطفل حالياً.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Color(0xFF7C6A58),
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const _BottomMenuBar(),
                  ],
                ),
              ),
              if (_showSleepOverlay)
                const Positioned.fill(child: _SleepOverlay()),
            ],
          ),
        ),
      ),
    );
  }
}

class _SleepOverlay extends StatelessWidget {
  const _SleepOverlay();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xB6EBE0C4),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Container(
            width: 300,
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 18),
            decoration: BoxDecoration(
              color: const Color(0xFFF8EFD9),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/risha/risha_sleep.png',
                  width: 235,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 12),
                const Text(
                  'حان وقت نومك..',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF3D3025),
                    fontSize: 27,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'سنعود للمرح مجددًا مع الصباح',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF8F7C61),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopSkySection extends StatelessWidget {
  const _TopSkySection({
    required this.coins,
    required this.isLoadingCoins,
    required this.level,
    required this.outfitAssetPath,
    required this.accessoryAssetPath,
  });

  final int? coins;
  final bool isLoadingCoins;
  final int level;
  final String? outfitAssetPath;
  final String? accessoryAssetPath;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 248,
      width: double.infinity,
      child: Stack(
        children: [
          // الخلفية (نفسها)
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/wallpapers/desert_wallpaper.png'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          // شارة المستوى والعملات (نفسها)
          Positioned(
            top: 8,
            left: 8,
            right: 8,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _LevelBadge(level: level),
                _CoinsBadge(value: coins, isLoading: isLoadingCoins),
              ],
            ),
          ),
          // الشخصية - استبدلنا Image.asset بـ ChildMascotAvatar
          Positioned(
            left: 0,
            right: 0,
            bottom: 10,
            child: Center(
              child: ChildMascotAvatar(
                poseAssetPath: 'assets/risha/risha_normal.png',
                width: 140,
                height: 140,
                scale: 0.82,
                alignment: const Alignment(0, 0.22),
                outfitAssetPath: outfitAssetPath,
                accessoryAssetPath: accessoryAssetPath,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoinsBadge extends StatelessWidget {
  const _CoinsBadge({required this.value, required this.isLoading});

  final int? value;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF8E6C3),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: const Color(0xFFE4CAA0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/icons/palm_icon.png',
            width: 12,
            height: 12,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 4),
          if (isLoading)
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.8,
                color: Color(0xFF3F2F1D),
              ),
            )
          else
            Text(
              value?.toString() ?? '--',
              style: const TextStyle(
                color: Color(0xFF3F2F1D),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}

class _WakeupCard extends StatelessWidget {
  const _WakeupCard({
    required this.levelState,
    required this.completedTasks,
    required this.totalTasks,
    required this.isLoading,
  });

  final ChildLevelState levelState;
  final int completedTasks;
  final int totalTasks;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final safeTotalTasks = totalTasks < 1 ? 1 : totalTasks;
    final safeCompletedTasks = completedTasks.clamp(0, safeTotalTasks);
    final clampedProgress = isLoading
        ? 0.0
        : safeCompletedTasks / safeTotalTasks;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF6EAD3),
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'إنجاز المستوى',
                style: TextStyle(
                  color: Color(0xFF6F6253),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '$safeCompletedTasks / $safeTotalTasks',
                style: const TextStyle(
                  color: Color(0xFF7A6A56),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8E6C3),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE0CCA7)),
                ),
                alignment: Alignment.center,
                child: Image.asset(
                  'assets/risha/risha.png',
                  width: 22,
                  height: 22,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 18,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F8F8),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE3D6C3)),
                  ),
                  padding: const EdgeInsets.all(2),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Stack(
                        children: [
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: const Color(0xFFE9E9E9),
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeOut,
                            width: constraints.maxWidth * clampedProgress,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [Color(0xFF2D8B52), Color(0xFF79C49B)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          if (isLoading)
                            const Positioned.fill(
                              child: Center(
                                child: SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.8,
                                    color: Color(0xFFB39A77),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.level});

  final int level;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF8E6C3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE4CAA0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/risha/risha.png',
            width: 16,
            height: 16,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 4),
          Text(
            level.toString(),
            style: const TextStyle(
              color: Color(0xFF3F2F1D),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupTitle extends StatelessWidget {
  const _GroupTitle({required this.title, required this.iconPath});

  final String title;
  final String iconPath;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset(iconPath, width: 20, height: 20, fit: BoxFit.contain),
        const SizedBox(width: 5),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF3D3025),
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _DailyTaskCard extends StatelessWidget {
  const _DailyTaskCard({
    required this.data,
    required this.completed,
    this.onTap,
  });

  final _DailyCardData data;
  final bool completed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onTap != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          height: 62,
          decoration: BoxDecoration(
            color: const Color(0xFFFDFBF8),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: data.highlighted
                  ? const Color(0xFF2A9DF4)
                  : Colors.transparent,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: completed ? 0.03 : 0.07),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Opacity(
            opacity: completed
                ? 0.52
                : isEnabled
                ? 1
                : 0.75,
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 56,
                          child: Center(
                            child: Image.asset(
                              data.imagePath,
                              width: 46,
                              height: 46,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Align(
                            alignment: Alignment.center,
                            child: Text(
                              data.title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFF2F261D),
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (completed)
                  const Positioned(
                    top: 6,
                    right: 8,
                    child: _TaskCompletedBadge(),
                  ),
                if (!completed &&
                    data.availabilityMessage != null &&
                    data.availabilityMessage!.trim().isNotEmpty)
                  Positioned(
                    top: 6,
                    right: 8,
                    child: _TaskStatusBadge(
                      label: data.availabilityMessage!,
                      isActiveSoon: data.availabilityHighlightsActivation,
                      isMissed: data.availabilityIsMissed,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TaskCompletedBadge extends StatelessWidget {
  const _TaskCompletedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFE6E0D2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF7A8D69)),
          SizedBox(width: 4),
          Text(
            'تم الإنجاز لليوم',
            style: TextStyle(
              color: Color(0xFF6B6254),
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskStatusBadge extends StatelessWidget {
  const _TaskStatusBadge({
    required this.label,
    required this.isActiveSoon,
    this.isMissed = false,
  });

  final String label;
  final bool isActiveSoon;
  final bool isMissed;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 142),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isMissed
            ? const Color(0xFFF6D9D5)
            : isActiveSoon
            ? const Color(0xFFF2E3C1)
            : const Color(0xFFE6E0D2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: isMissed
              ? const Color(0xFFB2473D)
              : isActiveSoon
              ? const Color(0xFF7E5C22)
              : const Color(0xFF6B6254),
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ScheduledTaskAvailabilityState {
  const _ScheduledTaskAvailabilityState({
    this.taskId,
    required this.availableNow,
    this.badgeText,
    this.badgeHighlightsActivation = false,
    this.badgeIsMissed = false,
  });

  final String? taskId;
  final bool availableNow;
  final String? badgeText;
  final bool badgeHighlightsActivation;
  final bool badgeIsMissed;
}

class _LevelRewardDialog extends StatefulWidget {
  const _LevelRewardDialog({required this.level, required this.onContinue});

  final int level;
  final Future<ChildWalletState> Function() onContinue;

  @override
  State<_LevelRewardDialog> createState() => _LevelRewardDialogState();
}

class _LevelRewardDialogState extends State<_LevelRewardDialog> {
  bool _isSubmitting = false;
  String? _errorMessage;

  Future<void> _handleContinue() async {
    if (_isSubmitting) {
      return;
    }
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      final wallet = await widget.onContinue();
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(wallet);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
        _errorMessage = 'تعذر إضافة مكافأة المستوى الآن.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
        decoration: BoxDecoration(
          color: const Color(0xFFF8EFD9),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/risha/risha_happy.png',
              width: 136,
              height: 136,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 14),
            Text(
              'مبروك عليك تقدمك إلى المستوى ${widget.level}\nلديك مكافئة 50 نقطة على هذا الانجاز العظيم',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF3D3025),
                fontSize: 19,
                fontWeight: FontWeight.w700,
                height: 1.45,
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF9B493D),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _handleContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D8B52),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFF9FB9A8),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'استمر يا بطل',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyCardData {
  const _DailyCardData({
    required this.title,
    required this.imagePath,
    this.route,
    this.taskId,
    this.behaviorId,
    this.availableNow = true,
    this.availabilityMessage,
    bool? availabilityHighlightsActivation,
    this.availabilityIsMissed = false,
  }) : availabilityHighlightsActivation =
           availabilityHighlightsActivation ?? !availableNow,
       highlighted = false;

  final String title;
  final String imagePath;
  final String? route;
  final String? taskId;
  final String? behaviorId;
  final bool availableNow;
  final String? availabilityMessage;
  final bool availabilityHighlightsActivation;
  final bool availabilityIsMissed;
  final bool highlighted;
}

class _RewardResultDialog extends StatefulWidget {
  const _RewardResultDialog({
    required this.isApproved,
    required this.description,
    required this.onClose,
  });

  final bool isApproved;
  final String description;
  final VoidCallback onClose;

  @override
  State<_RewardResultDialog> createState() => _RewardResultDialogState();
}

class _RewardResultDialogState extends State<_RewardResultDialog> {
  late final AudioPlayer _player;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();

    // تشغيل الصوت فقط إذا كانت المكافأة مقبولة
    if (widget.isApproved) {
      _playSound();
    }
  }

  Future<void> _playSound() async {
    try {
      // تأكد من صحة المسار (نسبة إلى مجلد assets)
      await _player.setAsset('assets/sounds/getcoins.m4a');
      await _player.play();
    } catch (e) {
      debugPrint('خطأ في تشغيل الصوت: $e');
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // نفس محتوى build السابق (لكن مع استخدام widget.isApproved إلخ)
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
        decoration: BoxDecoration(
          color: const Color(0xFFF8EFD9),
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              widget.isApproved
                  ? 'assets/risha/risha_happy.png'
                  : 'assets/risha/risha_tired.png',
              width: 160,
              height: 160,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 20),
            Text(
              widget.isApproved ? 'أحسنت يا بطل!' : 'نعتذر منك..',
              style: TextStyle(
                color: widget.isApproved
                    ? const Color(0xFF2D8B52)
                    : const Color(0xFF9B493D),
                fontSize: 26,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              widget.isApproved
                  ? 'لقد وافق والداك على طلبك: "${widget.description}"\nتم إضافة النقاط إلى رصيدك بنجاح!'
                  : 'تم رفض طلبك: "${widget.description}"\nيجب عليك إعادة السلوك بشكل أفضل في المرة القادمة لتنال المكافأة. ريشة ينتظر منك التميز!',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF3D3025),
                fontSize: 17,
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: widget.onClose,
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.isApproved
                      ? const Color(0xFF2D8B52)
                      : const Color(0xFFC69C6D),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  widget.isApproved ? 'رائع!' : 'سأحاول مجدداً',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomMenuBar extends StatelessWidget {
  const _BottomMenuBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      color: const Color(0xFF5A9E79),
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => context.go('/child-home/market'),
            child: Image.asset(
              'assets/icons/market_icon.png',
              width: 90,
              height: 90,
              fit: BoxFit.contain,
            ),
          ),
          Image.asset(
            'assets/icons/nest_icon.png',
            width: 96,
            height: 96,
            fit: BoxFit.contain,
          ),
          GestureDetector(
            onTap: () => context.go('/child-home/settings'),
            child: Image.asset(
              'assets/icons/setting_icon.png',
              width: 60,
              height: 60,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }
}
