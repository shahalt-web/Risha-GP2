import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

class _StoryPageData {
  const _StoryPageData({required this.imageAsset, required this.text});

  final String imageAsset;
  final String text;
}

class _StoryPageTiming {
  const _StoryPageTiming({required this.start, required this.end});

  final Duration start;
  final Duration end;
}

class _StorySyncPageConfig {
  const _StorySyncPageConfig({
    required this.pageEndFraction,
    required this.transitionLeadMs,
    required this.wordLeadMs,
    this.manualWordEndRatios = const <double>[],
  });

  final double pageEndFraction;
  final int transitionLeadMs;
  final int wordLeadMs;
  final List<double> manualWordEndRatios;
}

class ChildSleepStoryScreen extends StatefulWidget {
  const ChildSleepStoryScreen({super.key});

  @override
  State<ChildSleepStoryScreen> createState() => _ChildSleepStoryScreenState();
}

class _ChildSleepStoryScreenState extends State<ChildSleepStoryScreen> {
  static const MethodChannel _storyAudioChannel = MethodChannel(
    'risha_v01/story_audio',
  );
  static const String _storyTitle = 'لمعة تستكشف الفضاء';
  static const String _storyAudioAssetPath =
      'assets/story/star_story/audio/lumaa_space_story.m4a';
  static const Duration _fallbackStoryDuration = Duration(seconds: 50);
  static const Duration _audioPollInterval = Duration(milliseconds: 120);
  static const int _storyNarrationStartDelayMs = 1900;
  static const int _storyNarrationEndTrimMs = 3000;
  static const int _storyFinishGraceMs = 550;

  static const List<_StoryPageData> _storyPages = [
    _StoryPageData(
      imageAsset: 'assets/story/star_story/star1.jpeg',
      text:
          'كانت النجمة الصغيرة لمعة تعيش وحيدة كانت تحلم دائماً باستكشاف الفضاء الواسع ومعرفة أسرار الكواكب الأخرى.',
    ),
    _StoryPageData(
      imageAsset: 'assets/story/star_story/star2.jpeg',
      text:
          'ذات يوم، قررت لمعة أن تعتني بالتلسكوب القديم. مسحت الغبار عنه بصبر، وبدأ التلسكوب يلمع من جديد!',
    ),
    _StoryPageData(
      imageAsset: 'assets/story/star_story/star3.jpeg',
      text:
          'بفضل التلسكوب، رأت لمعة كواكب غريبة! التقت بأصدقاء جدد: المكعب كعبول، والهرم هرموش. قرر الجميع العمل معاً لاستكشاف الفضاء.',
    ),
    _StoryPageData(
      imageAsset: 'assets/story/star_story/star4.jpeg',
      text:
          'باستخدام مهاراتهم المختلفة، نجح الأصدقاء في إصلاح التلسكوب تماماً. لقد تعلموا أن التعاون يجعل الأحلام الكبيرة ممكنة، والآن لديهم الكون كله لاستكشافه!',
    ),
  ];

  // هذا هو المكان الرئيسي لتعديل المزامنة يدوياً.
  // _storyNarrationStartDelayMs: صمت/تأخير البداية قبل بدء السرد الفعلي.
  // _storyNarrationEndTrimMs: صمت/تأخير النهاية بعد انتهاء السرد الفعلي.
  // pageEndFraction: نهاية الصفحة كنسبة من مدة السرد بعد تجاهل صمت البداية والنهاية.
  // transitionLeadMs: تقديم الانتقال للصفحة التالية بالمللي ثانية.
  // wordLeadMs: تقديم تمييز الكلمات داخل الصفحة.
  // manualWordEndRatios: اختياري. ضع نهاية كل كلمة كنسبة تراكمية من 0 إلى 1.
  static const List<_StorySyncPageConfig> _storySyncConfig = [
    _StorySyncPageConfig(
      pageEndFraction: 0.213,
      transitionLeadMs: 180,
      wordLeadMs: 360,
      manualWordEndRatios: <double>[],
    ),
    _StorySyncPageConfig(
      pageEndFraction: 0.453,
      transitionLeadMs: 190,
      wordLeadMs: 300,
      manualWordEndRatios: <double>[],
    ),
    _StorySyncPageConfig(
      pageEndFraction: 0.734,
      transitionLeadMs: 180,
      wordLeadMs: 340,
      manualWordEndRatios: <double>[],
    ),
    _StorySyncPageConfig(
      pageEndFraction: 1.0,
      transitionLeadMs: 120,
      wordLeadMs: 180,
      manualWordEndRatios: <double>[],
    ),
  ];

