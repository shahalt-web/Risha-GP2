import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:risha_v01/shared/config/feature_flags.dart';
import 'package:risha_v01/shared/services/child_task_progress_service.dart';

class ChildCustomBehaviorScreen extends StatefulWidget {
  const ChildCustomBehaviorScreen({super.key, this.taskId, this.behaviorTitle});

  final String? taskId;
  final String? behaviorTitle;

  @override
  State<ChildCustomBehaviorScreen> createState() =>
      _ChildCustomBehaviorScreenState();
}

class _ChildCustomBehaviorScreenState extends State<ChildCustomBehaviorScreen> {
  final _taskProgressService = ChildTaskProgressService();

  String get _effectiveTaskId => widget.taskId?.trim() ?? '';

  String get _titleText {
    final trimmed = widget.behaviorTitle?.trim();
    return trimmed == null || trimmed.isEmpty ? 'السلوك اليومي' : trimmed;
  }

  @override
  void initState() {
    super.initState();
    unawaited(_redirectIfCompletedToday());
  }

  Future<void> _redirectIfCompletedToday() async {
    if (FeatureFlags.bypassDailyTaskCompletionRestrictionsTemporarily) {
      return;
    }
    if (_effectiveTaskId.isEmpty) {
      return;
    }
    try {
      final progress = await _taskProgressService
          .getSelectedChildTaskProgress();
      if (!mounted || !progress.isCompleted(_effectiveTaskId)) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                'تم إنجاز هذا السلوك اليوم. سيظهر لك عند الوقت التالي.',
              ),
            ),
          );
        context.go('/child-home/daily-home');
      });
    } catch (_) {
      // Keep the screen accessible if loading cached progress fails.
    }
  }

  void _goBack() {
    final router = GoRouter.of(context);
    if (router.canPop()) {
      context.pop();
      return;
    }
    context.go('/child-home/daily-home');
  }

  void _goToReward() {
    if (_effectiveTaskId.isEmpty) {
      return;
    }
    context.go(
      '/child-home/hero-reward?task=${Uri.encodeComponent(_effectiveTaskId)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F1E2),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: _goBack,
                      icon: const Icon(
                        Icons.arrow_forward,
                        color: Color(0xFF2D241B),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _titleText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFD6A23C),
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'هل أنجزت هذا السلوك اليوم',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFB48C6A),
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 30),
                  Expanded(
                    child: Center(
                      child: Image.asset(
                        'assets/risha/risha_normal.png',
                        width: 180,
                        height: 180,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 56,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1F8A3D), Color(0xFF5DA57F)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF6A57A6,
                            ).withValues(alpha: 0.18),
                            blurRadius: 12,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(28),
                          onTap: _effectiveTaskId.isEmpty ? null : _goToReward,
                          child: const Center(
                            child: Text(
                              'نعم أنجزته',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
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
      ),
    );
  }
}
