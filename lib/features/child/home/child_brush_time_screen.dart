import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:risha_v01/shared/config/feature_flags.dart';
import 'package:risha_v01/shared/services/child_task_progress_service.dart';

class ChildBrushTimeScreen extends StatefulWidget {
  const ChildBrushTimeScreen({super.key, this.taskId});

  final String? taskId;

  @override
  State<ChildBrushTimeScreen> createState() => _ChildBrushTimeScreenState();
}

class _ChildBrushTimeScreenState extends State<ChildBrushTimeScreen> {
  static const int _totalSeconds = 120;

  final _taskProgressService = ChildTaskProgressService();
  Timer? _timer;
  int _secondsLeft = _totalSeconds;

  String get _effectiveTaskId => widget.taskId?.trim().isNotEmpty == true
      ? widget.taskId!.trim()
      : ChildTaskIds.brushTime;

  bool get _canFinish => _secondsLeft == 0;

  @override
  void initState() {
    super.initState();
    unawaited(_redirectIfCompletedToday());
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsLeft == 0) {
        timer.cancel();
        return;
      }
      setState(() {
        _secondsLeft -= 1;
      });
    });
  }

  Future<void> _redirectIfCompletedToday() async {
    if (FeatureFlags.bypassDailyTaskCompletionRestrictionsTemporarily) {
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
              content: Text('تم إنجاز هذه المهمة اليوم. ستعود غدًا.'),
            ),
          );
        context.go('/child-home/daily-home');
      });
    } catch (_) {
      // Keep the task accessible if progress loading fails.
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _close() {
    final router = GoRouter.of(context);
    if (router.canPop()) {
      context.pop();
    } else {
      context.go('/child-home/daily-home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final minutes = _secondsLeft ~/ 60;
    final seconds = (_secondsLeft % 60).toString().padLeft(2, '0');
    final secondsLabel = '$minutes:$seconds';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F1E2),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: _close,
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: const BoxDecoration(
                          color: Color(0xFF34458C),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'حان وقت\nتنظيف الاسنان!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 28,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const _BrushMascot(),
                  const SizedBox(height: 10),
                  const Text(
                    'استمر في تنظيف\nاسنانك حتى ينتهي الوقت',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 17,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    secondsLabel,
                    style: const TextStyle(
                      color: Color(0xFFF5C123),
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const Spacer(),
                  _DoneButton(
                    enabled: _canFinish,
                    onTap: () => context.go(
                      '/child-home/hero-reward?task=${Uri.encodeComponent(_effectiveTaskId)}',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _canFinish
                        ? 'أحسنت، يمكنك إنهاء المهمة الآن'
                        : 'زر الإنهاء سيتفعّل بعد انتهاء الدقيقتين',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _canFinish
                          ? const Color(0xFF2D8B52)
                          : const Color(0xFF8B7A67),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrushMascot extends StatelessWidget {
  const _BrushMascot();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      height: 170,
      child: ClipRect(
        child: Align(
          alignment: const Alignment(0, 1),
          widthFactor: 0.32,
          heightFactor: 0.33,
          child: Image.asset(
            'assets/risha/risha_brushing.png',
            width: 500,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}

class _DoneButton extends StatelessWidget {
  const _DoneButton({required this.onTap, required this.enabled});

  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 142,
      height: 58,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: enabled
                ? const [Color(0xFF1F8A3D), Color(0xFF65B183)]
                : const [Color(0xFFBDB6AB), Color(0xFFD7D1C8)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(
                0xFF6A57A6,
              ).withValues(alpha: enabled ? 0.18 : 0.08),
              blurRadius: 12,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: enabled ? onTap : null,
            child: Center(
              child: Icon(
                Icons.check_rounded,
                color: enabled ? Colors.white : const Color(0xFFF4EFE6),
                size: 50,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
