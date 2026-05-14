import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import 'package:risha_v01/shared/services/child_behavior_service.dart';
import 'package:risha_v01/shared/services/child_task_progress_service.dart';
import 'package:risha_v01/shared/services/selected_child_service.dart';

class ChildExercisingScreen extends StatefulWidget {
  const ChildExercisingScreen({super.key, this.taskId});
  final String? taskId;

  @override
  State<ChildExercisingScreen> createState() => _ChildExercisingScreenState();
}

class _ChildExercisingScreenState extends State<ChildExercisingScreen> {
  bool _isLightMode = false;

  final _childBehaviorService = ChildBehaviorService();
  final _selectedChildService = SelectedChildService();
  final _taskProgressService = ChildTaskProgressService();
  final ValueNotifier<double> _progressNotifier = ValueNotifier<double>(0);
  final ValueNotifier<bool> _isPlayingNotifier = ValueNotifier<bool>(false);
  VideoPlayerController? _videoController;
  bool _isSwitchingVideo = false;
  bool _isNavigating = false;
  String? _activeVideoAsset;
  int _videoLoadGeneration = 0;
  int _lastProgressStep = -1;

  String get _effectiveTaskId => widget.taskId?.trim().isNotEmpty == true
      ? widget.taskId!.trim()
      : ChildTaskIds.exercising;

  @override
  void initState() {
    super.initState();
    unawaited(_loadConfiguredVideoMode());
    unawaited(_redirectIfCompletedToday());
  }

  Future<void> _loadConfiguredVideoMode() async {
    var configuredLightMode = _isLightMode;
    try {
      final childId = await _selectedChildService.getSelectedChildId();
      if (childId != null && childId.isNotEmpty) {
        final config = await _childBehaviorService.getChildBehaviorConfig(
          childId: childId,
        );
        configuredLightMode = config.sportLightActivityEnabled;
      }
    } catch (_) {
      // Keep the default exercise mode if the parent configuration is unavailable.
    }

    if (!mounted) {
      return;
    }
    _isLightMode = configuredLightMode;
    await _loadVideoForCurrentMode();
  }

  List<String> _videoCandidatesForMode(bool isLightMode) {
    if (isLightMode) {
      return const <String>[
        'assets/exercising/exrtcise_2.mp4',
        'assets/exercising/exercise_2.mp4',
      ];
    }
    return const <String>[
      'assets/exercising/exrtcise_1.mp4',
      'assets/exercising/exercise_1.mp4',
    ];
  }

