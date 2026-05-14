import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:risha_v01/shared/config/feature_flags.dart';
import 'package:risha_v01/shared/services/child_task_progress_service.dart';

class ChildQuranReadingScreen extends StatefulWidget {
  const ChildQuranReadingScreen({super.key});

  @override
  State<ChildQuranReadingScreen> createState() =>
      _ChildQuranReadingScreenState();
}

class _ChildQuranReadingScreenState extends State<ChildQuranReadingScreen> {
  static const MethodChannel _quranAudioChannel = MethodChannel(
    'risha_v01/quran_audio',
  );
  static const int _maxRepeatsPerPage = 3;
  static const Duration _audioPollInterval = Duration(milliseconds: 180);

  static const List<_SurahPageData> _pages = [
    _SurahPageData(
      title: 'سورة الإخلاص',
      imageAssetPath: 'assets/quran/Surah_Al_Ikhlas.png',
      audioAssetPath: 'assets/quran/audio/surah_al_ikhlas.m4a',
    ),
    _SurahPageData(
      title: 'سورة الناس',
      imageAssetPath: 'assets/quran/Surah_An_Nas.png',
      audioAssetPath: 'assets/quran/audio/surah_an_nas.m4a',
    ),
    _SurahPageData(
      title: 'سورة الفلق',
      imageAssetPath: 'assets/quran/Surah_Al_Falaq.png',
      audioAssetPath: 'assets/quran/audio/surah_al_falaq.m4a',
    ),
  ];

  final PageController _pageController = PageController();
  final _taskProgressService = ChildTaskProgressService();

  Timer? _audioPoller;
  int _currentPage = 0;
  int _currentRepeat = 1;
  bool _isPlaying = false;
  bool _isPreparingAudio = false;
  bool _isAudioReady = false;
  bool _isBuffering = false;
  bool _didFinishSession = false;
  bool _completionHandled = false;
  String? _audioErrorMessage;
  Duration _currentPosition = Duration.zero;
  Duration _currentDuration = Duration.zero;
  int _audioSessionToken = 0;

  _SurahPageData get _currentSurah => _pages[_currentPage];
  bool get _isFirstStep => _currentPage == 0 && _currentRepeat == 1;
  bool get _isLastStep =>
      _currentPage == _pages.length - 1 && _currentRepeat == _maxRepeatsPerPage;
  bool get _supportsNativeAudio =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  double get _progress {
    final totalSteps = _pages.length * _maxRepeatsPerPage;
    final completedSteps =
        (_currentPage * _maxRepeatsPerPage) + (_currentRepeat - 1);
    final positionFactor = _currentDuration.inMilliseconds > 0
        ? _currentPosition.inMilliseconds / _currentDuration.inMilliseconds
        : 0.0;
    final progress = (completedSteps + positionFactor) / totalSteps;
    return progress.clamp(0.0, 1.0);
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
    try {
      final progress = await _taskProgressService
          .getSelectedChildTaskProgress();
      if (!mounted || !progress.isCompleted(ChildTaskIds.quranReading)) {
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

  bool _isActiveAudioSession(int token) {
    return mounted && _audioSessionToken == token;
  }

  Future<Map<String, dynamic>> _invokeStateMethod(
    String method, [
    Map<String, dynamic>? arguments,
  ]) async {
    if (!_supportsNativeAudio) {
      return const <String, dynamic>{};
    }
    try {
      final rawState = await _quranAudioChannel
          .invokeMapMethod<String, dynamic>(method, arguments)
          .timeout(const Duration(seconds: 6));
      return _normalizeStateMap(rawState);
    } catch (_) {
      return const <String, dynamic>{};
    }
  }

  Future<void> _invokeSilentMethod(
    String method, [
    Map<String, dynamic>? arguments,
  ]) async {
    if (!_supportsNativeAudio) {
      return;
    }
    try {
      await _quranAudioChannel
          .invokeMethod<void>(method, arguments)
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      // Ignore cleanup failures and timeouts.
    }
  }

  Map<String, dynamic> _normalizeStateMap(Map<dynamic, dynamic>? rawState) {
    if (rawState == null) {
      return const <String, dynamic>{};
    }
    return rawState.map((key, value) => MapEntry(key.toString(), value));
  }

  int _readIntValue(Object? value, {int fallback = 0}) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value) ?? fallback;
    }
    return fallback;
  }

