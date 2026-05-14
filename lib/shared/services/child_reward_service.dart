import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:risha_v01/shared/services/child_local_state_service.dart';
import 'package:risha_v01/shared/services/email_notification_service.dart';
import 'package:risha_v01/shared/services/selected_child_service.dart';

class ChildLevelState {
  const ChildLevelState({
    required this.level,
    required this.progressTasks,
    required this.targetTasks,
    this.pendingRewardLevels = const <int>[],
  });

  final int level;
  final int progressTasks;
  final int targetTasks;
  final List<int> pendingRewardLevels;

  factory ChildLevelState.defaults({int targetTasks = 1}) {
    final safeTarget = targetTasks < 1 ? 1 : targetTasks;
    return ChildLevelState(
      level: 0,
      progressTasks: 0,
      targetTasks: safeTarget,
      pendingRewardLevels: const <int>[],
    );
  }

  factory ChildLevelState.fromMap(
    Object? rawValue, {
    int fallbackTargetTasks = 1,
  }) {
    if (rawValue is! Map) {
      return ChildLevelState.defaults(targetTasks: fallbackTargetTasks);
    }

    final data = rawValue.map((key, value) => MapEntry(key.toString(), value));
    final safeTarget = ChildRewardService.parseLevelTargetValue(
      data['targetTasks'],
      fallback: fallbackTargetTasks,
    );
    final pendingLevels =
        (data['pendingRewardLevels'] as Iterable<dynamic>? ?? const <dynamic>[])
            .map(
              (item) =>
                  ChildRewardService.parseIntegerValue(item, fallback: -1),
            )
            .where((value) => value > 0)
            .toList(growable: false);

    return ChildLevelState(
      level: ChildRewardService.parseIntegerValue(data['level'], fallback: 0),
      progressTasks: ChildRewardService.parseIntegerValue(
        data['progressTasks'],
        fallback: 0,
      ),
      targetTasks: safeTarget,
      pendingRewardLevels: pendingLevels,
    );
  }

  bool get hasPendingReward => pendingRewardLevels.isNotEmpty;

  int? get nextPendingRewardLevel =>
      hasPendingReward ? pendingRewardLevels.first : null;

  double get progressRatio {
    if (targetTasks <= 0) {
      return 0;
    }
    return progressTasks / targetTasks;
  }

  ChildLevelState copyWith({
    int? level,
    int? progressTasks,
    int? targetTasks,
    List<int>? pendingRewardLevels,
  }) {
    return ChildLevelState(
      level: level ?? this.level,
      progressTasks: progressTasks ?? this.progressTasks,
      targetTasks: targetTasks ?? this.targetTasks,
      pendingRewardLevels: pendingRewardLevels ?? this.pendingRewardLevels,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'level': level < 0 ? 0 : level,
      'progressTasks': progressTasks < 0 ? 0 : progressTasks,
      'targetTasks': targetTasks < 1 ? 1 : targetTasks,
      'pendingRewardLevels': pendingRewardLevels.toList(growable: false),
    };
  }
}

class ChildWalletState {
  const ChildWalletState({
    required this.coins,
    required this.ownedMarketItemAssetPaths,
    this.levelState = const ChildLevelState(
      level: 0,
      progressTasks: 0,
      targetTasks: 1,
    ),
    this.equippedAccessoryAssetPath,
    this.equippedOutfitAssetPath,
    this.pendingRewards = const <PendingReward>[],
  });

  final int coins;
  final List<String> ownedMarketItemAssetPaths;
  final ChildLevelState levelState;
  final String? equippedAccessoryAssetPath;
  final String? equippedOutfitAssetPath;
  final List<PendingReward> pendingRewards;

  factory ChildWalletState.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return ChildWalletState.fromMap(doc.data() ?? const <String, dynamic>{});
  }

  factory ChildWalletState.fromMap(Map<String, dynamic> data) {
    final rawOwnedItems = data['ownedMarketItemAssetPaths'];
    final rawPendingRewards = data['pendingRewards'];
    return ChildWalletState(
      coins: ChildRewardService.parseCoinsValue(data['coins']),
      ownedMarketItemAssetPaths: rawOwnedItems is Iterable
          ? rawOwnedItems
                .whereType<String>()
                .map((item) => item.trim())
                .where((item) => item.isNotEmpty)
                .toSet()
                .toList(growable: false)
          : const <String>[],
      levelState: ChildLevelState.fromMap(data['levelState']),
      equippedAccessoryAssetPath: _readNullableString(
        data['equippedAccessoryAssetPath'],
      ),
      equippedOutfitAssetPath: _readNullableString(
        data['equippedOutfitAssetPath'],
      ),
      pendingRewards: rawPendingRewards is Iterable
          ? rawPendingRewards
                .whereType<Map<String, dynamic>>()
                .map(PendingReward.fromMap)
                .toList(growable: false)
          : const <PendingReward>[],
    );
  }

  ChildWalletState copyWith({
    int? coins,
    List<String>? ownedMarketItemAssetPaths,
    ChildLevelState? levelState,
    String? equippedAccessoryAssetPath,
    bool clearAccessory = false,
    String? equippedOutfitAssetPath,
    bool clearOutfit = false,
    List<PendingReward>? pendingRewards,
  }) {
    return ChildWalletState(
      coins: coins ?? this.coins,
      ownedMarketItemAssetPaths:
          ownedMarketItemAssetPaths ?? this.ownedMarketItemAssetPaths,
      levelState: levelState ?? this.levelState,
      equippedAccessoryAssetPath: clearAccessory
          ? null
          : equippedAccessoryAssetPath ?? this.equippedAccessoryAssetPath,
      equippedOutfitAssetPath: clearOutfit
          ? null
          : equippedOutfitAssetPath ?? this.equippedOutfitAssetPath,
      pendingRewards: pendingRewards ?? this.pendingRewards,
    );
  }

  static String? _readNullableString(Object? value) {
    if (value is! String) {
      return null;
    }

    final cleanValue = value.trim();
    return cleanValue.isEmpty ? null : cleanValue;
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'coins': coins,
      'ownedMarketItemAssetPaths': ownedMarketItemAssetPaths.toList(
        growable: false,
      ),
      'levelState': levelState.toMap(),
      'pendingRewards': pendingRewards
          .map((r) => r.toMap())
          .toList(growable: false),
      if (equippedAccessoryAssetPath != null)
        'equippedAccessoryAssetPath': equippedAccessoryAssetPath,
      if (equippedOutfitAssetPath != null)
        'equippedOutfitAssetPath': equippedOutfitAssetPath,
    };
  }
}

enum PendingRewardStatus { pending, approved, rejected, expired }

class PendingReward {
  const PendingReward({
    required this.id,
    required this.rewardType,
    required this.description,
    required this.coins,
    required this.requestedAt,
    this.status = PendingRewardStatus.pending,
    this.approvedAt,
    this.rejectedAt,
    this.approvalToken,
    this.rejectionToken,
    this.taskId,
  });

  final String id;
  final String rewardType;
  final String description;
  final int coins;
  final DateTime requestedAt;
  final PendingRewardStatus status;
  final DateTime? approvedAt;
  final DateTime? rejectedAt;
  final String? approvalToken;
  final String? rejectionToken;
  final String? taskId;

  factory PendingReward.fromMap(Map<String, dynamic> data) {
    return PendingReward(
      id: data['id'] as String? ?? '',
      rewardType: data['rewardType'] as String? ?? '',
      description: data['description'] as String? ?? '',
      coins: ChildRewardService.parseIntegerValue(data['coins'], fallback: 0),
      requestedAt:
          DateTime.tryParse(data['requestedAt'] as String? ?? '') ??
          DateTime.now(),
      status: PendingRewardStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => PendingRewardStatus.pending,
      ),
      approvedAt: data['approvedAt'] != null
          ? DateTime.tryParse(data['approvedAt'] as String)
          : null,
      rejectedAt: data['rejectedAt'] != null
          ? DateTime.tryParse(data['rejectedAt'] as String)
          : null,
      approvalToken: data['approvalToken'] as String?,
      rejectionToken: data['rejectionToken'] as String?,
      taskId: data['taskId'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'rewardType': rewardType,
      'description': description,
      'coins': coins,
      'requestedAt': requestedAt.toIso8601String(),
      'status': status.name,
      if (approvedAt != null) 'approvedAt': approvedAt!.toIso8601String(),
      if (rejectedAt != null) 'rejectedAt': rejectedAt!.toIso8601String(),
      if (approvalToken != null) 'approvalToken': approvalToken,
      if (rejectionToken != null) 'rejectionToken': rejectionToken,
      if (taskId != null) 'taskId': taskId,
    };
  }

  PendingReward copyWith({
    String? id,
    String? rewardType,
    String? description,
    int? coins,
    DateTime? requestedAt,
    PendingRewardStatus? status,
    DateTime? approvedAt,
    DateTime? rejectedAt,
    String? approvalToken,
    String? rejectionToken,
    String? taskId,
  }) {
    return PendingReward(
      id: id ?? this.id,
      rewardType: rewardType ?? this.rewardType,
      description: description ?? this.description,
      coins: coins ?? this.coins,
      requestedAt: requestedAt ?? this.requestedAt,
      status: status ?? this.status,
      approvedAt: approvedAt ?? this.approvedAt,
      rejectedAt: rejectedAt ?? this.rejectedAt,
      approvalToken: approvalToken ?? this.approvalToken,
      rejectionToken: rejectionToken ?? this.rejectionToken,
      taskId: taskId ?? this.taskId,
    );
  }
}

class _RewardApprovalSyncResult {
  const _RewardApprovalSyncResult({
    required this.wallet,
    required this.taskProgressHistory,
    this.dailyTaskProgress,
  });

