import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:risha_v01/shared/services/child_behavior_service.dart';
import 'package:risha_v01/shared/services/local_notification_service.dart';
import 'package:risha_v01/shared/services/selected_child_service.dart';
import 'package:risha_v01/shared/services/session_progress_service.dart';

class ChildSetupPreparingScreen extends StatefulWidget {
  const ChildSetupPreparingScreen({super.key});

  @override
  State<ChildSetupPreparingScreen> createState() =>
      _ChildSetupPreparingScreenState();
}

class _ChildSetupPreparingScreenState extends State<ChildSetupPreparingScreen> {
  final _sessionProgressService = SessionProgressService();
  final _selectedChildService = SelectedChildService();
  final _childBehaviorService = ChildBehaviorService();
  final _localNotificationService = LocalNotificationService.instance;

  bool _isChecking = true;
  String? _errorMessage;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    unawaited(
      _sessionProgressService.saveChildSetupRoute(
        '/child-home/setup-preparing',
      ),
    );
    unawaited(_verifyAndContinue());
  }

  Future<void> _verifyAndContinue() async {
    setState(() {
      _isChecking = true;
      _errorMessage = null;
    });

    try {
      // Ensure the screen stays visible long enough for the user to see it
      // while all startup work completes in parallel.
      final minDisplayFuture = Future<void>.delayed(
        const Duration(milliseconds: 1500),
      );

      final childId = await _selectedChildService.getSelectedChildId();
      if (!mounted) {
        return;
      }

      final cleanChildId = childId?.trim() ?? '';
      if (cleanChildId.isEmpty) {
        throw const ChildBehaviorFailure('يرجى اختيار الطفل أولاً.');
      }

      await _verifySetupPersistedWithRetry(cleanChildId);
      await _finalizeSetupData(cleanChildId);
      await _runStartupSteps(cleanChildId);

      // Wait for minimum display duration before navigating.
      await minDisplayFuture;

      if (!mounted || _hasNavigated) {
        return;
      }
      _hasNavigated = true;
      context.go('/child-home/setup-success');
    } on ChildBehaviorFailure catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isChecking = false;
        _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isChecking = false;
        _errorMessage = 'تعذر إتمام تجهيز إعدادات الطفل حالياً.';
      });
    }
  }

  Future<void> _verifySetupPersistedWithRetry(String childId) async {
    const maxAttempts = 6;
    ChildBehaviorFailure? lastFailure;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        await _childBehaviorService.verifyChildSetupPersisted(childId: childId);
        return;
      } on ChildBehaviorFailure catch (e) {
        lastFailure = e;
        if (attempt < maxAttempts) {
          await Future<void>.delayed(const Duration(milliseconds: 700));
        }
      }
    }

    throw lastFailure ??
        const ChildBehaviorFailure('تعذر التحقق من حفظ الإعدادات حالياً.');
  }

  Future<void> _finalizeSetupData(String childId) async {
    final config = await _childBehaviorService.getChildBehaviorConfig(
      childId: childId,
    );

    await _childBehaviorService.saveSelectedBehaviorIds(
      childId: childId,
      behaviorIds: config.selectedBehaviorIds,
    );

    await _childBehaviorService.saveWaterRoutine(
      childId: childId,
      cupsCount: config.waterCupsCount,
      reminderTimesMinutes: config.waterReminderTimesMinutes,
    );

    await _childBehaviorService.saveSportRoutine(
      childId: childId,
      sessionsCount: config.sportSessionsCount,
      lightActivityEnabled: config.sportLightActivityEnabled,
      sessionTimesMinutes: config.sportSessionTimesMinutes,
    );

    await _childBehaviorService.saveSleepRoutine(
      childId: childId,
      hour: config.sleepHour,
      minute: config.sleepMinute,
      notificationsEnabled: config.sleepNotificationsEnabled,
    );
  }

  /// Await critical startup operations so subsequent screens load instantly.
  Future<void> _runStartupSteps(String childId) async {
    // Initialize notifications — must complete before leaving this screen.
    await _localNotificationService.initialize();
    _localNotificationService.syncSelectedChildNotificationsInBackground(
      delay: const Duration(milliseconds: 200),
    );

    // Sync sleep lock — await so the child home screen has it ready.
  }

  void _goBack() {
    final router = GoRouter.of(context);
    if (router.canPop()) {
      context.pop();
    } else {
      context.go('/child-home/sleep-routine');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F1E2),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _isChecking
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/risha/risha.png',
                        width: 72,
                        height: 72,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'جاري التجهيز.....',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: const Color(0xFFB48C6A),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(strokeWidth: 2.8),
                      ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Color(0xFFB48C6A),
                        size: 42,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _errorMessage ?? 'تعذر التأكد من حفظ الإعدادات حالياً.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: const Color(0xFFB48C6A),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 10,
                        alignment: WrapAlignment.center,
                        children: [
                          _ActionButton(
                            label: 'إعادة المحاولة',
                            onTap: _verifyAndContinue,
                          ),
                          _ActionButton(
                            label: 'رجوع',
                            onTap: _goBack,
                            isSecondary: true,
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.onTap,
    this.isSecondary = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool isSecondary;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      height: 44,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: isSecondary
              ? const LinearGradient(
                  colors: [Color(0xFFD8D3C6), Color(0xFFE6DDCC)],
                )
              : const LinearGradient(
                  colors: [Color(0xFF1F8A3D), Color(0xFF5DA57F)],
                ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: onTap,
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: isSecondary ? const Color(0xFF6E5B43) : Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