  void _restartAudioPolling() {
    _audioPoller?.cancel();
    _audioPoller = Timer.periodic(
      _audioPollInterval,
      (_) => unawaited(_pollAudioState()),
    );
  }

  Future<void> _prepareCurrentAudio({required bool autoplay}) async {
    final sessionToken = ++_audioSessionToken;

    if (!_supportsNativeAudio) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isPreparingAudio = false;
        _isAudioReady = false;
        _isBuffering = false;
        _audioErrorMessage =
            'تشغيل الصوت في هذه الشاشة متاح حالياً على Android فقط.';
      });
      return;
    }

    try {
      setState(() {
        _isPreparingAudio = true;
        _isBuffering = autoplay;
        _isPlaying = false;
        _audioErrorMessage = null;
        _completionHandled = false;
      });

      _audioPoller?.cancel();
      await _invokeSilentMethod('stopQuranAudio');
      if (!_isActiveAudioSession(sessionToken)) {
        return;
      }

      final state = await _invokeStateMethod('loadQuranAudio', {
        'assetPath': _currentSurah.audioAssetPath,
      });
      if (state.isEmpty) {
        throw Exception('لم يتم تحميل حالة الصوت من القناة الأصلية.');
      }

      if (!_isActiveAudioSession(sessionToken)) {
        return;
      }

      final duration = Duration(
        milliseconds: _readIntValue(state['durationMs']),
      );
      final position = Duration(
        milliseconds: _readIntValue(state['positionMs']),
      );

      _restartAudioPolling();

      if (!_isActiveAudioSession(sessionToken)) {
        return;
      }

      setState(() {
        _currentDuration = duration;
        _currentPosition = position;
        _isPreparingAudio = false;
        _isAudioReady = state['ready'] == true;
        _isBuffering = false;
        _isPlaying = state['playing'] == true;
        _audioErrorMessage = null;
      });

      if (autoplay) {
        await _playPreparedAudio(sessionToken);
      }
    } catch (_) {
      if (!_isActiveAudioSession(sessionToken)) {
        return;
      }
      setState(() {
        _currentDuration = Duration.zero;
        _currentPosition = Duration.zero;
        _isPreparingAudio = false;
        _isAudioReady = false;
        _isPlaying = false;
        _isBuffering = false;
        _audioErrorMessage =
            'ملف الصوت غير موجود حالياً. أضفه داخل assets/quran/audio ثم أعد تشغيل التطبيق.';
      });
    }
  }

  Future<void> _playPreparedAudio([int? sessionToken]) async {
    if (!_supportsNativeAudio || !_isAudioReady) {
      return;
    }

    final expectedToken = sessionToken ?? _audioSessionToken;
    try {
      setState(() {
        _isBuffering = true;
        _audioErrorMessage = null;
      });
      await _quranAudioChannel.invokeMethod<void>('playQuranAudio');
      if (!_isActiveAudioSession(expectedToken)) {
        return;
      }
      setState(() {
        _isPlaying = true;
        _isBuffering = false;
        _completionHandled = false;
      });
    } catch (_) {
      if (!_isActiveAudioSession(expectedToken)) {
        return;
      }
      setState(() {
        _isPlaying = false;
        _isBuffering = false;
        _audioErrorMessage = 'تعذر تشغيل المقطع الصوتي لهذا الجزء.';
      });
    }
  }

  Future<void> _pauseAudio() async {
    try {
      await _quranAudioChannel.invokeMethod<void>('pauseQuranAudio');
      if (!mounted) {
        return;
      }
      setState(() {
        _isPlaying = false;
        _isBuffering = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isPlaying = false;
        _isBuffering = false;
        _audioErrorMessage = 'تعذر إيقاف الصوت مؤقتاً.';
      });
    }
  }

  Future<void> _pollAudioState() async {
    if (!mounted || !_isAudioReady || !_supportsNativeAudio) {
      return;
    }

    try {
      final state = await _invokeStateMethod('getQuranAudioState');
      if (!mounted || state.isEmpty) {
        return;
      }

      final position = Duration(
        milliseconds: _readIntValue(state['positionMs']),
      );
      final duration = Duration(
        milliseconds: _readIntValue(state['durationMs']),
      );
      final isPlaying = state['playing'] == true;
      final isCompleted = state['completed'] == true;

      if (_currentPosition != position ||
          _currentDuration != duration ||
          _isPlaying != isPlaying ||
          _isBuffering) {
        setState(() {
          _currentPosition = position;
          _currentDuration = duration;
          _isPlaying = isPlaying;
          _isBuffering = false;
        });
      }

      if (isCompleted && !_completionHandled) {
        _completionHandled = true;
        unawaited(_advanceToNextStep(autoplay: true, autoTriggered: true));
        return;
      }

      if (!isCompleted && _completionHandled) {
        _completionHandled = false;
      }
    } catch (_) {
      // Keep the screen responsive if one polling tick fails.
    }
  }

  Future<void> _toggleAudio() async {
    if (_isPlaying) {
      await _pauseAudio();
      return;
    }

    if (!_isAudioReady) {
      await _prepareCurrentAudio(autoplay: true);
      return;
    }

    await _playPreparedAudio();
  }

  Future<void> _goToStep({
    required int pageIndex,
    required int repeat,
    required bool autoplay,
  }) async {
    final safePageIndex = pageIndex.clamp(0, _pages.length - 1);
    final safeRepeat = repeat.clamp(1, _maxRepeatsPerPage);
    final pageChanged = safePageIndex != _currentPage;

    _audioSessionToken++;
    _audioPoller?.cancel();
    await _invokeSilentMethod('stopQuranAudio');

    if (!mounted) {
      return;
    }

    setState(() {
      _currentPage = safePageIndex;
      _currentRepeat = safeRepeat;
      _currentPosition = Duration.zero;
      _currentDuration = Duration.zero;
      _isPlaying = false;
      _isPreparingAudio = false;
      _isAudioReady = false;
      _isBuffering = false;
      _completionHandled = false;
      _audioErrorMessage = null;
    });

    if (pageChanged && _pageController.hasClients) {
      unawaited(
        _pageController.animateToPage(
          safePageIndex,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        ),
      );
    }

    if (autoplay) {
      await _prepareCurrentAudio(autoplay: true);
    }
  }

  Future<void> _advanceToNextStep({
    required bool autoplay,
    bool autoTriggered = false,
  }) async {
    if (_currentRepeat < _maxRepeatsPerPage) {
      await _goToStep(
        pageIndex: _currentPage,
        repeat: _currentRepeat + 1,
        autoplay: autoplay,
      );
      return;
    }

    if (_currentPage < _pages.length - 1) {
      await _goToStep(
        pageIndex: _currentPage + 1,
        repeat: 1,
        autoplay: autoplay,
      );
      return;
    }

    await _finishReading(autoTriggered: autoTriggered);
  }

  Future<void> _returnToPreviousStep() async {
    final shouldAutoplay =
        _isPlaying || _isPreparingAudio || _isBuffering || _isAudioReady;

    if (_currentRepeat > 1) {
      await _goToStep(
        pageIndex: _currentPage,
        repeat: _currentRepeat - 1,
        autoplay: shouldAutoplay,
      );
      return;
    }

    if (_currentPage > 0) {
      await _goToStep(
        pageIndex: _currentPage - 1,
        repeat: _maxRepeatsPerPage,
        autoplay: shouldAutoplay,
      );
      return;
    }

    await _goToStep(pageIndex: 0, repeat: 1, autoplay: shouldAutoplay);
  }

  Future<void> _finishReading({bool autoTriggered = false}) async {
    if (_didFinishSession) {
      return;
    }
    _didFinishSession = true;
    _audioSessionToken++;
    _audioPoller?.cancel();
    await _invokeSilentMethod('stopQuranAudio');

    if (autoTriggered) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }

    if (!mounted) {
      return;
    }
    context.go('/child-home/hero-reward?task=quran-reading');
  }

  void _closeScreen(BuildContext context) {
    _audioSessionToken++;
    _audioPoller?.cancel();
    unawaited(_invokeSilentMethod('stopQuranAudio'));
    unawaited(_invokeSilentMethod('disposeQuranAudio'));
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/child-home/daily-home');
  }

  @override
  void dispose() {
    _audioSessionToken++;
    _audioPoller?.cancel();
    unawaited(_invokeSilentMethod('stopQuranAudio'));
    unawaited(_invokeSilentMethod('disposeQuranAudio'));
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1EEDC),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.topLeft,
                    child: _CloseButton(onTap: () => _closeScreen(context)),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 286,
                    child: PageView.builder(
                      controller: _pageController,
                      reverse: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _pages.length,
                      itemBuilder: (context, index) {
                        return _SurahPage(
                          assetPath: _pages[index].imageAssetPath,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _currentSurah.title,
                    style: const TextStyle(
                      color: Color(0xFF516245),
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(end: 10),
                      child: Text(
                        '$_currentRepeat/$_maxRepeatsPerPage',
                        style: const TextStyle(
                          color: Color(0xFF516245),
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _AudioActionButton(
                        icon: _isLastStep
                            ? Icons.check_rounded
                            : Icons.skip_next_rounded,
                        onTap: () =>
                            unawaited(_advanceToNextStep(autoplay: true)),
                        size: 64,
                      ),
                      const SizedBox(width: 12),
                      _AudioActionButton(
                        icon: _isPreparingAudio || _isBuffering
                            ? null
                            : _isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        onTap: () => unawaited(_toggleAudio()),
                        size: 82,
                        isPrimary: true,
                        isLoading: _isPreparingAudio || _isBuffering,
                      ),
                      const SizedBox(width: 12),
                      _AudioActionButton(
                        icon: Icons.skip_previous_rounded,
                        onTap: _isFirstStep
                            ? null
                            : () => unawaited(_returnToPreviousStep()),
                        size: 64,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _ReadingProgressBar(
                    value: _progress,
                    isActive: _isPlaying || _isPreparingAudio || _isBuffering,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'التكرار ينتقل تلقائياً بعد 3 مرات لكل صورة',
                    style: const TextStyle(
                      color: Color(0xFF7C775F),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (_audioErrorMessage != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _audioErrorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF8A4C35),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        height: 1.5,
                      ),
                    ),
                  ],
                  const Spacer(),
                  Align(
                    alignment: Alignment.bottomLeft,
                    child: Image.asset(
                      'assets/risha/risha_reading.png',
                      width: 136,
                      height: 136,
                      fit: BoxFit.contain,
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

class _SurahPage extends StatelessWidget {
  const _SurahPage({required this.assetPath});

  final String assetPath;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F5E8),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFD3C9B3), width: 1.2),
      ),
      padding: const EdgeInsets.all(3),
      child: Image.asset(
        assetPath,
        fit: BoxFit.contain,
        width: double.infinity,
      ),
    );
  }
}

class _AudioActionButton extends StatelessWidget {
  const _AudioActionButton({
    required this.icon,
    required this.onTap,
    required this.size,
    this.isPrimary = false,
    this.isLoading = false,
  });

  final IconData? icon;
  final VoidCallback? onTap;
  final double size;
  final bool isPrimary;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(size / 2),
        child: Ink(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: enabled ? const Color(0xFF8DBD79) : const Color(0xFFB7C5AE),
            shape: BoxShape.circle,
            boxShadow: enabled
                ? const [
                    BoxShadow(
                      color: Color(0x2F6B8D58),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: isLoading
                ? SizedBox(
                    width: isPrimary ? 30 : 24,
                    height: isPrimary ? 30 : 24,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                : Icon(icon, color: Colors.white, size: isPrimary ? 40 : 30),
          ),
        ),
      ),
    );
  }
}

class _ReadingProgressBar extends StatelessWidget {
  const _ReadingProgressBar({required this.value, required this.isActive});

  final double value;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(0.0, 1.0);
    final activeColor = isActive
        ? const Color(0xFF6F9A55)
        : const Color(0xFFE0C04A);
    return Container(
      width: 188,
      height: 7,
      decoration: BoxDecoration(
        color: const Color(0xFFC4D6AA),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: clamped,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            decoration: BoxDecoration(
              color: activeColor,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: onTap == null
                ? const Color(0xFFB7C5AE)
                : const Color(0xFF8DBD79),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

class _SurahPageData {
  const _SurahPageData({
    required this.title,
    required this.imageAssetPath,
    required this.audioAssetPath,
  });

  final String title;
  final String imageAssetPath;
  final String audioAssetPath;
}