  final ChildWalletState wallet;
  final Map<String, dynamic> taskProgressHistory;
  final Map<String, dynamic>? dailyTaskProgress;
}

class _RemoteWalletLookupResult {
  const _RemoteWalletLookupResult({
    required this.wasChecked,
    required this.wallet,
  });

  final bool wasChecked;
  final ChildWalletState? wallet;
}

class ChildRewardService {
  ChildRewardService({
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
           emailNotificationService ?? EmailNotificationService();

  // الرصيد الافتراضي الأساسي للطفل عند عدم وجود رصيد محفوظ بعد.
  // غيّر الرقم هنا إذا أردت أن يبدأ كل طفل جديد بعدد نقاط مختلف.
  static const int defaultCoins = 0;

  // عدد النقاط التي تضاف عند إنجاز مهمة واحدة.
  // غيّرها إذا أردت رفع أو خفض مكافأة المهام اليومية.
  static const int taskRewardCoins = 5;
  static const int levelRewardCoins = 25;

  // السعر الافتراضي العام لكل قطعة في المتجر.
  // هذا هو السعر الحقيقي المستخدم إذا لم تضع سعرًا تجريبيًا من شاشة المتجر.
  static const int marketItemPrice = 50;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final SelectedChildService _selectedChildService;
  final ChildLocalStateService _localStateService;
  final EmailNotificationService _emailNotificationService;
  final Set<String> _walletSyncInFlight = <String>{};

  static int parseCoinsValue(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return defaultCoins;
  }

  static int parseIntegerValue(Object? value, {required int fallback}) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value.trim()) ?? fallback;
    }
    return fallback;
  }

  static int parseLevelTargetValue(Object? value, {required int fallback}) {
    final parsed = parseIntegerValue(value, fallback: fallback);
    return parsed < 1 ? (fallback < 1 ? 1 : fallback) : parsed;
  }

  static String generatePendingRewardActionToken([int length = 32]) {
    const availableChars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final secureRandom = Random.secure();
    return List<String>.generate(
      length,
      (_) => availableChars[secureRandom.nextInt(availableChars.length)],
    ).join();
  }

  @visibleForTesting
  static PendingReward? selectReusablePendingRewardForTask({
    required ChildWalletState localWallet,
    required String taskId,
    required String rewardType,
    ChildWalletState? remoteWallet,
    bool remoteWasChecked = false,
  }) {
    final cleanTaskId = taskId.trim();
    final cleanRewardType = rewardType.trim();
    if (cleanTaskId.isEmpty || cleanRewardType.isEmpty) {
      return null;
    }

    PendingReward? localPendingReward;
    for (final reward in localWallet.pendingRewards) {
      if (_isPendingRewardForTask(
        reward: reward,
        taskId: cleanTaskId,
        rewardType: cleanRewardType,
      )) {
        localPendingReward = reward;
        break;
      }
    }

    if (localPendingReward == null) {
      return null;
    }
    if (!remoteWasChecked) {
      return localPendingReward;
    }

    for (final reward
        in remoteWallet?.pendingRewards ?? const <PendingReward>[]) {
      if (_isPendingRewardForTask(
        reward: reward,
        taskId: cleanTaskId,
        rewardType: cleanRewardType,
      )) {
        return reward;
      }
    }

    return null;
  }

  static bool _isPendingRewardForTask({
    required PendingReward reward,
    required String taskId,
    required String rewardType,
  }) {
    if (reward.status != PendingRewardStatus.pending) return false;
    if (reward.taskId?.trim() != taskId) return false;
    if (reward.rewardType.trim() != rewardType) return false;

    // As requested: allow retrying if it has been hanging for more than 5 minutes
    final age = DateTime.now().difference(reward.requestedAt);
    if (age.inMinutes >= 5) return false;

    return true;
  }

  Future<ChildWalletState> getSelectedChildWallet() async {
    final childId = await _selectedChildId();
    final childDoc = _childDocument(childId);

    // 1. Get current local state
    final localWalletMap = await _localStateService.getWalletMap(
      childId: childId,
    );
    final localWallet = localWalletMap != null
        ? ChildWalletState.fromMap(localWalletMap)
        : null;

    try {
      // 2. Always attempt to get the latest from Firestore
      final snapshot = await childDoc.get();
      if (snapshot.exists) {
        final remoteWallet = ChildWalletState.fromDocument(snapshot);

        // 3. Merge them! This is what forces "Approved" to replace "Pending"
        final mergedWallet = _mergePendingWalletWithRemote(
          remoteWallet: remoteWallet,
          pendingWallet: localWallet ?? remoteWallet,
        );

        // 4. Update local cache with the truth
        await _saveLocalWallet(childId: childId, wallet: mergedWallet);
        await _syncApprovedTaskRewardsLocally(
          childId: childId,
          wallet: mergedWallet,
        );
        return mergedWallet;
      }
    } catch (e) {
      debugPrint('Wallet fetch failed, falling back to local: $e');
    }

    // 5. Fallback only if remote fails
    if (localWallet != null) {
      unawaited(_syncPendingWalletIfNeeded(childId));
      return localWallet;
    }

    throw const ChildRewardFailure(
      'تعذر تحميل بيانات المحفظة. تحقق من الاتصال.',
    );
  }

  Future<ChildWalletState> ensureSelectedChildLevelInitialized({
    required int baseTargetTasks,
  }) async {
    final childId = await _selectedChildId();
    final safeBaseTarget = baseTargetTasks < 1 ? 1 : baseTargetTasks;
    final localWallet = await _getLocalWallet(childId);
    final localFallbackWallet = _initializedLevelWalletIfNeeded(
      localWallet,
      safeBaseTarget,
    );
    if (!_shouldInitializeLevelState(localWallet.levelState, safeBaseTarget)) {
      return localFallbackWallet;
    }

    await _saveLocalWallet(childId: childId, wallet: localFallbackWallet);
    await _localStateService.savePendingWalletSyncMap(
      childId: childId,
      data: localFallbackWallet.toMap(),
    );
    unawaited(_syncPendingWalletIfNeeded(childId));
    _schedulePendingWalletSyncRetries(childId);
    return localFallbackWallet;
  }

  bool _shouldInitializeLevelState(
    ChildLevelState levelState,
    int safeBaseTarget,
  ) {
    return levelState.targetTasks <= 0 ||
        (levelState.level == 0 &&
            levelState.progressTasks == 0 &&
            !levelState.hasPendingReward &&
            levelState.targetTasks == 1 &&
            safeBaseTarget != 1);
  }

  ChildWalletState _initializedLevelWalletIfNeeded(
    ChildWalletState wallet,
    int safeBaseTarget,
  ) {
    if (!_shouldInitializeLevelState(wallet.levelState, safeBaseTarget)) {
      return wallet;
    }
    return wallet.copyWith(
      levelState: ChildLevelState.defaults(targetTasks: safeBaseTarget),
    );
  }

  Future<ChildWalletState> claimSelectedChildLevelReward({
    int rewardCoins = levelRewardCoins,
  }) async {
    final childId = await _selectedChildId();
    final childDoc = _childDocument(childId);
    final normalizedRewardCoins = rewardCoins < 0 ? 0 : rewardCoins;
    final currentWallet = await _getLocalWallet(childId);
    final currentLevelState = currentWallet.levelState;
    if (!currentLevelState.hasPendingReward) {
      unawaited(_syncPendingWalletIfNeeded(childId));
      return currentWallet;
    }

    final claimedLevel = currentLevelState.pendingRewardLevels.first;
    try {
      final updatedWallet = await _firestore.runTransaction<ChildWalletState>((
        transaction,
      ) async {
        final snapshot = await transaction.get(childDoc);
        if (!snapshot.exists) {
          throw const ChildRewardFailure('لم يتم العثور على ملف الطفل المحدد.');
        }

        final remoteWallet = ChildWalletState.fromMap(
          snapshot.data() ?? const <String, dynamic>{},
        );
        final remoteLevelState = remoteWallet.levelState;
        if (!remoteLevelState.hasPendingReward) {
          return remoteWallet;
        }

        final nextPendingLevels = List<int>.from(
          remoteLevelState.pendingRewardLevels,
        );
        final matchingLevelIndex = nextPendingLevels.indexOf(claimedLevel);
        if (matchingLevelIndex == -1) {
          nextPendingLevels.removeAt(0);
        } else {
          nextPendingLevels.removeAt(matchingLevelIndex);
        }

        final nextWallet = remoteWallet.copyWith(
          coins: remoteWallet.coins + normalizedRewardCoins,
          levelState: remoteLevelState.copyWith(
            pendingRewardLevels: nextPendingLevels,
          ),
        );
        transaction.set(childDoc, {
          'coins': nextWallet.coins,
          'levelState': nextWallet.levelState.toMap(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return nextWallet;
      });

      await _saveLocalWallet(childId: childId, wallet: updatedWallet);
      await _localStateService.savePendingWalletSyncMap(
        childId: childId,
        data: const <String, dynamic>{},
      );
      return updatedWallet;
    } catch (e) {
      if (e is ChildRewardFailure) {
        rethrow;
      }
      if (!_shouldUseLocalFallback(e)) {
        if (e is FirebaseException) {
          throw ChildRewardFailure(_mapFirebaseError(e));
        }
        rethrow;
      }

      final nextPendingLevels = List<int>.from(
        currentLevelState.pendingRewardLevels,
      )..removeAt(0);
      final nextWallet = currentWallet.copyWith(
        coins: currentWallet.coins + normalizedRewardCoins,
        levelState: currentLevelState.copyWith(
          pendingRewardLevels: nextPendingLevels,
        ),
      );
      await _saveLocalWallet(childId: childId, wallet: nextWallet);
      await _localStateService.savePendingWalletSyncMap(
        childId: childId,
        data: nextWallet.toMap(),
      );
      _schedulePendingWalletSyncRetries(childId);
      return nextWallet;
    }
  }

  Future<int> awardSelectedChildCoins({int amount = taskRewardCoins}) async {
    if (amount <= 0) {
      final wallet = await getSelectedChildWallet();
      return wallet.coins;
    }

    final childId = await _selectedChildId();
    final childDoc = _childDocument(childId);

    try {
      final updatedWallet = await _firestore.runTransaction<ChildWalletState>((
        transaction,
      ) async {
        final snapshot = await transaction.get(childDoc);
        if (!snapshot.exists) {
          throw const ChildRewardFailure('لم يتم العثور على ملف الطفل المحدد.');
        }

        final currentWallet = ChildWalletState.fromMap(
          snapshot.data() ?? const <String, dynamic>{},
        );
        final nextCoins = currentWallet.coins + amount;
        transaction.set(childDoc, {
          'coins': nextCoins,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return currentWallet.copyWith(coins: nextCoins);
      });
      await _saveLocalWallet(childId: childId, wallet: updatedWallet);
      return updatedWallet.coins;
    } catch (e) {
      if (e is ChildRewardFailure) rethrow;

      if (_shouldUseLocalFallback(e)) {
        final currentWallet = await _getLocalWallet(childId);
        final nextWallet = currentWallet.copyWith(
          coins: currentWallet.coins + amount,
        );
        await _saveLocalWallet(childId: childId, wallet: nextWallet);
        return nextWallet.coins;
      }

      if (e is FirebaseException) {
        throw ChildRewardFailure(_mapFirebaseError(e));
      }
      rethrow;
    }
  }

  // استخدم هذه الدالة إذا أردت فرض رصيد معين للطفل من الكود مباشرة.
  // مثال: setSelectedChildCoins(coins: 300)
  Future<ChildWalletState> setSelectedChildCoins({required int coins}) async {
    final childId = await _selectedChildId();
    final childDoc = _childDocument(childId);
    final nextCoins = coins < 0 ? 0 : coins;

    try {
      final updatedWallet = await _firestore.runTransaction<ChildWalletState>((
        transaction,
      ) async {
        final snapshot = await transaction.get(childDoc);
        if (!snapshot.exists) {
          throw const ChildRewardFailure('لم يتم العثور على ملف الطفل المحدد.');
        }

        final currentWallet = ChildWalletState.fromMap(
          snapshot.data() ?? const <String, dynamic>{},
        );
        transaction.set(childDoc, {
          'coins': nextCoins,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return currentWallet.copyWith(coins: nextCoins);
      });
      await _saveLocalWallet(childId: childId, wallet: updatedWallet);
      return updatedWallet;
    } catch (e) {
      if (e is ChildRewardFailure) rethrow;

      if (_shouldUseLocalFallback(e)) {
        final currentWallet = await _getLocalWallet(childId);
        final nextWallet = currentWallet.copyWith(coins: nextCoins);
        await _saveLocalWallet(childId: childId, wallet: nextWallet);
        return nextWallet;
      }

      if (e is FirebaseException) {
        throw ChildRewardFailure(_mapFirebaseError(e));
      }
      rethrow;
    }
  }

  // purchasePrice:
  // إذا مررت قيمة هنا فسيستخدمها لهذا الشراء فقط.
  // وإذا لم تمرر شيئًا فسيستخدم السعر الافتراضي العام marketItemPrice.
  Future<MarketPurchaseResult> purchaseSelectedChildMarketItem({
    required String assetPath,
    required bool isAccessory,
    int purchasePrice = marketItemPrice,
  }) async {
    final childId = await _selectedChildId();
    final childDoc = _childDocument(childId);
    final cleanAssetPath = assetPath.trim();
    final normalizedPurchasePrice = purchasePrice < 0 ? 0 : purchasePrice;
    if (cleanAssetPath.isEmpty) {
      throw const ChildRewardFailure('تعذر تحديد العنصر المطلوب شراؤه.');
    }

    try {
      final result = await _firestore.runTransaction<MarketPurchaseResult>((
        transaction,
      ) async {
        final snapshot = await transaction.get(childDoc);
        if (!snapshot.exists) {
          throw const ChildRewardFailure('لم يتم العثور على ملف الطفل المحدد.');
        }

        final currentWallet = ChildWalletState.fromMap(
          snapshot.data() ?? const <String, dynamic>{},
        );
        final ownedItems = currentWallet.ownedMarketItemAssetPaths.toSet();
        final purchasedNow = !ownedItems.contains(cleanAssetPath);
        if (purchasedNow && currentWallet.coins < normalizedPurchasePrice) {
          throw const InsufficientCoinsFailure();
        }

        if (purchasedNow) {
          ownedItems.add(cleanAssetPath);
        }

        final nextCoins = purchasedNow
            ? currentWallet.coins - normalizedPurchasePrice
            : currentWallet.coins;
        final nextWallet = currentWallet.copyWith(
          coins: nextCoins,
          ownedMarketItemAssetPaths: ownedItems.toList(growable: false),
          equippedAccessoryAssetPath: isAccessory
              ? cleanAssetPath
              : currentWallet.equippedAccessoryAssetPath,
          equippedOutfitAssetPath: isAccessory
              ? currentWallet.equippedOutfitAssetPath
              : cleanAssetPath,
        );

        transaction.set(childDoc, {
          'coins': nextCoins,
          'ownedMarketItemAssetPaths': nextWallet.ownedMarketItemAssetPaths,
          if (isAccessory)
            'equippedAccessoryAssetPath': cleanAssetPath
          else
            'equippedOutfitAssetPath': cleanAssetPath,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        return MarketPurchaseResult(
          wallet: nextWallet,
          purchasedNow: purchasedNow,
        );
      });
      await _saveLocalWallet(childId: childId, wallet: result.wallet);
      return result;
    } catch (e) {
      if (e is ChildRewardFailure) rethrow;

      if (_shouldUseLocalFallback(e)) {
        return _purchaseLocally(
          childId: childId,
          assetPath: cleanAssetPath,
          isAccessory: isAccessory,
          purchasePrice: normalizedPurchasePrice,
        );
      }

      if (e is FirebaseException) {
        throw ChildRewardFailure(_mapFirebaseError(e));
      }
      rethrow;
    }
  }

  Future<ChildWalletState> setSelectedChildEquippedItem({
    required bool isAccessory,
    String? assetPath,
  }) async {
    final childId = await _selectedChildId();
    final childDoc = _childDocument(childId);
    final cleanAssetPath = assetPath?.trim();
    final nextAssetPath = cleanAssetPath == null || cleanAssetPath.isEmpty
        ? null
        : cleanAssetPath;

    try {
      final updatedWallet = await _firestore.runTransaction<ChildWalletState>((
        transaction,
      ) async {
        final snapshot = await transaction.get(childDoc);
        if (!snapshot.exists) {
          throw const ChildRewardFailure('لم يتم العثور على ملف الطفل المحدد.');
        }

        final currentWallet = ChildWalletState.fromMap(
          snapshot.data() ?? const <String, dynamic>{},
        );
        final ownedItems = currentWallet.ownedMarketItemAssetPaths.toSet();
        if (nextAssetPath != null && !ownedItems.contains(nextAssetPath)) {
          throw const ChildRewardFailure(
            'لا يمكن استخدام هذا العنصر قبل شرائه.',
          );
        }

        final nextWallet = currentWallet.copyWith(
          equippedAccessoryAssetPath: isAccessory
              ? nextAssetPath
              : currentWallet.equippedAccessoryAssetPath,
          clearAccessory: isAccessory && nextAssetPath == null,
          equippedOutfitAssetPath: isAccessory
              ? currentWallet.equippedOutfitAssetPath
              : nextAssetPath,
          clearOutfit: !isAccessory && nextAssetPath == null,
        );

        transaction.set(childDoc, {
          if (isAccessory)
            'equippedAccessoryAssetPath': nextAssetPath
          else
            'equippedOutfitAssetPath': nextAssetPath,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        return nextWallet;
      });
      await _saveLocalWallet(childId: childId, wallet: updatedWallet);
      return updatedWallet;
    } catch (e) {
      if (e is ChildRewardFailure) rethrow;

      if (_shouldUseLocalFallback(e)) {
        return _setEquippedItemLocally(
          childId: childId,
          isAccessory: isAccessory,
          assetPath: nextAssetPath,
        );
      }

      if (e is FirebaseException) {
        throw ChildRewardFailure(_mapFirebaseError(e));
      }
      rethrow;
    }
  }

  Future<void> rejectPendingReward(String rewardId) async {
    final childId = await _selectedChildId();
    final childDoc = _childDocument(childId);
    final decisionAt = DateTime.now();

    try {
      final updatedWallet = await _firestore.runTransaction<ChildWalletState>((
        transaction,
      ) async {
        final snapshot = await transaction.get(childDoc);
        if (!snapshot.exists) {
          throw const ChildRewardFailure('لم يتم العثور على ملف الطفل المحدد.');
        }

        final currentWallet = ChildWalletState.fromMap(
          snapshot.data() ?? const <String, dynamic>{},
        );

        final rewardIndex = currentWallet.pendingRewards.indexWhere(
          (r) => r.id == rewardId,
        );
        if (rewardIndex == -1) {
          throw const ChildRewardFailure('المكافأة المطلوبة غير موجودة.');
        }

        final reward = currentWallet.pendingRewards[rewardIndex];
        if (reward.status != PendingRewardStatus.pending) {
          throw const ChildRewardFailure('المكافأة لم تعد معلقة.');
        }

        final updatedRewards = List<PendingReward>.from(
          currentWallet.pendingRewards,
        );
        updatedRewards[rewardIndex] = reward.copyWith(
          status: PendingRewardStatus.rejected,
          rejectedAt: decisionAt,
        );

        final updatedWallet = currentWallet.copyWith(
          pendingRewards: updatedRewards,
        );

        transaction.set(childDoc, {
          'pendingRewards': updatedWallet.pendingRewards
              .map((r) => r.toMap())
              .toList(growable: false),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return updatedWallet;
      });

      await _saveLocalWallet(childId: childId, wallet: updatedWallet);
      await _localStateService.savePendingWalletSyncMap(
        childId: childId,
        data: updatedWallet.toMap(),
      );
      await _syncPendingWalletIfNeeded(childId);
    } catch (e) {
      if (_shouldUseLocalFallback(e)) {
        final currentWallet = await _getLocalWallet(childId);
        final rewardIndex = currentWallet.pendingRewards.indexWhere(
          (r) => r.id == rewardId,
        );
        if (rewardIndex != -1) {
          final reward = currentWallet.pendingRewards[rewardIndex];
          final updatedRewards = List<PendingReward>.from(
            currentWallet.pendingRewards,
          );
          updatedRewards[rewardIndex] = reward.copyWith(
            status: PendingRewardStatus.rejected,
            rejectedAt: decisionAt,
          );
          final updatedWallet = currentWallet.copyWith(
            pendingRewards: updatedRewards,
          );
          await _saveLocalWallet(childId: childId, wallet: updatedWallet);
          await _localStateService.savePendingWalletSyncMap(
            childId: childId,
            data: updatedWallet.toMap(),
          );
          unawaited(_syncPendingWalletIfNeeded(childId));
          _schedulePendingWalletSyncRetries(childId);
        }
        return;
      }

      if (e is FirebaseException) {
        throw ChildRewardFailure(_mapFirebaseError(e));
      }
      rethrow;
    }
  }

  Future<void> approvePendingReward(String rewardId) async {
    final childId = await _selectedChildId();
    final childDoc = _childDocument(childId);
    final decisionAt = DateTime.now();

    try {
      final syncResult = await _firestore
          .runTransaction<_RewardApprovalSyncResult>((transaction) async {
            final snapshot = await transaction.get(childDoc);
            if (!snapshot.exists) {
              throw const ChildRewardFailure('Child record was not found.');
            }

            final childData = snapshot.data() ?? const <String, dynamic>{};
            final currentWallet = ChildWalletState.fromMap(childData);
            final rewardIndex = currentWallet.pendingRewards.indexWhere(
              (r) => r.id == rewardId,
            );
            if (rewardIndex == -1) {
              throw const ChildRewardFailure('Pending reward was not found.');
            }

            final reward = currentWallet.pendingRewards[rewardIndex];
            if (reward.status != PendingRewardStatus.pending) {
              throw const ChildRewardFailure('Reward is no longer pending.');
            }

            final updatedReward = reward.copyWith(
              status: PendingRewardStatus.approved,
              approvedAt: decisionAt,
            );
            final updatedRewards = List<PendingReward>.from(
              currentWallet.pendingRewards,
            );
            updatedRewards[rewardIndex] = updatedReward;

            final syncResult = _buildRewardApprovalSyncResult(
              currentWallet: currentWallet,
              updatedRewards: updatedRewards,
              approvedReward: updatedReward,
              rawTaskProgressHistory: childData['taskProgressHistory'],
              rawDailyTaskProgress: childData['dailyTaskProgress'],
              approvedAt: decisionAt,
            );

            final childUpdates = <String, dynamic>{
              'pendingRewards': syncResult.wallet.pendingRewards
                  .map((r) => r.toMap())
                  .toList(growable: false),
              'coins': syncResult.wallet.coins,
              'levelState': syncResult.wallet.levelState.toMap(),
              'updatedAt': FieldValue.serverTimestamp(),
            };
            if (syncResult.taskProgressHistory.isNotEmpty) {
              childUpdates['taskProgressHistory'] =
                  syncResult.taskProgressHistory;
            }
            if (syncResult.dailyTaskProgress != null) {
              childUpdates['dailyTaskProgress'] = syncResult.dailyTaskProgress;
            }

            transaction.set(childDoc, childUpdates, SetOptions(merge: true));
            return syncResult;
          });

      await _saveLocalWallet(childId: childId, wallet: syncResult.wallet);
      await _saveLocalTaskProgressState(
        childId: childId,
        taskProgressHistory: syncResult.taskProgressHistory,
        dailyTaskProgress: syncResult.dailyTaskProgress,
      );
      _syncProgressHistoryForReports(
        childId: childId,
        taskProgressHistory: syncResult.taskProgressHistory,
      );
      await _localStateService.savePendingWalletSyncMap(
        childId: childId,
        data: syncResult.wallet.toMap(),
      );
      await _syncPendingWalletIfNeeded(childId);
    } catch (e) {
      if (_shouldUseLocalFallback(e)) {
        final currentWallet = await _getLocalWallet(childId);
        final localTaskProgressHistory = await _localStateService
            .getTaskProgressHistoryMap(childId: childId);
        final localDailyTaskProgress = await _localStateService
            .getDailyTaskProgressMap(childId: childId);
        final rewardIndex = currentWallet.pendingRewards.indexWhere(
          (r) => r.id == rewardId,
        );
        if (rewardIndex != -1) {
          final reward = currentWallet.pendingRewards[rewardIndex];
          final updatedReward = reward.copyWith(
            status: PendingRewardStatus.approved,
            approvedAt: decisionAt,
          );
          final updatedRewards = List<PendingReward>.from(
            currentWallet.pendingRewards,
          );
          updatedRewards[rewardIndex] = updatedReward;

          final syncResult = _buildRewardApprovalSyncResult(
            currentWallet: currentWallet,
            updatedRewards: updatedRewards,
            approvedReward: updatedReward,
            rawTaskProgressHistory: localTaskProgressHistory,
            rawDailyTaskProgress: localDailyTaskProgress,
            approvedAt: decisionAt,
          );

          await _saveLocalWallet(childId: childId, wallet: syncResult.wallet);
          await _saveLocalTaskProgressState(
            childId: childId,
            taskProgressHistory: syncResult.taskProgressHistory,
            dailyTaskProgress: syncResult.dailyTaskProgress,
          );
          _syncProgressHistoryForReports(
            childId: childId,
            taskProgressHistory: syncResult.taskProgressHistory,
          );
          await _localStateService.savePendingWalletSyncMap(
            childId: childId,
            data: syncResult.wallet.toMap(),
          );
          await _savePendingTaskProgressSync(
            childId: childId,
            taskProgressHistory: syncResult.taskProgressHistory,
          );
          unawaited(_syncPendingWalletIfNeeded(childId));
          _schedulePendingWalletSyncRetries(childId);
        }
        return;
      }

      if (e is FirebaseException) {
        throw ChildRewardFailure(_mapFirebaseError(e));
      }
      rethrow;
    }
  }

  Future<PendingReward> addPendingReward({
    required String rewardType,
    required String description,
    required int coins,
    String? taskId,
    bool awaitEmail = false,
  }) async {
    final childId = await _selectedChildId();
    final newPendingReward = PendingReward(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      rewardType: rewardType,
      description: description,
      coins: coins,
      requestedAt: DateTime.now(),
      status: PendingRewardStatus.pending,
      approvalToken: generatePendingRewardActionToken(),
      rejectionToken: generatePendingRewardActionToken(),
      taskId: taskId?.trim().isEmpty == true ? null : taskId?.trim(),
    );

    final localWallet = await _getLocalWallet(childId);
    var baseLocalWallet = localWallet;
    if (newPendingReward.taskId != null) {
      final localReusableReward = selectReusablePendingRewardForTask(
        localWallet: localWallet,
        taskId: newPendingReward.taskId!,
        rewardType: newPendingReward.rewardType,
      );
      if (localReusableReward != null) {
        final remoteLookup = await _tryReadRemoteWalletForPendingReuse(childId);
        final reusableReward = selectReusablePendingRewardForTask(
          localWallet: localWallet,
          remoteWallet: remoteLookup.wallet,
          remoteWasChecked: remoteLookup.wasChecked,
          taskId: newPendingReward.taskId!,
          rewardType: newPendingReward.rewardType,
        );
        if (reusableReward != null) {
          if (reusableReward.id != localReusableReward.id) {
            await _replaceLocalPendingRewardForTask(
              childId: childId,
              wallet: localWallet,
              reward: reusableReward,
            );
          }
          unawaited(_syncPendingWalletIfNeeded(childId));
          _schedulePendingWalletSyncRetries(childId);
          return reusableReward;
        }

        if (remoteLookup.wasChecked) {
          baseLocalWallet = await _removeLocalPendingRewardForTask(
            childId: childId,
            wallet: localWallet,
            taskId: newPendingReward.taskId!,
            rewardType: newPendingReward.rewardType,
          );
        }
      }
    }

    final alreadyExistsLocally = baseLocalWallet.pendingRewards.any(
      (reward) => reward.id == newPendingReward.id,
    );
    final nextLocalWallet = alreadyExistsLocally
        ? baseLocalWallet
        : baseLocalWallet.copyWith(
            pendingRewards: List<PendingReward>.from(
              baseLocalWallet.pendingRewards,
            )..add(newPendingReward),
          );
    await _saveLocalWallet(childId: childId, wallet: nextLocalWallet);
    await _localStateService.savePendingWalletSyncMap(
      childId: childId,
      data: nextLocalWallet.toMap(),
    );
    await _syncPendingWalletIfNeeded(childId);
    _schedulePendingWalletSyncRetries(childId);

    if (awaitEmail) {
      await _queuePendingRewardEmail(
        childId: childId,
        childName: await _resolveChildName(childId),
        pendingReward: newPendingReward,
      );
    } else {
      unawaited(
        _queuePendingRewardEmail(
          childId: childId,
          childName: await _resolveChildName(childId),
          pendingReward: newPendingReward,
        ),
      );
    }

    return newPendingReward;
  }

  Future<String> _resolveChildName(String childId) async {
    try {
      final childData = await _localStateService.getChildProfileMap(
        childId: childId,
      );
      final childName = (childData?['name'] as String?)?.trim() ?? '';
      if (childName.isNotEmpty) {
        return childName;
      }
    } catch (_) {
      // Fallback to generic label.
    }
    return 'الطفل';
  }

  Future<void> _queuePendingRewardEmail({
    required String childId,
    required String childName,
    required PendingReward pendingReward,
  }) async {
    try {
      await _emailNotificationService.queuePendingRewardEmail(
        childId: childId,
        childName: childName,
        rewardType: pendingReward.rewardType,
        description: pendingReward.description,
        coins: pendingReward.coins,
        rewardId: pendingReward.id,
        approvalToken: pendingReward.approvalToken ?? '',
        rejectionToken: pendingReward.rejectionToken ?? '',
        taskId: pendingReward.taskId,
      );
      await _emailNotificationService.flushPendingRewardEmailQueue().timeout(
        const Duration(seconds: 10),
        onTimeout: () =>
            debugPrint('Email flush timed out, will retry in background'),
      );
    } catch (error) {
      // Best-effort notification; failure should not break reward creation.
      debugPrint('Failed to queue pending reward email: $error');
    }
  }

  Future<String> _selectedChildId() async {
    final childId = await _selectedChildService.getSelectedChildId();
    if (childId == null || childId.trim().isEmpty) {
      throw const ChildRewardFailure('الرجاء اختيار الطفل أولًا.');
    }
    return childId.trim();
  }

  DocumentReference<Map<String, dynamic>> _childDocument(String childId) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw const ChildRewardFailure('يجب تسجيل الدخول أولًا.');
    }

    return _firestore
        .collection('users')
        .doc(uid)
        .collection('children')
        .doc(childId);
  }

  Future<MarketPurchaseResult> _purchaseLocally({
    required String childId,
    required String assetPath,
    required bool isAccessory,
    required int purchasePrice,
  }) async {
    final currentWallet = await _getLocalWallet(childId);
    final ownedItems = currentWallet.ownedMarketItemAssetPaths.toSet();
    final purchasedNow = !ownedItems.contains(assetPath);
    if (purchasedNow && currentWallet.coins < purchasePrice) {
      throw const InsufficientCoinsFailure();
    }

    if (purchasedNow) {
      ownedItems.add(assetPath);
    }

    final nextWallet = currentWallet.copyWith(
      coins: purchasedNow
          ? currentWallet.coins - purchasePrice
          : currentWallet.coins,
      ownedMarketItemAssetPaths: ownedItems.toList(growable: false),
      equippedAccessoryAssetPath: isAccessory
          ? assetPath
          : currentWallet.equippedAccessoryAssetPath,
      equippedOutfitAssetPath: isAccessory
          ? currentWallet.equippedOutfitAssetPath
          : assetPath,
    );
    await _saveLocalWallet(childId: childId, wallet: nextWallet);
    return MarketPurchaseResult(wallet: nextWallet, purchasedNow: purchasedNow);
  }

  Future<ChildWalletState> _setEquippedItemLocally({
    required String childId,
    required bool isAccessory,
    required String? assetPath,
  }) async {
    final currentWallet = await _getLocalWallet(childId);
    final ownedItems = currentWallet.ownedMarketItemAssetPaths.toSet();
    if (assetPath != null && !ownedItems.contains(assetPath)) {
      throw const ChildRewardFailure('لا يمكن استخدام هذا العنصر قبل شرائه.');
    }

    final nextWallet = currentWallet.copyWith(
      equippedAccessoryAssetPath: isAccessory
          ? assetPath
          : currentWallet.equippedAccessoryAssetPath,
      clearAccessory: isAccessory && assetPath == null,
      equippedOutfitAssetPath: isAccessory
          ? currentWallet.equippedOutfitAssetPath
          : assetPath,
      clearOutfit: !isAccessory && assetPath == null,
    );
    await _saveLocalWallet(childId: childId, wallet: nextWallet);
    return nextWallet;
  }

  Future<ChildWalletState> _getLocalWallet(String childId) async {
    final localData = await _localStateService.getWalletMap(childId: childId);
    if (localData == null || localData.isEmpty) {
      return const ChildWalletState(
        coins: defaultCoins,
        ownedMarketItemAssetPaths: <String>[],
      );
    }
    return ChildWalletState.fromMap(localData);
  }

  Future<void> _saveLocalWallet({
    required String childId,
    required ChildWalletState wallet,
  }) async {
    await _localStateService.saveWalletMap(
      childId: childId,
      data: wallet.toMap(),
    );
  }

  Future<_RemoteWalletLookupResult> _tryReadRemoteWalletForPendingReuse(
    String childId,
  ) async {
    try {
      final snapshot = await _childDocument(
        childId,
      ).get().timeout(const Duration(seconds: 6));
      if (!snapshot.exists) {
        return const _RemoteWalletLookupResult(
          wasChecked: true,
          wallet: ChildWalletState(
            coins: defaultCoins,
            ownedMarketItemAssetPaths: <String>[],
          ),
        );
      }
      return _RemoteWalletLookupResult(
        wasChecked: true,
        wallet: ChildWalletState.fromDocument(snapshot),
      );
    } catch (_) {
      return const _RemoteWalletLookupResult(wasChecked: false, wallet: null);
    }
  }

  Future<ChildWalletState> _replaceLocalPendingRewardForTask({
    required String childId,
    required ChildWalletState wallet,
    required PendingReward reward,
  }) async {
    final nextRewards = _withoutPendingRewardForTask(
      rewards: wallet.pendingRewards,
      taskId: reward.taskId ?? '',
      rewardType: reward.rewardType,
    )..add(reward);
    final nextWallet = wallet.copyWith(pendingRewards: nextRewards);
    await _saveLocalWallet(childId: childId, wallet: nextWallet);
    return nextWallet;
  }

  Future<ChildWalletState> _removeLocalPendingRewardForTask({
    required String childId,
    required ChildWalletState wallet,
    required String taskId,
    required String rewardType,
  }) async {
    final nextRewards = _withoutPendingRewardForTask(
      rewards: wallet.pendingRewards,
      taskId: taskId,
      rewardType: rewardType,
    );
    if (nextRewards.length == wallet.pendingRewards.length) {
      return wallet;
    }
    final nextWallet = wallet.copyWith(pendingRewards: nextRewards);
    await _saveLocalWallet(childId: childId, wallet: nextWallet);
    return nextWallet;
  }

  List<PendingReward> _withoutPendingRewardForTask({
    required List<PendingReward> rewards,
    required String taskId,
    required String rewardType,
  }) {
    final cleanTaskId = taskId.trim();
    final cleanRewardType = rewardType.trim();
    return rewards
        .where(
          (reward) => !_isPendingRewardForTask(
            reward: reward,
            taskId: cleanTaskId,
            rewardType: cleanRewardType,
          ),
        )
        .toList(growable: true);
  }

  Future<void> _syncPendingWalletIfNeeded(String childId) async {
    if (_walletSyncInFlight.contains(childId)) {
      return;
    }

    final pendingWalletData = await _localStateService.getPendingWalletSyncMap(
      childId: childId,
    );
    if (pendingWalletData == null || pendingWalletData.isEmpty) {
      return;
    }

    _walletSyncInFlight.add(childId);
    try {
      final pendingWallet = ChildWalletState.fromMap(pendingWalletData);
      final remoteSnapshot = await _childDocument(childId).get();
      final remoteWallet = remoteSnapshot.exists
          ? ChildWalletState.fromDocument(remoteSnapshot)
          : const ChildWalletState(
              coins: defaultCoins,
              ownedMarketItemAssetPaths: <String>[],
            );
      final mergedWallet = _mergePendingWalletWithRemote(
        remoteWallet: remoteWallet,
        pendingWallet: pendingWallet,
      );
      await _saveLocalWallet(childId: childId, wallet: mergedWallet);
      await _syncApprovedTaskRewardsLocally(
        childId: childId,
        wallet: mergedWallet,
      );
      await _childDocument(childId).set({
        'coins': mergedWallet.coins,
        'ownedMarketItemAssetPaths': mergedWallet.ownedMarketItemAssetPaths,
        'levelState': mergedWallet.levelState.toMap(),
        'pendingRewards': mergedWallet.pendingRewards
            .map((reward) => reward.toMap())
            .toList(growable: false),
        if (mergedWallet.equippedAccessoryAssetPath != null)
          'equippedAccessoryAssetPath': mergedWallet.equippedAccessoryAssetPath,
        if (mergedWallet.equippedOutfitAssetPath != null)
          'equippedOutfitAssetPath': mergedWallet.equippedOutfitAssetPath,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      final latestPendingWalletData = await _localStateService
          .getPendingWalletSyncMap(childId: childId);
      if (_walletMapsEqual(latestPendingWalletData, pendingWalletData)) {
        await _localStateService.savePendingWalletSyncMap(
          childId: childId,
          data: const <String, dynamic>{},
        );
      }
    } catch (e) {
      if (!_shouldUseLocalFallback(e)) {
        return;
      }
    } finally {
      _walletSyncInFlight.remove(childId);
    }
  }

  void _schedulePendingWalletSyncRetries(String childId) {
    const retryDelays = <Duration>[
      Duration(seconds: 15),
      Duration(seconds: 45),
      Duration(minutes: 2),
    ];
    for (final delay in retryDelays) {
      unawaited(
        Future<void>.delayed(delay, () async {
          await _syncPendingWalletIfNeeded(childId);
        }),
      );
    }
  }

  bool _walletMapsEqual(
    Map<String, dynamic>? first,
    Map<String, dynamic>? second,
  ) {
    if (first == null && second == null) {
      return true;
    }
    if (first == null || second == null) {
      return false;
    }
    return jsonEncode(first) == jsonEncode(second);
  }

  bool _shouldUseLocalFallback(Object e) {
    if (e is FirebaseException) {
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
          normalizedMessage.contains('permission-denied') ||
          normalizedMessage.contains('resource-exhausted') ||
          normalizedMessage.contains('quota') ||
          normalizedMessage.contains('exceeded') ||
          normalizedMessage.contains('cloud firestore api has not been used') ||
          normalizedMessage.contains('deadline exceeded') ||
          normalizedMessage.contains('deadline-exceeded') ||
          normalizedMessage.contains('timeout') ||
          normalizedMessage.contains('timed out') ||
          normalizedMessage.contains('network') ||
          normalizedMessage.contains('unable to resolve host');
    }
    if (e is PlatformException) {
      final message = e.message ?? '';
      return e.code == 'unavailable' ||
          e.code == 'deadline-exceeded' ||
          message.contains('unavailable') ||
          message.contains('deadline exceeded') ||
          message.contains('deadline-exceeded') ||
          message.contains('timed out') ||
          message.contains('Unable to resolve host') ||
          message.contains('network');
    }
    return false;
  }

  String _mapFirebaseError(FirebaseException e) {
    final message = e.message ?? '';
    final normalizedCode = e.code.trim().toLowerCase();
    if (message.contains('Cloud Firestore API has not been used')) {
      return 'خدمة Firestore غير مفعلة في مشروع Firebase. فعّل Firestore Database ثم أعد المحاولة.';
    }

    switch (normalizedCode) {
      case 'permission-denied':
      case 'cloud_firestore/permission-denied':
        return 'ليس لديك صلاحية للوصول إلى قاعدة البيانات. تحقق من قواعد Firestore.';
      case 'unavailable':
      case 'cloud_firestore/unavailable':
        return 'خدمة قاعدة البيانات غير متاحة حاليًا. حاول بعد قليل.';
      case 'resource-exhausted':
      case 'cloud_firestore/resource-exhausted':
        return 'تم تجاوز حصة Firestore الحالية. سيستخدم التطبيق البيانات المحلية ويحاول المزامنة لاحقًا.';
      default:
        return 'تعذر تنفيذ العملية حاليًا. حاول مرة أخرى.';
    }
  }

  /// يراقب بيانات المحفظة للطفل المختار في الوقت الفعلي.
  Stream<ChildWalletState> watchSelectedChildWallet() async* {
    final childId = await _selectedChildId();
    final childDoc = _childDocument(childId);

    yield* childDoc.snapshots().asyncMap((snapshot) async {
      try {
        if (!snapshot.exists) {
          throw const ChildRewardFailure('لم يتم العثور على ملف الطفل المحدد.');
        }
        var wallet = ChildWalletState.fromDocument(snapshot);
        
        // Filter out any rewards that we've already acknowledged in this session
        // but haven't successfully synced back to firestore yet due to network issues.
        if (_acknowledgedRewardIds.isNotEmpty) {
          final filteredRewards = wallet.pendingRewards
              .where((r) => !_acknowledgedRewardIds.contains(r.id))
              .toList(growable: false);
          if (filteredRewards.length != wallet.pendingRewards.length) {
            wallet = wallet.copyWith(pendingRewards: filteredRewards);
          }
        }

        await _saveLocalWallet(childId: childId, wallet: wallet);
        await _syncApprovedTaskRewardsLocally(childId: childId, wallet: wallet);
        return wallet;
      } catch (e, stack) {
        debugPrint('Error in wallet stream mapping: $e\n$stack');
        // Return local wallet as fallback to keep the stream alive
        return _getLocalWallet(childId);
      }
    });
  }

  static final Set<String> _acknowledgedRewardIds = <String>{};

  /// يؤكد رؤية نتيجة المكافأة (موافقة/رفض) ويحذفها من القائمة المعلقة.
  Future<void> acknowledgeRewardResult(String rewardId) async {
    final childId = await _selectedChildId();
    final cleanRewardId = rewardId.trim();
    if (cleanRewardId.isEmpty) {
      return;
    }

    _acknowledgedRewardIds.add(cleanRewardId);

    // Remove locally first so the same decision popup does not reappear
    // whenever the child navigates back to home.
    final localWallet = await _getLocalWallet(childId);
    await _syncApprovedTaskRewardsLocally(
      childId: childId,
      wallet: localWallet,
      rewardIdFilter: cleanRewardId,
    );
    final nextLocalRewards = localWallet.pendingRewards
        .where((reward) => reward.id != cleanRewardId)
        .toList(growable: false);
    if (nextLocalRewards.length == localWallet.pendingRewards.length) {
      return;
    }

    final nextLocalWallet = localWallet.copyWith(
      pendingRewards: nextLocalRewards,
    );
    await _saveLocalWallet(childId: childId, wallet: nextLocalWallet);
    await _localStateService.savePendingWalletSyncMap(
      childId: childId,
      data: nextLocalWallet.toMap(),
    );
    unawaited(_syncPendingWalletIfNeeded(childId));

    final childDoc = _childDocument(childId);
    try {
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(childDoc);
        if (!snapshot.exists) return;

        final currentWallet = ChildWalletState.fromMap(
          snapshot.data() ?? const <String, dynamic>{},
        );

        final updatedRewards = currentWallet.pendingRewards
            .where((reward) => reward.id != cleanRewardId)
            .toList(growable: false);

        if (updatedRewards.length == currentWallet.pendingRewards.length) {
          return;
        }

        final nextWallet = currentWallet.copyWith(
          pendingRewards: updatedRewards,
        );
        transaction.set(childDoc, {
          'pendingRewards': nextWallet.pendingRewards
              .map((reward) => reward.toMap())
              .toList(growable: false),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });

      await _localStateService.savePendingWalletSyncMap(
        childId: childId,
        data: const <String, dynamic>{},
      );
    } catch (e) {
      // Keep local acknowledgement as fallback if remote write fails.
      debugPrint('Error acknowledging reward: $e');
    }
  }

  _RewardApprovalSyncResult _buildRewardApprovalSyncResult({
    required ChildWalletState currentWallet,
    required List<PendingReward> updatedRewards,
    required PendingReward approvedReward,
    required Object? rawTaskProgressHistory,
    required Object? rawDailyTaskProgress,
    required DateTime approvedAt,
  }) {
    final baseWallet = currentWallet.copyWith(pendingRewards: updatedRewards);
    final cleanTaskId = approvedReward.taskId?.trim() ?? '';
    if (approvedReward.rewardType.trim() != 'task_completion' ||
        cleanTaskId.isEmpty) {
      return _RewardApprovalSyncResult(
        wallet: baseWallet.copyWith(
          coins: currentWallet.coins + approvedReward.coins,
        ),
        taskProgressHistory: _taskProgressHistoryFromSources(
          rawTaskProgressHistory: rawTaskProgressHistory,
          rawDailyTaskProgress: rawDailyTaskProgress,
        ),
      );
    }

    final history = _taskProgressHistoryFromSources(
      rawTaskProgressHistory: rawTaskProgressHistory,
      rawDailyTaskProgress: rawDailyTaskProgress,
    );
    final rewardDate = approvedReward.requestedAt;
    final todayKey = _todayKey(rewardDate);
    final currentDailyProgress =
        _normalizedTaskProgressEntry(
          history[todayKey],
          fallbackDateKey: todayKey,
        ) ??
        _emptyTaskProgressEntry(todayKey);
    final completedTaskIds =
        ((currentDailyProgress['completedTaskIds'] as List<dynamic>? ??
                    const <dynamic>[])
                .whereType<String>()
                .map((taskId) => taskId.trim())
                .where((taskId) => taskId.isNotEmpty))
            .toSet();
    if (completedTaskIds.contains(cleanTaskId)) {
      return _RewardApprovalSyncResult(
        wallet: baseWallet,
        taskProgressHistory: history,
        dailyTaskProgress: currentDailyProgress,
      );
    }

    completedTaskIds.add(cleanTaskId);
    final awardedCoinsByTaskId = <String, int>{
      ..._normalizedAwardedCoinsMap(
        currentDailyProgress['awardedCoinsByTaskId'],
      ),
      cleanTaskId: approvedReward.coins,
    };
    final nextTotalTaskCount = max(
      _toNonNegativeInt(
        currentDailyProgress['totalTaskCount'],
        fallback: completedTaskIds.length,
      ),
      completedTaskIds.length,
    );
    final nextDailyProgress = <String, dynamic>{
      'dateKey': todayKey,
      'completedTaskIds': completedTaskIds.toList(growable: false)..sort(),
      'totalTaskCount': nextTotalTaskCount,
      'awardedCoinsByTaskId': awardedCoinsByTaskId,
      'plannedTaskIds': _normalizedPlannedTaskIds(
        currentDailyProgress['plannedTaskIds'],
      ),
      'plannedTaskTitlesById': _normalizedPlannedTaskTitlesById(
        currentDailyProgress['plannedTaskTitlesById'],
        plannedTaskIds: _normalizedPlannedTaskIds(
          currentDailyProgress['plannedTaskIds'],
        ),
      ),
    };
    final nextHistory = _pruneTaskProgressHistory(<String, dynamic>{
      ...history,
      todayKey: nextDailyProgress,
    });
    final nextLevelState = _advanceLevelState(
      currentWallet.levelState,
      fallbackTargetTasks: nextTotalTaskCount,
    );

    return _RewardApprovalSyncResult(
      wallet: baseWallet.copyWith(
        coins: currentWallet.coins + approvedReward.coins,
        levelState: nextLevelState,
      ),
      taskProgressHistory: nextHistory,
      dailyTaskProgress: nextDailyProgress,
    );
  }

  Future<void> _saveLocalTaskProgressState({
    required String childId,
    required Map<String, dynamic> taskProgressHistory,
    Map<String, dynamic>? dailyTaskProgress,
  }) async {
    await _localStateService.saveTaskProgressHistoryMap(
      childId: childId,
      data: taskProgressHistory,
    );
    final latestDailyProgress =
        dailyTaskProgress ??
        _latestDailyProgressFromHistory(taskProgressHistory);
    if (latestDailyProgress != null) {
      await _localStateService.saveDailyTaskProgressMap(
        childId: childId,
        data: latestDailyProgress,
      );
    }
  }

  Future<void> _savePendingTaskProgressSync({
    required String childId,
    required Map<String, dynamic> taskProgressHistory,
  }) async {
    final pendingHistory = _taskProgressHistoryFromSources(
      rawTaskProgressHistory: await _localStateService
          .getPendingTaskProgressSyncMap(childId: childId),
      rawDailyTaskProgress: null,
    );
    final mergedPendingHistory = _pruneTaskProgressHistory(<String, dynamic>{
      ...pendingHistory,
      ...taskProgressHistory,
    });
    await _localStateService.savePendingTaskProgressSyncMap(
      childId: childId,
      data: mergedPendingHistory,
    );
  }

  void _syncProgressHistoryForReports({
    required String childId,
    required Map<String, dynamic> taskProgressHistory,
  }) {
    if (taskProgressHistory.isEmpty) {
      return;
    }
    unawaited(
      _emailNotificationService.syncChildProgressHistory(
        childId: childId,
        progressHistory: taskProgressHistory,
      ).catchError((Object error, StackTrace stackTrace) {
        debugPrint('Failed to sync child progress history for reports: $error');
      }),
    );
  }

  Future<void> _syncApprovedTaskRewardsLocally({
    required String childId,
    required ChildWalletState wallet,
    String? rewardIdFilter,
  }) async {
    final approvedTaskRewards = wallet.pendingRewards
        .where((reward) {
          if (reward.status != PendingRewardStatus.approved) {
            return false;
          }
          if (reward.rewardType.trim() != 'task_completion') {
            return false;
          }
          final cleanTaskId = reward.taskId?.trim() ?? '';
          if (cleanTaskId.isEmpty) {
            return false;
          }
          if (rewardIdFilter != null && reward.id != rewardIdFilter) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
    if (approvedTaskRewards.isEmpty) {
      return;
    }

    final currentHistory = _taskProgressHistoryFromSources(
      rawTaskProgressHistory: await _localStateService
          .getTaskProgressHistoryMap(childId: childId),
      rawDailyTaskProgress: await _localStateService.getDailyTaskProgressMap(
        childId: childId,
      ),
    );
    var nextHistory = currentHistory;
    var didChange = false;

    for (final reward in approvedTaskRewards) {
      final taskId = reward.taskId!.trim();
      final rewardDate = reward.requestedAt;
      final dateKey = _todayKey(rewardDate);
      final currentDailyProgress =
          _normalizedTaskProgressEntry(
            nextHistory[dateKey],
            fallbackDateKey: dateKey,
          ) ??
          _emptyTaskProgressEntry(dateKey);
      final completedTaskIds =
          ((currentDailyProgress['completedTaskIds'] as List<dynamic>? ??
                      const <dynamic>[])
                  .whereType<String>()
                  .map((taskId) => taskId.trim())
                  .where((taskId) => taskId.isNotEmpty))
              .toSet();
      if (completedTaskIds.contains(taskId)) {
        continue;
      }

      completedTaskIds.add(taskId);
      final nextDailyProgress = <String, dynamic>{
        'dateKey': dateKey,
        'completedTaskIds': completedTaskIds.toList(growable: false)..sort(),
        'totalTaskCount': max(
          _toNonNegativeInt(
            currentDailyProgress['totalTaskCount'],
            fallback: completedTaskIds.length,
          ),
          completedTaskIds.length,
        ),
        'awardedCoinsByTaskId': <String, int>{
          ..._normalizedAwardedCoinsMap(
            currentDailyProgress['awardedCoinsByTaskId'],
          ),
          taskId: reward.coins,
        },
        'plannedTaskIds': _normalizedPlannedTaskIds(
          currentDailyProgress['plannedTaskIds'],
        ),
        'plannedTaskTitlesById': _normalizedPlannedTaskTitlesById(
          currentDailyProgress['plannedTaskTitlesById'],
          plannedTaskIds: _normalizedPlannedTaskIds(
            currentDailyProgress['plannedTaskIds'],
          ),
        ),
      };
      nextHistory = _pruneTaskProgressHistory(<String, dynamic>{
        ...nextHistory,
        dateKey: nextDailyProgress,
      });
      didChange = true;
    }

    if (!didChange) {
      return;
    }

    await _saveLocalTaskProgressState(
      childId: childId,
      taskProgressHistory: nextHistory,
      dailyTaskProgress: _latestDailyProgressFromHistory(nextHistory),
    );
  }

  Map<String, dynamic> _taskProgressHistoryFromSources({
    required Object? rawTaskProgressHistory,
    required Object? rawDailyTaskProgress,
  }) {
    final history = _normalizedTaskProgressHistory(rawTaskProgressHistory);
    final legacyDailyProgress = _normalizedTaskProgressEntry(
      rawDailyTaskProgress,
    );
    if (legacyDailyProgress != null) {
      final dateKey = legacyDailyProgress['dateKey'] as String;
      history[dateKey] = _mergeTaskProgressEntries(
        history[dateKey],
        legacyDailyProgress,
      );
    }
    return _pruneTaskProgressHistory(history);
  }

  Map<String, dynamic> _normalizedTaskProgressHistory(
    Object? rawTaskProgressHistory,
  ) {
    if (rawTaskProgressHistory is! Map) {
      return <String, dynamic>{};
    }

    final history = <String, dynamic>{};
    for (final entry in rawTaskProgressHistory.entries) {
      final dateKey = entry.key.toString().trim();
      if (!_isValidDateKey(dateKey)) {
        continue;
      }
      final normalizedEntry = _normalizedTaskProgressEntry(
        entry.value,
        fallbackDateKey: dateKey,
      );
      if (normalizedEntry == null) {
        continue;
      }
      history[dateKey] = normalizedEntry;
    }
    return _pruneTaskProgressHistory(history);
  }

  Map<String, dynamic>? _normalizedTaskProgressEntry(
    Object? rawTaskProgress, {
    String? fallbackDateKey,
  }) {
    if (rawTaskProgress is! Map) {
      return null;
    }
    final data = rawTaskProgress.map(
      (key, value) => MapEntry(key.toString(), value),
    );
    final dateKey = (data['dateKey'] as String? ?? fallbackDateKey ?? '')
        .trim();
    if (!_isValidDateKey(dateKey)) {
      return null;
    }
    final completedTaskIds =
        ((data['completedTaskIds'] as Iterable<dynamic>? ?? const <dynamic>[])
                .whereType<String>()
                .map((taskId) => taskId.trim())
                .where((taskId) => taskId.isNotEmpty))
            .toSet()
            .toList(growable: false)
          ..sort();
    final totalTaskCount = max(
      max(
        _toNonNegativeInt(
          data['totalTaskCount'],
          fallback: completedTaskIds.length,
        ),
        _normalizedPlannedTaskIds(data['plannedTaskIds']).length,
      ),
      completedTaskIds.length,
    );
    final plannedTaskIds = _normalizedPlannedTaskIds(data['plannedTaskIds']);
    return <String, dynamic>{
      'dateKey': dateKey,
      'completedTaskIds': completedTaskIds,
      'totalTaskCount': totalTaskCount,
      'awardedCoinsByTaskId': _normalizedAwardedCoinsMap(
        data['awardedCoinsByTaskId'],
        completedTaskIds: completedTaskIds,
      ),
      'plannedTaskIds': plannedTaskIds,
      'plannedTaskTitlesById': _normalizedPlannedTaskTitlesById(
        data['plannedTaskTitlesById'],
        plannedTaskIds: plannedTaskIds,
      ),
    };
  }

  Map<String, int> _normalizedAwardedCoinsMap(
    Object? rawAwardedCoinsMap, {
    List<String>? completedTaskIds,
  }) {
    if (rawAwardedCoinsMap is! Map) {
      return <String, int>{};
    }
    final completedSet = (completedTaskIds ?? const <String>[]).toSet();
    final awardedCoinsByTaskId = <String, int>{};
    for (final entry in rawAwardedCoinsMap.entries) {
      final taskId = entry.key.toString().trim();
      if (taskId.isEmpty) {
        continue;
      }
      if (completedSet.isNotEmpty && !completedSet.contains(taskId)) {
        continue;
      }
      awardedCoinsByTaskId[taskId] = _toNonNegativeInt(
        entry.value,
        fallback: 0,
      );
    }
    return awardedCoinsByTaskId;
  }

  Map<String, dynamic> _mergeTaskProgressEntries(
    Object? primaryRaw,
    Map<String, dynamic> secondary,
  ) {
    final primary =
        _normalizedTaskProgressEntry(
          primaryRaw,
          fallbackDateKey: secondary['dateKey'] as String,
        ) ??
        _emptyTaskProgressEntry(secondary['dateKey'] as String);
    final mergedTaskIds =
        ((primary['completedTaskIds'] as List<dynamic>? ?? const <dynamic>[])
                .whereType<String>()
                .map((taskId) => taskId.trim())
                .where((taskId) => taskId.isNotEmpty))
            .toSet()
          ..addAll(
            (secondary['completedTaskIds'] as List<dynamic>? ??
                    const <dynamic>[])
                .whereType<String>()
                .map((taskId) => taskId.trim())
                .where((taskId) => taskId.isNotEmpty),
          );
    final mergedTaskIdsList = mergedTaskIds.toList(growable: false)..sort();
    final mergedPlannedTaskIds = <String>{
      ..._normalizedPlannedTaskIds(primary['plannedTaskIds']),
      ..._normalizedPlannedTaskIds(secondary['plannedTaskIds']),
    }.toList(growable: false)..sort();
    return <String, dynamic>{
      'dateKey': secondary['dateKey'],
      'completedTaskIds': mergedTaskIdsList,
      'totalTaskCount': max(
        max(
          _toNonNegativeInt(
            primary['totalTaskCount'],
            fallback: mergedTaskIdsList.length,
          ),
          _toNonNegativeInt(
            secondary['totalTaskCount'],
            fallback: mergedTaskIdsList.length,
          ),
        ),
        mergedPlannedTaskIds.length,
      ),
      'awardedCoinsByTaskId': <String, int>{
        ..._normalizedAwardedCoinsMap(
          primary['awardedCoinsByTaskId'],
          completedTaskIds: mergedTaskIdsList,
        ),
        ..._normalizedAwardedCoinsMap(
          secondary['awardedCoinsByTaskId'],
          completedTaskIds: mergedTaskIdsList,
        ),
      },
      'plannedTaskIds': mergedPlannedTaskIds,
      'plannedTaskTitlesById': <String, String>{
        ..._normalizedPlannedTaskTitlesById(
          primary['plannedTaskTitlesById'],
          plannedTaskIds: mergedPlannedTaskIds,
        ),
        ..._normalizedPlannedTaskTitlesById(
          secondary['plannedTaskTitlesById'],
          plannedTaskIds: mergedPlannedTaskIds,
        ),
      },
    };
  }

  Map<String, dynamic> _pruneTaskProgressHistory(Map<String, dynamic> history) {
    final sortedKeys = history.keys.toList(growable: false)
      ..sort((a, b) => b.compareTo(a));
    final retainedKeys = sortedKeys.take(90).toSet();
    final prunedHistory = <String, dynamic>{};
    for (final dateKey in sortedKeys.reversed) {
      if (retainedKeys.contains(dateKey)) {
        prunedHistory[dateKey] = history[dateKey];
      }
    }
    return prunedHistory;
  }

  Map<String, dynamic>? _latestDailyProgressFromHistory(
    Map<String, dynamic> history,
  ) {
    if (history.isEmpty) {
      return null;
    }
    final latestKey = history.keys.reduce(
      (a, b) => a.compareTo(b) >= 0 ? a : b,
    );
    final latestEntry = history[latestKey];
    return latestEntry is Map<String, dynamic>
        ? latestEntry
        : latestEntry is Map
        ? latestEntry.map((key, value) => MapEntry(key.toString(), value))
        : null;
  }

  Map<String, dynamic> _emptyTaskProgressEntry(String dateKey) {
    return <String, dynamic>{
      'dateKey': dateKey,
      'completedTaskIds': const <String>[],
      'totalTaskCount': 0,
      'awardedCoinsByTaskId': const <String, int>{},
      'plannedTaskIds': const <String>[],
      'plannedTaskTitlesById': const <String, String>{},
    };
  }

  List<String> _normalizedPlannedTaskIds(Object? rawPlannedTaskIds) {
    final plannedTaskIds =
        ((rawPlannedTaskIds as Iterable<dynamic>? ?? const <dynamic>[])
                .whereType<String>()
                .map((taskId) => taskId.trim())
                .where((taskId) => taskId.isNotEmpty))
            .toSet()
            .toList(growable: false)
          ..sort();
    return plannedTaskIds;
  }

  Map<String, String> _normalizedPlannedTaskTitlesById(
    Object? rawPlannedTaskTitlesById, {
    required List<String> plannedTaskIds,
  }) {
    if (rawPlannedTaskTitlesById is! Map) {
      return <String, String>{};
    }
    final plannedTaskIdSet = plannedTaskIds.toSet();
    final plannedTaskTitlesById = <String, String>{};
    for (final entry in rawPlannedTaskTitlesById.entries) {
      final taskId = entry.key.toString().trim();
      final title = entry.value.toString().trim();
      if (!plannedTaskIdSet.contains(taskId) || title.isEmpty) {
        continue;
      }
      plannedTaskTitlesById[taskId] = title;
    }
    return plannedTaskTitlesById;
  }

  ChildWalletState _mergePendingWalletWithRemote({
    required ChildWalletState remoteWallet,
    required ChildWalletState pendingWallet,
  }) {
    final pendingRewardsById = <String, PendingReward>{
      for (final reward in pendingWallet.pendingRewards) reward.id: reward,
    };
    final mergedRewards = <PendingReward>[];

    for (final remoteReward in remoteWallet.pendingRewards) {
      final pendingReward = pendingRewardsById.remove(remoteReward.id);
      if (pendingReward != null) {
        mergedRewards.add(_preferNewerRewardState(remoteReward, pendingReward));
        continue;
      }
      if (_acknowledgedRewardIds.contains(remoteReward.id)) {
        continue; // Do not resurrect rewards we've already acknowledged!
      }
      // Include all rewards (pending, approved, rejected) so the UI can react to them
      mergedRewards.add(remoteReward);
    }

    mergedRewards.addAll(pendingRewardsById.values);
    final mergedLevelState = _preferMergedLevelState(
      remoteWallet: remoteWallet,
      pendingWallet: pendingWallet,
    );

    return ChildWalletState(
      coins: max(remoteWallet.coins, pendingWallet.coins),
      ownedMarketItemAssetPaths: <String>{
        ...remoteWallet.ownedMarketItemAssetPaths,
        ...pendingWallet.ownedMarketItemAssetPaths,
      }.toList(growable: false),
      levelState: mergedLevelState,
      equippedAccessoryAssetPath:
          pendingWallet.equippedAccessoryAssetPath ??
          remoteWallet.equippedAccessoryAssetPath,
      equippedOutfitAssetPath:
          pendingWallet.equippedOutfitAssetPath ??
          remoteWallet.equippedOutfitAssetPath,
      pendingRewards: mergedRewards,
    );
  }

  ChildLevelState _preferMergedLevelState({
    required ChildWalletState remoteWallet,
    required ChildWalletState pendingWallet,
  }) {
    final pendingLevelState = pendingWallet.levelState;
    final remoteLevelState = remoteWallet.levelState;
    final sameLevelProgress =
        pendingLevelState.level == remoteLevelState.level &&
        pendingLevelState.progressTasks == remoteLevelState.progressTasks &&
        pendingLevelState.targetTasks == remoteLevelState.targetTasks;
    final localLooksLikeClaimedLevelReward =
        pendingWallet.coins > remoteWallet.coins &&
        pendingLevelState.pendingRewardLevels.length <
            remoteLevelState.pendingRewardLevels.length;
    if (sameLevelProgress && localLooksLikeClaimedLevelReward) {
      return pendingLevelState;
    }

    return _preferNewerLevelState(
      primary: pendingLevelState,
      secondary: remoteLevelState,
    );
  }

  PendingReward _preferNewerRewardState(
    PendingReward first,
    PendingReward second,
  ) {
    if (first.status != second.status) {
      if (first.status == PendingRewardStatus.pending) {
        return second;
      }
      if (second.status == PendingRewardStatus.pending) {
        return first;
      }
    }

    final firstDecisionAt =
        first.approvedAt ?? first.rejectedAt ?? first.requestedAt;
    final secondDecisionAt =
        second.approvedAt ?? second.rejectedAt ?? second.requestedAt;
    return secondDecisionAt.isAfter(firstDecisionAt) ? second : first;
  }

  ChildLevelState _advanceLevelState(
    ChildLevelState currentLevelState, {
    required int fallbackTargetTasks,
  }) {
    final normalizedLevelState = _normalizeLevelState(
      currentLevelState,
      fallbackTargetTasks: fallbackTargetTasks,
    );
    var nextLevel = normalizedLevelState.level;
    var nextProgressTasks = normalizedLevelState.progressTasks + 1;
    var nextTargetTasks = normalizedLevelState.targetTasks;
    final nextPendingLevels = List<int>.from(
      normalizedLevelState.pendingRewardLevels,
    );

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

  ChildLevelState _normalizeLevelState(
    ChildLevelState levelState, {
    required int fallbackTargetTasks,
  }) {
    final safeFallbackTarget = fallbackTargetTasks < 1
        ? 1
        : fallbackTargetTasks;
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
      progressTasks: levelState.progressTasks < 0
          ? 0
          : levelState.progressTasks,
      targetTasks: safeFallbackTarget,
      pendingRewardLevels: levelState.pendingRewardLevels,
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
    if (primary.pendingRewardLevels.length !=
        secondary.pendingRewardLevels.length) {
      return primary.pendingRewardLevels.length >
              secondary.pendingRewardLevels.length
          ? primary
          : secondary;
    }
    return primary.targetTasks >= secondary.targetTasks ? primary : secondary;
  }

  int _nextLevelTarget(int currentTarget) {
    final safeTarget = currentTarget < 1 ? 1 : currentTarget;
    return ((safeTarget * 4) / 3).ceil();
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

  int _toNonNegativeInt(Object? value, {required int fallback}) {
    final parsed = parseIntegerValue(value, fallback: fallback);
    return parsed < 0 ? fallback : parsed;
  }
}

class MarketPurchaseResult {
  const MarketPurchaseResult({
    required this.wallet,
    required this.purchasedNow,
  });

  final ChildWalletState wallet;
  final bool purchasedNow;
}

class ChildRewardFailure implements Exception {
  const ChildRewardFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

class InsufficientCoinsFailure extends ChildRewardFailure {
  const InsufficientCoinsFailure() : super('لا توجد نقاط كافية لإتمام الشراء.');
}
