import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:risha_v01/shared/services/child_behavior_service.dart';
import 'package:risha_v01/shared/services/local_notification_service.dart';
import 'package:risha_v01/shared/services/selected_child_service.dart';
import 'package:risha_v01/shared/services/session_progress_service.dart';

class OnboardingPreparingScreen extends StatefulWidget {
  const OnboardingPreparingScreen({super.key});

  @override
  State<OnboardingPreparingScreen> createState() =>
      _OnboardingPreparingScreenState();
}

class _OnboardingPreparingScreenState extends State<OnboardingPreparingScreen> {
  final _sessionProgressService = SessionProgressService();
  final _selectedChildService = SelectedChildService();
  final _childBehaviorService = ChildBehaviorService();
  final _localNotificationService = LocalNotificationService.instance;

  bool _isPreparing = true;
  String? _errorMessage;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    unawaited(_sessionProgressService.saveChildSetupRoute('/parent-setup'));
    unawaited(_prepareAndContinue());
  }

  Future<void> _prepareAndContinue() async {
    setState(() {
      _isPreparing = true;
      _errorMessage = null;
    });

    try {
      final childId = await _selectedChildService.getSelectedChildId();
      if (!mounted) {
        return;
      }
      final cleanChildId = childId?.trim() ?? '';
      if (cleanChildId.isEmpty) {
        throw const ChildBehaviorFailure('يرجى اختيار الطفل أولاً.');
      }

      await _verifySetupPersistedWithRetry(cleanChildId);
      await _runBackgroundStartupSteps(cleanChildId);

      if (!mounted || _hasNavigated) {
        return;
      }
      _hasNavigated = true;
      context.go('/parent-setup');
    } on ChildBehaviorFailure catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isPreparing = false;
        _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isPreparing = false;
        _errorMessage = 'تعذر تجهيز إعدادات الطفل حالياً. حاول مرة أخرى.';
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
        const ChildBehaviorFailure(
          'تعذر التحقق من حفظ إعدادات السلوكيات حالياً.',
        );
  }

  Future<void> _runBackgroundStartupSteps(String childId) async {
    unawaited(_localNotificationService.initialize());
    _localNotificationService.syncSelectedChildNotificationsInBackground(
      delay: const Duration(milliseconds: 400),
    );
  }

  void _retry() {
    if (_isPreparing) {
      return;
    }
    unawaited(_prepareAndContinue());
  }

  void _goBack() {
    final router = GoRouter.of(context);
    if (router.canPop()) {
      context.pop();
    } else {
      context.go('/parent-setup');
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
            child: _isPreparing
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
                        'يتم التحضير.......',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: const Color(0xFFB48C6A),
                          fontWeight: FontWeight.w500,
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
                        _errorMessage ?? 'تعذر تجهيز إعدادات الطفل حالياً.',
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
                          _ActionButton(label: 'إعادة المحاولة', onTap: _retry),
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
