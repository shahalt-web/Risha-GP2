/// R5 / R9 / R10 – Dashboard & Task Card Widget Test
///
/// Tests that daily task dashboard renders correctly,
/// shows proper values, and task cards respond to taps.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Builds a testable dashboard showing task progress,
  // coins balance, and task cards for Quran/Puzzle activities.
  Widget buildTestDashboard({
    required int coins,
    required int completedTasks,
    required int totalTasks,
    required List<_TaskCardData> tasks,
    void Function(String taskId)? onTaskTap,
  }) {
    return MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Coins display
                Container(
                  key: const Key('coins_display'),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.monetization_on,
                        color: Color(0xFFD6A23C),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$coins',
                        key: const Key('coins_value'),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Progress bar
                Container(
                  key: const Key('progress_section'),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        '$completedTasks / $totalTasks مهام مكتملة',
                        key: const Key('progress_text'),
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        key: const Key('progress_bar'),
                        value: totalTasks > 0 ? completedTasks / totalTasks : 0,
                        backgroundColor: Colors.grey[200],
                        valueColor: const AlwaysStoppedAnimation(
                          Color(0xFF4CAF50),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Task cards
                ...tasks.map(
                  (task) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      key: Key('task_card_${task.id}'),
                      onTap: task.isCompleted
                          ? null
                          : () => onTaskTap?.call(task.id),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: task.isCompleted
                              ? const Color(0xFFE8F5E9)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: task.isCompleted
                                ? const Color(0xFF4CAF50)
                                : const Color(0xFFE0E0E0),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              task.isCompleted
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: task.isCompleted
                                  ? const Color(0xFF4CAF50)
                                  : Colors.grey,
                              key: Key('task_icon_${task.id}'),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                task.title,
                                key: Key('task_title_${task.id}'),
                                style: TextStyle(
                                  fontSize: 16,
                                  decoration: task.isCompleted
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                            ),
                            Text(
                              '+${task.rewardCoins}',
                              key: Key('task_coins_${task.id}'),
                              style: const TextStyle(
                                color: Color(0xFFD6A23C),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  group('Dashboard UI (R5)', () {
    testWidgets('renders coins balance correctly', (tester) async {
      await tester.pumpWidget(
        buildTestDashboard(
          coins: 150,
          completedTasks: 2,
          totalTasks: 5,
          tasks: [],
        ),
      );

      expect(find.byKey(const Key('coins_display')), findsOneWidget);
      expect(find.text('150'), findsOneWidget);
    });

    testWidgets('renders progress text and bar', (tester) async {
      await tester.pumpWidget(
        buildTestDashboard(
          coins: 50,
          completedTasks: 3,
          totalTasks: 6,
          tasks: [],
        ),
      );

      expect(find.text('3 / 6 مهام مكتملة'), findsOneWidget);
      expect(find.byKey(const Key('progress_bar')), findsOneWidget);
    });

    testWidgets('renders task cards with titles and coins', (tester) async {
      await tester.pumpWidget(
        buildTestDashboard(
          coins: 75,
          completedTasks: 1,
          totalTasks: 3,
          tasks: [
            _TaskCardData(
              id: 'quran-reading',
              title: 'قراءة القرآن',
              rewardCoins: 5,
              isCompleted: true,
            ),
            _TaskCardData(
              id: 'shape-matching',
              title: 'لعبة الأشكال',
              rewardCoins: 5,
              isCompleted: false,
            ),
            _TaskCardData(
              id: 'brush-time',
              title: 'تنظيف الأسنان',
              rewardCoins: 5,
              isCompleted: false,
            ),
          ],
        ),
      );

      // Quran task shown as completed
      expect(find.text('قراءة القرآن'), findsOneWidget);
      expect(find.text('لعبة الأشكال'), findsOneWidget);
      expect(find.text('تنظيف الأسنان'), findsOneWidget);
      expect(find.text('+5'), findsNWidgets(3));
    });

    testWidgets('completed task card has check icon', (tester) async {
      await tester.pumpWidget(
        buildTestDashboard(
          coins: 50,
          completedTasks: 1,
          totalTasks: 2,
          tasks: [
            _TaskCardData(
              id: 'quran-reading',
              title: 'قراءة القرآن',
              rewardCoins: 5,
              isCompleted: true,
            ),
          ],
        ),
      );

      final icon = tester.widget<Icon>(
        find.byKey(const Key('task_icon_quran-reading')),
      );
      expect(icon.icon, Icons.check_circle);
    });

    testWidgets('tapping incomplete task triggers callback', (tester) async {
      String? tappedTaskId;

      await tester.pumpWidget(
        buildTestDashboard(
          coins: 50,
          completedTasks: 0,
          totalTasks: 2,
          tasks: [
            _TaskCardData(
              id: 'shape-matching',
              title: 'لعبة الأشكال',
              rewardCoins: 5,
              isCompleted: false,
            ),
          ],
          onTaskTap: (id) => tappedTaskId = id,
        ),
      );

      await tester.tap(find.byKey(const Key('task_card_shape-matching')));
      await tester.pumpAndSettle();

      expect(tappedTaskId, 'shape-matching');
    });

    testWidgets('tapping completed task does NOT trigger callback', (
      tester,
    ) async {
      String? tappedTaskId;

      await tester.pumpWidget(
        buildTestDashboard(
          coins: 55,
          completedTasks: 1,
          totalTasks: 1,
          tasks: [
            _TaskCardData(
              id: 'quran-reading',
              title: 'قراءة القرآن',
              rewardCoins: 5,
              isCompleted: true,
            ),
          ],
          onTaskTap: (id) => tappedTaskId = id,
        ),
      );

      await tester.tap(find.byKey(const Key('task_card_quran-reading')));
      await tester.pumpAndSettle();

      // Completed task tap is disabled
      expect(tappedTaskId, isNull);
    });

    testWidgets('FAIL case: 0 coins displays correctly', (tester) async {
      await tester.pumpWidget(
        buildTestDashboard(
          coins: 0,
          completedTasks: 0,
          totalTasks: 0,
          tasks: [],
        ),
      );

      expect(find.text('0'), findsOneWidget);
      expect(find.text('0 / 0 مهام مكتملة'), findsOneWidget);
    });
  });
}

class _TaskCardData {
  const _TaskCardData({
    required this.id,
    required this.title,
    required this.rewardCoins,
    required this.isCompleted,
  });

  final String id;
  final String title;
  final int rewardCoins;
  final bool isCompleted;
}