  Future<void> _loadVideoForCurrentMode({bool autoPlay = false}) async {
    final loadGeneration = ++_videoLoadGeneration;
    if (mounted) {
      setState(() => _isSwitchingVideo = true);
    }
    _progressNotifier.value = 0;
    _isPlayingNotifier.value = false;
    _lastProgressStep = -1;

    final previousController = _videoController;
    _videoController = null;
    if (previousController != null) {
      await _releaseController(previousController);
      await Future<void>.delayed(const Duration(milliseconds: 140));
    }
    if (!mounted || loadGeneration != _videoLoadGeneration) {
      return;
    }

    final candidates = _videoCandidatesForMode(_isLightMode);
    for (final assetPath in candidates) {
      final controller = VideoPlayerController.asset(assetPath);
      try {
        await controller.initialize();
        await controller.setLooping(false);
        if (!mounted || loadGeneration != _videoLoadGeneration) {
          await _releaseController(controller);
          return;
        }
        controller.addListener(_onVideoUpdate);
        _videoController = controller;
        _activeVideoAsset = assetPath;
        _syncPlaybackNotifiers(controller.value);
        if (autoPlay) {
          unawaited(controller.play());
        }
        if (mounted) {
          setState(() => _isSwitchingVideo = false);
        }
        return;
      } catch (_) {
        await _releaseController(controller);
      }
    }

    if (!mounted || loadGeneration != _videoLoadGeneration) {
      return;
    }

    _activeVideoAsset = null;
    setState(() => _isSwitchingVideo = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('تعذر تحميل فيديو التمرين حالياً.')),
      );
  }

  void _onVideoUpdate() {
    final controller = _videoController;
    if (!mounted || controller == null || !controller.value.isInitialized) {
      return;
    }

    final value = controller.value;
    if (!_isNavigating &&
        !_isSwitchingVideo &&
        value.duration > Duration.zero &&
        !value.isPlaying &&
        value.position >= value.duration - const Duration(milliseconds: 120)) {
      _finishExercise();
      return;
    }

    final progressStep = value.position.inMilliseconds ~/ 500;
    if (progressStep == _lastProgressStep &&
        _isPlayingNotifier.value == value.isPlaying) {
      return;
    }
    _lastProgressStep = progressStep;
    _syncPlaybackNotifiers(value);
  }

  Future<void> _releaseController(VideoPlayerController controller) async {
    controller.removeListener(_onVideoUpdate);
    try {
      await controller.pause();
    } catch (_) {
      // Ignore pause errors during teardown.
    }
    try {
      await controller.dispose();
    } catch (_) {
      // Ignore dispose errors during teardown.
    }
  }

  void _syncPlaybackNotifiers(VideoPlayerValue value) {
    if (value.duration.inMilliseconds > 0) {
      final nextProgress =
          (value.position.inMilliseconds / value.duration.inMilliseconds)
              .clamp(0.0, 1.0)
              .toDouble();
      if (_progressNotifier.value != nextProgress) {
        _progressNotifier.value = nextProgress;
      }
    } else if (_progressNotifier.value != 0) {
      _progressNotifier.value = 0;
    }

    if (_isPlayingNotifier.value != value.isPlaying) {
      _isPlayingNotifier.value = value.isPlaying;
    }
  }

  Future<void> _redirectIfCompletedToday() async {
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
              content: Text('تم إنجاز هذه المهمة اليوم. ستعود غداً.'),
            ),
          );
        context.go('/child-home/daily-home');
      });
    } catch (_) {
      // Keep screen accessible when progress lookup fails.
    }
  }

  void _closeScreen() {
    final controller = _videoController;
    if (controller?.value.isInitialized == true &&
        controller!.value.isPlaying) {
      controller.pause();
      _isPlayingNotifier.value = false;
    }
    final router = GoRouter.of(context);
    if (router.canPop()) {
      context.pop();
      return;
    }
    context.go('/child-home/daily-home');
  }

  void _togglePlayback() {
    if (_isNavigating || _isSwitchingVideo) {
      return;
    }

    final controller = _videoController;
    if (controller?.value.isInitialized != true) {
      return;
    }

    if (controller!.value.isPlaying) {
      controller.pause();
      _isPlayingNotifier.value = false;
    } else {
      controller.play();
      _isPlayingNotifier.value = true;
    }
  }

  void _finishExercise() {
    if (_isNavigating) {
      return;
    }
    _isNavigating = true;
    _videoController?.pause();
    _isPlayingNotifier.value = false;
    setState(() {});
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) {
        return;
      }
      context.go(
        '/child-home/hero-reward?task=${Uri.encodeComponent(_effectiveTaskId)}',
      );
    });
  }

  @override
  void dispose() {
    _videoLoadGeneration++;
    final controller = _videoController;
    _videoController = null;
    if (controller != null) {
      controller.removeListener(_onVideoUpdate);
      controller.dispose();
    }
    _progressNotifier.dispose();
    _isPlayingNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5EFD9),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _CloseButton(onTap: _closeScreen),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      width: 360,
                      height: 228,
                      color: Colors.black,
                      child: _isSwitchingVideo
                          ? const Center(child: CircularProgressIndicator())
                          : _videoController?.value.isInitialized == true
                          ? AspectRatio(
                              aspectRatio: _videoController!.value.aspectRatio,
                              child: VideoPlayer(
                                _videoController!,
                                key: ValueKey(_activeVideoAsset),
                              ),
                            )
                          : const _VideoLoadFallback(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  ValueListenableBuilder<bool>(
                    valueListenable: _isPlayingNotifier,
                    builder: (_, isPlaying, _) => _VideoActionButton(
                      isPlaying: isPlaying,
                      onTap: _togglePlayback,
                      enabled:
                          !_isSwitchingVideo &&
                          _videoController?.value.isInitialized == true,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Image.asset(
                    'assets/risha/risha_athlete.png',
                    width: 102,
                    height: 102,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'جربها معي ',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_activeVideoAsset != null) const Spacer(),
                  ValueListenableBuilder<double>(
                    valueListenable: _progressNotifier,
                    builder: (_, progress, _) =>
                        _ProgressBar(progress: progress),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
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
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          width: 38,
          height: 38,
          decoration: const BoxDecoration(
            color: Color(0xFF2D3E7A),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}

class _VideoActionButton extends StatelessWidget {
  const _VideoActionButton({
    required this.isPlaying,
    required this.onTap,
    required this.enabled,
  });

  final bool isPlaying;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(22),
          child: Ink(
            width: 160,
            height: 44,
            decoration: BoxDecoration(
              color: enabled
                  ? const Color(0xFF95B678).withValues(alpha: 0.95)
                  : const Color(0xFFAEBBA0),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VideoLoadFallback extends StatelessWidget {
  const _VideoLoadFallback();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.movie_outlined, color: Colors.white70, size: 42),
          SizedBox(height: 8),
          Text(
            'جاري تجهيز فيديو التمرين',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 316,
      height: 10,
      decoration: BoxDecoration(
        color: const Color(0xFFD5DEC0),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: progress.clamp(0.0, 1.0),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF86B26C),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }
}
