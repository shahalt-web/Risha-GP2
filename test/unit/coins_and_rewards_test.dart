/// R5 / R6 – Coins & Reward Business Logic Unit Tests
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:risha_v01/shared/services/child_reward_service.dart';

void main() {
  // ── Coin Parsing ──
  group('parseCoinsValue (R5)', () {
    test('returns int value as-is', () {
      final input = 100;
      debugPrint(
        '🔍 فحص العملات: [المدخلات: $input (int)] -> [النتيجة المتوقعة: $input]',
      );
      final result = ChildRewardService.parseCoinsValue(input);
      expect(result, 100);
      debugPrint('✅ النتيجة: تم إرجاع القيمة 100 بنجاح.');
    });

    test('truncates double to int', () {
      final input = 99.7;
      debugPrint(
        '🔍 فحص العملات: [المدخلات: $input (double)] -> [النتيجة المتوقعة: 99]',
      );
      final result = ChildRewardService.parseCoinsValue(input);
      expect(result, 99);
      debugPrint('✅ النتيجة: تم تقريب القيمة إلى 99 بنجاح.');
    });

    test('returns default when value is null', () {
      expect(
        ChildRewardService.parseCoinsValue(null),
        ChildRewardService.defaultCoins,
      );
    });

    test('FAIL case: string "50" is NOT parsed – returns default', () {
      expect(
        ChildRewardService.parseCoinsValue('50'),
        ChildRewardService.defaultCoins,
      );
    });
  });

  // ── Integer Parsing ──
  group('parseIntegerValue (R5)', () {
    test('returns int value directly', () {
      expect(ChildRewardService.parseIntegerValue(42, fallback: 0), 42);
    });

    test('parses valid numeric string', () {
      expect(ChildRewardService.parseIntegerValue('10', fallback: 0), 10);
    });

    test('returns fallback for unparseable string', () {
      expect(ChildRewardService.parseIntegerValue('xyz', fallback: -1), -1);
    });

    test('returns fallback for null', () {
      expect(ChildRewardService.parseIntegerValue(null, fallback: 5), 5);
    });
  });

  // ── Level Target Parsing ──
  group('parseLevelTargetValue (R5)', () {
    test('returns parsed value when > 0', () {
      expect(ChildRewardService.parseLevelTargetValue(7, fallback: 1), 7);
    });

    test('returns fallback when parsed value is 0', () {
      expect(ChildRewardService.parseLevelTargetValue(0, fallback: 3), 3);
    });

    test('FAIL case: fallback < 1 defaults to 1', () {
      expect(ChildRewardService.parseLevelTargetValue(0, fallback: 0), 1);
    });
  });

  // ── ChildLevelState ──
  group('ChildLevelState (R5)', () {
    test('defaults() creates level 0 with the given target', () {
      final state = ChildLevelState.defaults(targetTasks: 5);
      expect(state.level, 0);
      expect(state.progressTasks, 0);
      expect(state.targetTasks, 5);
      expect(state.hasPendingReward, isFalse);
    });

    test('progressRatio correct for partial completion', () {
      const progress = 3;
      const target = 6;
      debugPrint(
        '🔍 فحص نسبة التقدم: [المهام المكتملة: $progress] [الهدف: $target] -> [النتيجة المتوقعة: 0.5]',
      );
      const state = ChildLevelState(
        level: 1,
        progressTasks: progress,
        targetTasks: target,
      );
      expect(state.progressRatio, closeTo(0.5, 0.001));
      debugPrint('✅ النتيجة: تم حساب نسبة التقدم 50% بنجاح.');
    });

    test('progressRatio is 0 when targetTasks <= 0', () {
      const state = ChildLevelState(level: 0, progressTasks: 5, targetTasks: 0);
      expect(state.progressRatio, 0);
    });

    test('toMap/fromMap round-trips correctly', () {
      const original = ChildLevelState(
        level: 3,
        progressTasks: 2,
        targetTasks: 5,
        pendingRewardLevels: [3],
      );
      final restored = ChildLevelState.fromMap(original.toMap());
      expect(restored.level, original.level);
      expect(restored.targetTasks, original.targetTasks);
      expect(restored.pendingRewardLevels, original.pendingRewardLevels);
    });

    test('toMap clamps negative values', () {
      const state = ChildLevelState(
        level: -1,
        progressTasks: -5,
        targetTasks: -3,
      );
      final map = state.toMap();
      expect(map['level'], 0);
      expect(map['progressTasks'], 0);
      expect(map['targetTasks'], 1);
    });
  });

  // ── ChildWalletState ──
  group('ChildWalletState (R5/R6)', () {
    test('fromMap constructs wallet with correct coin balance', () {
      final wallet = ChildWalletState.fromMap({
        'coins': 150,
        'ownedMarketItemAssetPaths': ['hat_01', 'shirt_02'],
      });
      expect(wallet.coins, 150);
      expect(wallet.ownedMarketItemAssetPaths, hasLength(2));
    });

    test('fromMap handles missing coins gracefully', () {
      final wallet = ChildWalletState.fromMap({});
      expect(wallet.coins, ChildRewardService.defaultCoins);
    });

    test('copyWith updates coins only', () {
      final wallet = ChildWalletState.fromMap({'coins': 50});
      final updated = wallet.copyWith(coins: 100);
      expect(updated.coins, 100);
    });
  });

  // ── PendingReward ──
  group('PendingReward (R6)', () {
    test('fromMap constructs with all fields', () {
      final now = DateTime.now();
      final reward = PendingReward.fromMap({
        'id': 'rw-001',
        'rewardType': 'task_completion',
        'description': 'حفظ القرآن',
        'coins': 10,
        'requestedAt': now.toIso8601String(),
        'status': 'pending',
        'taskId': 'quran-reading',
      });
      expect(reward.id, 'rw-001');
      expect(reward.coins, 10);
      expect(reward.status, PendingRewardStatus.pending);
    });

    test('FAIL case: missing id defaults to empty string', () {
      final reward = PendingReward.fromMap({
        'rewardType': 'bonus',
        'description': 'مكافأة',
        'coins': 5,
        'requestedAt': DateTime.now().toIso8601String(),
      });
      expect(reward.id, isEmpty);
    });
  });

  // ── Token Generation ──
  group('generatePendingRewardActionToken (R7)', () {
    test('generates token of requested length', () {
      final token = ChildRewardService.generatePendingRewardActionToken(16);
      expect(token.length, 16);
    });

    test('generates unique tokens', () {
      final a = ChildRewardService.generatePendingRewardActionToken();
      final b = ChildRewardService.generatePendingRewardActionToken();
      expect(a, isNot(equals(b)));
    });

    test('default length is 32', () {
      expect(ChildRewardService.generatePendingRewardActionToken().length, 32);
    });
  });
}
