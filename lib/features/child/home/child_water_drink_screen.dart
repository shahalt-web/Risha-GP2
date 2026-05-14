import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';

import 'package:risha_v01/shared/config/feature_flags.dart';
import 'package:risha_v01/shared/services/child_task_progress_service.dart';

class ChildWaterDrinkScreen extends StatefulWidget {
  const ChildWaterDrinkScreen({super.key, this.taskId});

  final String? taskId;

  @override
  State<ChildWaterDrinkScreen> createState() => _ChildWaterDrinkScreenState();
}

class _ChildWaterDrinkScreenState extends State<ChildWaterDrinkScreen> {
  static const List<_WaterStage> _stages = [
    _WaterStage(
      title: 'هيا نبدأ\nاشرب الماء',
      assetPath: 'assets/water/cup_filled_of_water.png',
    ),
    _WaterStage(
      title: 'أحسنت\nأنهيت كوب الماء',
      assetPath: 'assets/water/cup_empty.png',
    ),
  ];

  final _taskProgressService = ChildTaskProgressService();
  final AudioPlayer _tapSoundPlayer = AudioPlayer();
  Timer? _completionTimer;
  int _stageIndex = 0;

  String get _effectiveTaskId => widget.taskId?.trim().isNotEmpty == true
      ? widget.taskId!.trim()
      : ChildTaskIds.waterDrink;

  bool get _isCompleted => _stageIndex == _stages.length - 1;
  _WaterStage get _stage => _stages[_stageIndex];

  @override
  void initState() {
    super.initState();
    _initializeTapSound();
    unawaited(_redirectIfCompletedToday());
  }

  Future<void> _initializeTapSound() async {
    try {
      await _tapSoundPlayer.setAsset('assets/sounds/click_sound.m4a');
    } catch (_) {
      // Ignore sound loading failures to keep the screen usable.
    }
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
      // If progress loading fails, keep the task accessible.
    }
  }

  void _closeScreen() {
    _completionTimer?.cancel();
    final router = GoRouter.of(context);
    if (router.canPop()) {
      context.pop();
      return;
    }
    context.go('/child-home/daily-home');
  }

  void _advanceCup() {
    if (_isCompleted) {
      return;
    }

    unawaited(_playTapSound());
    setState(() {
      _stageIndex += 1;
    });

    if (_isCompleted) {
      _completionTimer?.cancel();
      _completionTimer = Timer(const Duration(seconds: 3), () {
        if (!mounted) {
          return;
        }
        context.go(
          '/child-home/hero-reward?task=${Uri.encodeComponent(_effectiveTaskId)}',
        );
      });
    }
  }

  Future<void> _playTapSound() async {
    try {
      await _tapSoundPlayer.seek(Duration.zero);
      await _tapSoundPlayer.play();
    } catch (_) {
      // Ignore sound playback failures.
    }
  }

  @override
  void dispose() {
    _completionTimer?.cancel();
    _tapSoundPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F2E6),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage('assets/water/wallpaper_water.png'),
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
                      child: Column(
                        children: [
                          const SizedBox(height: 20),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            child: Text(
                              _stage.title,
                              key: ValueKey<String>(_stage.title),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFF2D241B),
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                height: 1.2,
                              ),
                            ),
                          ),
                          const SizedBox(height: 135),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 260),
                            child: Image.asset(
                              _stage.assetPath,
                              key: ValueKey<String>(_stage.assetPath),
                              width: 300,
                              height: 190,
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 16),
                          AnimatedOpacity(
                            duration: const Duration(milliseconds: 180),
                            opacity: _isCompleted ? 0.35 : 1,
                            child: IgnorePointer(
                              ignoring: _isCompleted,
                              child: _WaterActionButton(onTap: _advanceCup),
                            ),
                          ),
                          const Spacer(),
                          Align(
                            alignment: Alignment.bottomLeft,
                            child: Image.asset(
                              'assets/risha/risha_drink.png',
                              width: 180,
                              height: 190,
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 6,
                  left: 6,
                  child: _CloseButton(onTap: _closeScreen),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WaterActionButton extends StatelessWidget {
  const _WaterActionButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Ink(
          width: 54,
          height: 54,
          decoration: const BoxDecoration(
            color: Color(0xFFF0BE20),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Color(0x2F9B7F1F),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 38),
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: 30,
          height: 30,
          decoration: const BoxDecoration(
            color: Color(0xFF2E3A70),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

class _WaterStage {
  const _WaterStage({required this.title, required this.assetPath});

  final String title;
  final String assetPath;
}