  Timer? _positionPoller;

  List<_StoryPageTiming> _pageTimings = const <_StoryPageTiming>[];
  Duration _storyDuration = _fallbackStoryDuration;
  Duration _currentPosition = Duration.zero;
  int _pageIndex = 0;
  int _highlightedWordIndex = -1;
  bool _isPlaying = false;
  bool _isPreparingAudio = false;
  bool _isAudioReady = false;
  bool _isBuffering = false;
  bool _didFinishStory = false;
  String? _audioErrorMessage;
  int _audioSessionToken = 0;
  late final List<List<double>> _pageWordEndRatios =
      List<List<double>>.generate(
        _storyPages.length,
        (index) => _buildWordEndRatios(index, _storyPages[index].text),
        growable: false,
      );

  _StoryPageData get _currentPage => _storyPages[_pageIndex];
  bool get _isLastPage => _pageIndex == _storyPages.length - 1;
  bool get _supportsNativeStoryAudio =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    _pageTimings = _buildPageTimings(_fallbackStoryDuration);
  }

  @override
  void dispose() {
    _audioSessionToken++;
    _positionPoller?.cancel();
    unawaited(_invokeNativeAudioMethod('stopStoryAudio'));
    unawaited(_invokeNativeAudioMethod('disposeStoryAudio'));
    super.dispose();
  }

  Future<void> _prepareStoryAudio() async {
    final sessionToken = ++_audioSessionToken;
    developer.log('sleep_story: prepare start', name: 'sleep_story_audio');
    if (!_isActiveAudioSession(sessionToken)) {
      developer.log(
        'sleep_story: prepare aborted before start',
        name: 'sleep_story_audio',
      );
      return;
    }

    if (!_supportsNativeStoryAudio) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isPreparingAudio = false;
        _isAudioReady = false;
        _isBuffering = false;
        _audioErrorMessage =
            'تشغيل الصوت متاح حالياً على Android فقط داخل هذه الشاشة.';
      });
      return;
    }

    try {
      setState(() {
        _isPreparingAudio = true;
        _isBuffering = false;
        _audioErrorMessage = null;
      });
      _positionPoller?.cancel();
      await _invokeNativeAudioMethod('stopStoryAudio');

      final response = await _storyAudioChannel
          .invokeMapMethod<String, dynamic>('loadStoryAudio', {
            'assetPath': _storyAudioAssetPath,
          })
          .timeout(const Duration(seconds: 6));
      final state = _normalizeStateMap(response);
      final resolvedDuration = Duration(
        milliseconds: _readIntValue(
          state['durationMs'],
          fallback: _fallbackStoryDuration.inMilliseconds,
        ),
      );
      developer.log(
        'sleep_story: asset loaded duration=${resolvedDuration.inMilliseconds}',
        name: 'sleep_story_audio',
      );

      if (!_isActiveAudioSession(sessionToken)) {
        developer.log(
          'sleep_story: prepare aborted after load',
          name: 'sleep_story_audio',
        );
        return;
      }
      _restartPositionPolling();

      if (!_isActiveAudioSession(sessionToken)) {
        return;
      }

      setState(() {
        _storyDuration = resolvedDuration;
        _pageTimings = _buildPageTimings(resolvedDuration);
        _highlightedWordIndex = _highlightedWordIndexForPosition(
          0,
          Duration.zero,
        );
        _currentPosition = Duration.zero;
        _isPlaying = state['playing'] == true;
        _isPreparingAudio = false;
        _isAudioReady = true;
        _isBuffering = false;
        _audioErrorMessage = null;
      });
      developer.log('sleep_story: prepare success', name: 'sleep_story_audio');
    } catch (error, stackTrace) {
      developer.log(
        'sleep_story: prepare failed',
        name: 'sleep_story_audio',
        error: error,
        stackTrace: stackTrace,
      );
      if (!_isActiveAudioSession(sessionToken)) {
        return;
      }
      setState(() {
        _storyDuration = _fallbackStoryDuration;
        _pageTimings = _buildPageTimings(_fallbackStoryDuration);
        _isPreparingAudio = false;
        _isAudioReady = false;
        _audioErrorMessage =
            'تعذر تشغيل الملف الصوتي. يمكنك متابعة القصة يدوياً الآن.';
      });
    }
  }

  bool _isActiveAudioSession(int token) {
    return mounted && _audioSessionToken == token;
  }

  void _restartPositionPolling() {
    _positionPoller?.cancel();
    _positionPoller = Timer.periodic(
      _audioPollInterval,
      (_) => unawaited(_pollNativeAudioState()),
    );
  }

  Future<void> _pollNativeAudioState() async {
    if (!mounted || !_isAudioReady || !_supportsNativeStoryAudio) {
      return;
    }

    try {
      final response = await _storyAudioChannel
          .invokeMapMethod<String, dynamic>('getStoryAudioState');
      if (!mounted) {
        return;
      }
      final state = _normalizeStateMap(response);
      final position = Duration(
        milliseconds: _readIntValue(state['positionMs']),
      );
      final isPlaying = state['playing'] == true;
      final isCompleted = state['completed'] == true;

      if (_isPlaying != isPlaying) {
        setState(() {
          _isPlaying = isPlaying;
          _isBuffering = false;
        });
      }

      _handleAudioPositionChanged(position);

      if (_hasReachedNarrationEnd(position) || isCompleted) {
        unawaited(_finishStory(autoTriggered: true));
      }
    } catch (_) {
      // Keep the story readable even if a polling tick fails.
    }
  }

  void _handleAudioPositionChanged(Duration position) {
    if (!mounted || _pageTimings.isEmpty) {
      return;
    }

    final clampedPosition = _clampPosition(position);
    final rawPageIndex = _pageIndexForPosition(clampedPosition);
    final nextPageIndex = _pageIndexForPosition(
      _clampPosition(
        clampedPosition + _transitionLeadOffsetForPage(rawPageIndex),
      ),
    );
    final nextHighlightedWordIndex = _highlightedWordIndexForPosition(
      nextPageIndex,
      clampedPosition,
    );

    if (nextPageIndex == _pageIndex &&
        nextHighlightedWordIndex == _highlightedWordIndex &&
        clampedPosition.inSeconds == _currentPosition.inSeconds) {
      return;
    }

    setState(() {
      _currentPosition = clampedPosition;
      _pageIndex = nextPageIndex;
      _highlightedWordIndex = nextHighlightedWordIndex;
    });
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

  Future<void> _invokeNativeAudioMethod(
    String method, [
    Map<String, dynamic>? arguments,
  ]) async {
    if (!_supportsNativeStoryAudio) {
      return;
    }
    try {
      await _storyAudioChannel.invokeMethod<void>(method, arguments);
    } catch (_) {
      // Ignore non-critical cleanup calls.
    }
  }

  Future<void> _togglePlayback() async {
    developer.log(
      'sleep_story: toggle start ready=$_isAudioReady',
      name: 'sleep_story_audio',
    );
    if (!_isAudioReady) {
      await _prepareStoryAudio();
    }

    if (_audioErrorMessage != null ||
        !_isAudioReady ||
        !_supportsNativeStoryAudio) {
      developer.log(
        'sleep_story: toggle aborted error=$_audioErrorMessage ready=$_isAudioReady native=$_supportsNativeStoryAudio',
        name: 'sleep_story_audio',
      );
      return;
    }

    if (_isPlaying) {
      developer.log('sleep_story: pause request', name: 'sleep_story_audio');
      await _invokeNativeAudioMethod('pauseStoryAudio');
      if (!mounted) {
        return;
      }
      setState(() {
        _isPlaying = false;
        _isBuffering = false;
      });
      return;
    }

    developer.log('sleep_story: play request', name: 'sleep_story_audio');
    setState(() {
      _isBuffering = true;
    });
    await _invokeNativeAudioMethod('playStoryAudio');
    developer.log('sleep_story: play returned', name: 'sleep_story_audio');
    if (!mounted) {
      return;
    }
    setState(() {
      _isPlaying = true;
      _isBuffering = false;
    });
  }

  Future<void> _skipToNextPage() async {
    if (_isLastPage) {
      await _finishStory();
      return;
    }

    final nextPageIndex = _pageIndex + 1;
    final nextStart = nextPageIndex < _pageTimings.length
        ? _pageTimings[nextPageIndex].start
        : Duration.zero;

    if (_isAudioReady && _supportsNativeStoryAudio) {
      await _invokeNativeAudioMethod('seekStoryAudio', {
        'positionMs': nextStart.inMilliseconds,
      });
      await _invokeNativeAudioMethod('playStoryAudio');
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _pageIndex = nextPageIndex;
      _currentPosition = nextStart;
      _highlightedWordIndex = _highlightedWordIndexForPosition(
        nextPageIndex,
        nextStart,
      );
    });
  }

  Future<void> _finishStory({bool autoTriggered = false}) async {
    if (_didFinishStory) {
      return;
    }
    _didFinishStory = true;
    _audioSessionToken++;
    _positionPoller?.cancel();

    await _invokeNativeAudioMethod('stopStoryAudio');

    if (autoTriggered) {
      await Future<void>.delayed(const Duration(milliseconds: 700));
    }

    if (!mounted) {
      return;
    }
    context.go('/child-home/hero-reward?task=sleep-story');
  }

  void _closeScreen() {
    _audioSessionToken++;
    _positionPoller?.cancel();
    unawaited(_invokeNativeAudioMethod('stopStoryAudio'));
    final router = GoRouter.of(context);
    if (router.canPop()) {
      context.pop();
      return;
    }
    context.go('/child-home/daily-home');
  }

  Duration _clampPosition(Duration position) {
    if (position < Duration.zero) {
      return Duration.zero;
    }
    if (position > _storyDuration) {
      return _storyDuration;
    }
    return position;
  }

  Duration _effectiveNarrationEndPosition() {
    final totalMilliseconds = _storyDuration.inMilliseconds;
    final safeEndTrimMs = _storyNarrationEndTrimMs.clamp(
      0,
      totalMilliseconds > 1 ? totalMilliseconds - 1 : 0,
    );
    return Duration(milliseconds: totalMilliseconds - safeEndTrimMs);
  }

  bool _hasReachedNarrationEnd(Duration position) {
    final totalMilliseconds = _storyDuration.inMilliseconds;
    final finishGraceMs = _storyFinishGraceMs.clamp(
      0,
      totalMilliseconds > 1 ? totalMilliseconds - 1 : 0,
    );
    final finishPosition = _clampPosition(
      _effectiveNarrationEndPosition() + Duration(milliseconds: finishGraceMs),
    );
    return position >= finishPosition;
  }

  int _pageIndexForPosition(Duration position) {
    for (var i = 0; i < _pageTimings.length; i++) {
      if (position < _pageTimings[i].end) {
        return i;
      }
    }
    return _storyPages.length - 1;
  }

  List<_StoryPageTiming> _buildPageTimings(Duration totalDuration) {
    final timings = <_StoryPageTiming>[];
    final safeDuration = totalDuration > Duration.zero
        ? totalDuration
        : _fallbackStoryDuration;
    final totalMilliseconds = safeDuration.inMilliseconds;
    final narrationEndTrimMs = _storyNarrationEndTrimMs.clamp(
      0,
      totalMilliseconds > 1 ? totalMilliseconds - 1 : 0,
    );
    final narrationStartDelayMs = _storyNarrationStartDelayMs.clamp(
      0,
      totalMilliseconds - narrationEndTrimMs > 1
          ? totalMilliseconds - narrationEndTrimMs - 1
          : 0,
    );
    final narrationEndMilliseconds = totalMilliseconds - narrationEndTrimMs;
    final narrationDurationMilliseconds =
        (narrationEndMilliseconds - narrationStartDelayMs).clamp(
          1,
          totalMilliseconds,
        );
    var previousEndFraction = 0.0;

    for (var i = 0; i < _storyPages.length; i++) {
      final config = _syncConfigForPage(i);
      final minimumEndFraction = (previousEndFraction + 0.01).clamp(0.0, 1.0);
      final maximumEndFraction = i == _storyPages.length - 1 ? 1.0 : 0.99;
      final safeEndFraction = i == _storyPages.length - 1
          ? 1.0
          : config.pageEndFraction
                .clamp(minimumEndFraction, maximumEndFraction)
                .toDouble();
      final start = Duration(
        milliseconds:
            narrationStartDelayMs +
            (narrationDurationMilliseconds * previousEndFraction).round(),
      );
      final end = Duration(
        milliseconds: i == _storyPages.length - 1
            ? narrationEndMilliseconds
            : narrationStartDelayMs +
                  (narrationDurationMilliseconds * safeEndFraction).round(),
      );
      timings.add(_StoryPageTiming(start: start, end: end));
      previousEndFraction = safeEndFraction;
    }

    return timings;
  }

  _StorySyncPageConfig _syncConfigForPage(int pageIndex) {
    if (pageIndex <= 0) {
      return _storySyncConfig.first;
    }
    if (pageIndex >= _storySyncConfig.length) {
      return _storySyncConfig.last;
    }
    return _storySyncConfig[pageIndex];
  }

  Duration _transitionLeadOffsetForPage(int pageIndex) {
    return Duration(
      milliseconds: _syncConfigForPage(pageIndex).transitionLeadMs,
    );
  }

  Duration _wordLeadOffsetForPage(int pageIndex) {
    return Duration(milliseconds: _syncConfigForPage(pageIndex).wordLeadMs);
  }

  double _wordNarrationUnits(String word) {
    final cleanWord = word.replaceAll(RegExp(r'[^\u0600-\u06FFA-Za-z0-9]'), '');
    final baseUnits = cleanWord.runes.isEmpty
        ? 1.0
        : cleanWord.runes.length.clamp(1, 10).toDouble();
    var units = baseUnits;

    if (word.contains('،') || word.contains('؛')) {
      units += 1.0;
    }
    if (word.contains(':')) {
      units += 0.8;
    }
    if (word.contains('!') || word.contains('؟') || word.contains('.')) {
      units += 1.4;
    }

    return units;
  }

  List<double> _buildWordEndRatios(int pageIndex, String text) {
    final manualWordEndRatios = _syncConfigForPage(
      pageIndex,
    ).manualWordEndRatios;
    if (manualWordEndRatios.isNotEmpty) {
      return _sanitizeWordEndRatios(manualWordEndRatios);
    }

    final words = _tokenizeText(text);
    if (words.isEmpty) {
      return const <double>[];
    }

    final units = words.map(_wordNarrationUnits).toList(growable: false);
    final totalUnits = units.fold<double>(0, (sum, value) => sum + value);
    var cumulativeUnits = 0.0;

    return units
        .map((unit) {
          cumulativeUnits += unit;
          return cumulativeUnits / totalUnits;
        })
        .toList(growable: false);
  }

  List<double> _sanitizeWordEndRatios(List<double> ratios) {
    if (ratios.isEmpty) {
      return const <double>[];
    }

    final sanitized = <double>[];
    var previous = 0.0;
    for (var i = 0; i < ratios.length; i++) {
      final maximumValue = i == ratios.length - 1 ? 1.0 : 0.999;
      final currentValue = ratios[i].clamp(previous + 0.001, maximumValue);
      sanitized.add(currentValue.toDouble());
      previous = currentValue.toDouble();
    }
    sanitized[sanitized.length - 1] = 1.0;
    return sanitized;
  }

  List<String> _tokenizeText(String text) {
    return text
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.trim().isNotEmpty)
        .toList(growable: false);
  }

  int _highlightedWordIndexForPosition(int pageIndex, Duration position) {
    if (_pageTimings.isEmpty || pageIndex >= _pageTimings.length) {
      return -1;
    }

    final wordEndRatios = _pageWordEndRatios[pageIndex];
    if (wordEndRatios.isEmpty) {
      return -1;
    }

    final pageTiming = _pageTimings[pageIndex];
    final pageDuration = pageTiming.end - pageTiming.start;
    if (pageDuration <= Duration.zero) {
      return 0;
    }

    final adjustedPosition = _clampPosition(
      position + _wordLeadOffsetForPage(pageIndex),
    );
    if (adjustedPosition < pageTiming.start) {
      return -1;
    }

    final elapsed = adjustedPosition - pageTiming.start;
    final progress = elapsed.inMilliseconds / pageDuration.inMilliseconds;
    for (var i = 0; i < wordEndRatios.length; i++) {
      if (progress <= wordEndRatios[i]) {
        return i;
      }
    }
    return wordEndRatios.length - 1;
  }

  List<TextSpan> _buildHighlightedTextSpans() {
    final words = _tokenizeText(_currentPage.text);

    return List<TextSpan>.generate(words.length, (index) {
      final isCurrentWord = _highlightedWordIndex == index;
      final isReadWord = _highlightedWordIndex > index;

      return TextSpan(
        text: index == words.length - 1 ? words[index] : '${words[index]} ',
        style: TextStyle(
          color: isCurrentWord
              ? const Color(0xFFE6862C)
              : isReadWord
              ? const Color(0xFF2C4B8F)
              : const Color(0xFF30251E),
          fontSize: 17,
          fontWeight: isCurrentWord ? FontWeight.w800 : FontWeight.w600,
          height: 1.8,
        ),
      );
    });
  }

  double get _playbackProgress {
    if (_storyDuration <= Duration.zero) {
      return 0;
    }
    final progress =
        _currentPosition.inMilliseconds / _storyDuration.inMilliseconds;
    return progress.clamp(0, 1).toDouble();
  }

  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds.clamp(0, 5999).toInt();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2EAD8),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              children: [
                SizedBox(
                  height: 292,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(28),
                          bottomRight: Radius.circular(28),
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 280),
                          child: Image.asset(
                            _currentPage.imageAsset,
                            key: ValueKey<String>(_currentPage.imageAsset),
                            fit: BoxFit.cover,
                            alignment: Alignment.center,
                          ),
                        ),
                      ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0x220B1234), Color(0x99141C4A)],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        left: 8,
                        child: _CloseButton(onTap: _closeScreen),
                      ),
                      Positioned(
                        top: 14,
                        right: 14,
                        child: _PageBadge(
                          currentPage: _pageIndex + 1,
                          totalPages: _storyPages.length,
                        ),
                      ),
                      Positioned(
                        right: 20,
                        bottom: 20,
                        left: 20,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _storyTitle,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF7F1E4),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(28),
                        topRight: Radius.circular(28),
                      ),
                    ),
                    transform: Matrix4.translationValues(0, -10, 0),
                    padding: const EdgeInsets.fromLTRB(18, 24, 18, 22),
                    child: Column(
                      children: [
                        _StoryProgressDots(
                          currentIndex: _pageIndex,
                          count: _storyPages.length,
                        ),
                        const SizedBox(height: 18),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            child: SingleChildScrollView(
                              key: ValueKey<int>(_pageIndex),
                              child: Directionality(
                                textDirection: TextDirection.rtl,
                                child: Text.rich(
                                  TextSpan(
                                    children: _buildHighlightedTextSpans(),
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        _StoryAudioControls(
                          isReady: _isAudioReady,
                          isPreparing: _isPreparingAudio,
                          isPlaying: _isPlaying,
                          isBuffering: _isBuffering,
                          errorMessage: _audioErrorMessage,
                          currentPositionLabel: _formatDuration(
                            _currentPosition,
                          ),
                          totalDurationLabel: _formatDuration(_storyDuration),
                          progress: _playbackProgress,
                          onPlayPause: _togglePlayback,
                          onTap: _skipToNextPage,
                          isLastPage: _isLastPage,
                        ),
                      ],
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

class _StoryAdvanceButton extends StatelessWidget {
  const _StoryAdvanceButton({required this.onTap, required this.isLastPage});

  final Future<void> Function() onTap;
  final bool isLastPage;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => unawaited(onTap()),
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          width: 104,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0xFF6B63F1), Color(0xFFCBC7F3)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6B63F1).withValues(alpha: 0.24),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            child: Icon(
              isLastPage ? Icons.check_rounded : Icons.arrow_forward_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }
}

class _PageBadge extends StatelessWidget {
  const _PageBadge({required this.currentPage, required this.totalPages});

  final int currentPage;
  final int totalPages;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xAAFFFFFF),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          '$currentPage / $totalPages',
          style: const TextStyle(
            color: Color(0xFF223164),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _StoryProgressDots extends StatelessWidget {
  const _StoryProgressDots({required this.currentIndex, required this.count});

  final int currentIndex;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        count,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: index == currentIndex ? 24 : 9,
          height: 9,
          decoration: BoxDecoration(
            color: index == currentIndex
                ? const Color(0xFF2C4B8F)
                : const Color(0xFFD6D9E7),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }
}

class _StoryAudioControls extends StatelessWidget {
  const _StoryAudioControls({
    required this.isReady,
    required this.isPreparing,
    required this.isPlaying,
    required this.isBuffering,
    required this.errorMessage,
    required this.currentPositionLabel,
    required this.totalDurationLabel,
    required this.progress,
    required this.onPlayPause,
    required this.onTap,
    required this.isLastPage,
  });

  final bool isReady;
  final bool isPreparing;
  final bool isPlaying;
  final bool isBuffering;
  final String? errorMessage;
  final String currentPositionLabel;
  final String totalDurationLabel;
  final double progress;
  final Future<void> Function() onPlayPause;
  final Future<void> Function() onTap;
  final bool isLastPage;

  @override
  Widget build(BuildContext context) {
    final hasError = errorMessage != null && errorMessage!.trim().isNotEmpty;

    return Column(
      children: [
        _StoryAdvanceButton(onTap: onTap, isLastPage: isLastPage),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: !isPreparing && !isBuffering && !hasError
                    ? () => unawaited(onPlayPause())
                    : null,
                borderRadius: BorderRadius.circular(30),
                child: Ink(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: hasError
                        ? const Color(0xFFCF5F4E)
                        : const Color(0xFF5E5CEB),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color:
                            (hasError
                                    ? const Color(0xFFCF5F4E)
                                    : const Color(0xFF5E5CEB))
                                .withValues(alpha: 0.22),
                        blurRadius: 14,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Center(
                    child: isPreparing || isBuffering
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            hasError
                                ? Icons.error_outline_rounded
                                : isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 34,
                          ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _WaveformTrack(
                progress: progress,
                isPlaying: isPlaying,
                isReady: isReady,
                hasError: hasError,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (hasError)
          Text(
            errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF8D2D20),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          )
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                currentPositionLabel,
                style: const TextStyle(
                  color: Color(0xFF6A62F2),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                totalDurationLabel,
                style: const TextStyle(
                  color: Color(0xFF6A62F2),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _WaveformTrack extends StatelessWidget {
  const _WaveformTrack({
    required this.progress,
    required this.isPlaying,
    required this.isReady,
    required this.hasError,
  });

  static const List<double> _bars = [
    12,
    18,
    24,
    14,
    20,
    16,
    26,
    17,
    23,
    15,
    28,
    18,
    22,
    30,
    18,
    24,
    16,
    29,
    21,
    15,
    25,
    17,
    27,
    18,
    22,
    14,
    20,
    12,
  ];

  final double progress;
  final bool isPlaying;
  final bool isReady;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final activeBarIndex = (_bars.length * progress).floor().clamp(
      0,
      _bars.length - 1,
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: List<Widget>.generate(_bars.length, (index) {
        final isActive = isReady && index <= activeBarIndex;
        final isCurrent = isReady && index == activeBarIndex;
        final color = hasError
            ? const Color(0xFFCF5F4E)
            : isActive
            ? const Color(0xFF5E5CEB)
            : const Color(0xFFC8C2FF);
        final extraHeight = isPlaying && isCurrent ? 6.0 : 0.0;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 4,
          height: _bars[index] + extraHeight,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            boxShadow: isCurrent && !hasError
                ? [
                    BoxShadow(
                      color: const Color(0xFF5E5CEB).withValues(alpha: 0.18),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
        );
      }),
    );
  }
}
