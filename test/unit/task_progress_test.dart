/// R4 / R5 / R9 / R10 / R11 – Task Progress Unit Tests
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:risha_v01/shared/services/child_task_progress_service.dart';

void main() {
  // ── ChildTaskIds ──
  group('ChildTaskIds (R4/R9/R10)', () {
    test('quran-reading is supported', () {
      expect(ChildTaskIds.isSupported('quran-reading'), isTrue);
    });

    test('shape-matching (puzzle) is supported', () {
      expect(ChildTaskIds.isSupported('shape-matching'), isTrue);
    });

    test('brush-time-morning is supported', () {
      expect(ChildTaskIds.isSupported('brush-time-morning'), isTrue);
    });

    test('water-drink-slot-1 is supported', () {
      expect(ChildTaskIds.isSupported('water-drink-slot-1'), isTrue);
    });

    test('exercising-slot-3 is supported', () {
      expect(ChildTaskIds.isSupported('exercising-slot-3'), isTrue);
    });

    test('custom behavior slot is supported', () {
      final taskId = ChildTaskIds.customBehaviorSlot('custom_123', 1);
      expect(ChildTaskIds.isSupported(taskId), isTrue);
    });

    test('unknown task id is not supported', () {
      expect(ChildTaskIds.isSupported('flying-lesson'), isFalse);
    });

    test('FAIL case: empty string is not supported', () {
      expect(ChildTaskIds.isSupported(''), isFalse);
    });

    test('water drink slot clamps to valid range', () {
      expect(ChildTaskIds.waterDrinkSlot(0), 'water-drink-slot-1');
      expect(ChildTaskIds.waterDrinkSlot(99), 'water-drink-slot-12');
    });
  });

  // ── ChildDailyTaskProgress ──
  group('ChildDailyTaskProgress (R5/R11)', () {
    test('isCompleted returns true for completed task', () {
      const progress = ChildDailyTaskProgress(
        dateKey: '2026-05-05',
        completedTaskIds: {'quran-reading', 'brush-time'},
        totalTaskCount: 5,
      );
      expect(progress.isCompleted('quran-reading'), isTrue);
      expect(progress.isCompleted('shape-matching'), isFalse);
    });

    test('completedTaskCount reflects set size', () {
      const progress = ChildDailyTaskProgress(
        dateKey: '2026-05-05',
        completedTaskIds: {'quran-reading', 'brush-time', 'water-drink'},
        totalTaskCount: 6,
      );
      expect(progress.completedTaskCount, 3);
    });

    test('remainingTaskCount is correct', () {
      const progress = ChildDailyTaskProgress(
        dateKey: '2026-05-05',
        completedTaskIds: {'quran-reading'},
        totalTaskCount: 5,
      );
      expect(progress.remainingTaskCount, 4);
    });

    test('remainingTaskCount never goes negative', () {
      const progress = ChildDailyTaskProgress(
        dateKey: '2026-05-05',
        completedTaskIds: {'a', 'b', 'c'},
        totalTaskCount: 2,
      );
      expect(progress.remainingTaskCount, 0);
    });

    test('completionRatio is correct', () {
      const progress = ChildDailyTaskProgress(
        dateKey: '2026-05-05',
        completedTaskIds: {'a', 'b'},
        totalTaskCount: 4,
      );
      expect(progress.completionRatio, closeTo(0.5, 0.001));
    });

    test('completionRatio is 0 when totalTaskCount is 0', () {
      const progress = ChildDailyTaskProgress(
        dateKey: '2026-05-05',
        completedTaskIds: {},
        totalTaskCount: 0,
      );
      expect(progress.completionRatio, 0);
    });

    test('toMap serializes correctly', () {
      const progress = ChildDailyTaskProgress(
        dateKey: '2026-05-05',
        completedTaskIds: {'quran-reading'},
        totalTaskCount: 3,
        awardedCoinsByTaskId: {'quran-reading': 5},
      );
      final map = progress.toMap();
      expect(map['dateKey'], '2026-05-05');
      expect(map['totalTaskCount'], 3);
      expect((map['completedTaskIds'] as List), contains('quran-reading'));
      expect((map['awardedCoinsByTaskId'] as Map)['quran-reading'], 5);
    });

    test('copyWith overrides only specified fields', () {
      const progress = ChildDailyTaskProgress(
        dateKey: '2026-05-05',
        completedTaskIds: {'a'},
        totalTaskCount: 3,
      );
      final updated = progress.copyWith(totalTaskCount: 6);
      expect(updated.totalTaskCount, 6);
      expect(updated.completedTaskIds, {'a'});
      expect(updated.dateKey, '2026-05-05');
    });
  });

  // ── ChildWeeklyTaskProgress ──
  group('ChildWeeklyTaskProgress (R11)', () {
    test('hasRecordedData is true when any day has tasks', () {
      const weekly = ChildWeeklyTaskProgress(
        days: [
          ChildDailyTaskProgress(
            dateKey: '2026-05-01',
            completedTaskIds: {},
            totalTaskCount: 0,
          ),
          ChildDailyTaskProgress(
            dateKey: '2026-05-02',
            completedTaskIds: {'a'},
            totalTaskCount: 3,
          ),
        ],
      );
      expect(weekly.hasRecordedData, isTrue);
    });

    test('hasRecordedData is false when all days are empty', () {
      const weekly = ChildWeeklyTaskProgress(
        days: [
          ChildDailyTaskProgress(
            dateKey: '2026-05-01',
            completedTaskIds: {},
            totalTaskCount: 0,
          ),
        ],
      );
      expect(weekly.hasRecordedData, isFalse);
    });
  });
}
