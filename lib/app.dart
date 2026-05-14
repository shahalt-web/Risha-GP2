import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:risha_v01/app_router.dart';
import 'package:risha_v01/shared/config/feature_flags.dart';
import 'package:risha_v01/shared/services/background_startup_coordinator.dart';
import 'package:risha_v01/shared/services/child_reward_service.dart';
import 'package:risha_v01/shared/services/device_sleep_lock_service.dart';
import 'package:risha_v01/shared/services/device_usage_service.dart';
import 'package:risha_v01/shared/services/email_notification_service.dart';
import 'package:risha_v01/shared/services/local_notification_service.dart';
import 'package:risha_v01/shared/services/selected_child_service.dart';
import 'package:risha_v01/shared/theme/app_theme.dart';
import 'package:risha_v01/shared/widgets/overlay_permission_startup_gate.dart';
import 'package:risha_v01/shared/widgets/usage_access_permission_startup_gate.dart';

class RishaApp extends StatefulWidget {
  const RishaApp({super.key});

  @override
  State<RishaApp> createState() => _RishaAppState();
}

class _RishaAppState extends State<RishaApp> with WidgetsBindingObserver {
  static const Duration _usageFlowStartupDelay = Duration(seconds: 20);
  static const Duration _usageCheckInterval = Duration(seconds: 30);
  static const Duration _usageThreshold = Duration(minutes: 10);
  static const Duration _restDuration = Duration(minutes: 3);
  static const int _maxUsageRestCyclesPerDay = 3;
  static const int _restRewardCoins = 50;
  static const String _usageRestStatePrefsKey = 'risha_usage_rest_state_v1';
  static const Set<String> _usageFlowRoutePrefixes = <String>{
    '/child-home/daily-home',
    '/child-home/brush-time',
    '/child-home/exercising',
    '/child-home/hero-reward',
    '/child-home/market',
    '/child-home/quran-reading',
    '/child-home/shape-matching',
    '/child-home/sleep-story',
    '/child-home/water-drink',
    '/child-home/custom-behavior',
    '/child-home/welcome-egg',
    '/child-home/welcome-greeting',
  };

  final _deviceSleepLockService = DeviceSleepLockService();
  final _deviceUsageService = DeviceUsageService();
  final _localNotificationService = LocalNotificationService.instance;
  final _childRewardService = ChildRewardService();
  final _emailNotificationService = EmailNotificationService();
  final _selectedChildService = SelectedChildService();
  final _backgroundStartupCoordinator = BackgroundStartupCoordinator();

  Timer? _usageCheckTimer;
  Timer? _usageFlowStartTimer;
  bool _usageFlowEnabled = false;
  bool _isUsageSyncInProgress = false;
  bool _isUsageStateLoaded = false;
  bool _hasSelectedChild = false;

  DateTime? _usageCycleStartedAt;
  String? _usageCycleDateKey;
  int _usageCycleCount = 0;
  DateTime? _restEndsAt;
  bool _restRewardPending = false;
  String? _lastRewardDateKey;

  bool _showRestRewardOverlay = false;

  bool get _isChildRouteActive {
    final routePath = appRouter.routeInformationProvider.value.uri.path;
    return _usageFlowRoutePrefixes.any(routePath.startsWith);
  }

  Duration get _effectiveUsageThreshold {
    return FeatureFlags.enableUsageRestQuickTestMode
        ? FeatureFlags.usageRestQuickTestDelay
        : _usageThreshold;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    appRouter.routeInformationProvider.addListener(_handleRouteChanged);

    _usageFlowStartTimer = Timer(_usageFlowStartupDelay, () {
      if (!mounted) {
        return;
      }
      _usageFlowEnabled = true;
      _usageCheckTimer?.cancel();
      _usageCheckTimer = Timer.periodic(_usageCheckInterval, (_) {
        unawaited(_syncUsageFlow());
      });
      unawaited(_syncUsageFlow());
    });

    unawaited(_refreshSelectedChildState());
    unawaited(_loadUsageRestState());
    _emailNotificationService.flushDurableOutboxInBackground();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (FeatureFlags.disableSleepLockTemporarily) {
        _deviceSleepLockService.clearSleepLockConfig();
      }
      unawaited(_handleAppResumed());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    appRouter.routeInformationProvider.removeListener(_handleRouteChanged);
    _backgroundStartupCoordinator.dispose();
    _usageCheckTimer?.cancel();
    _usageFlowStartTimer?.cancel();
    super.dispose();
  }

  void _handleRouteChanged() {
    if (!mounted) {
      return;
    }
    unawaited(_refreshSelectedChildState());
    setState(() {});
    _updateBackgroundStartupEligibility();
    unawaited(_syncUsageFlow());
  }

  Future<void> _handleAppResumed() async {
    _emailNotificationService.flushDurableOutboxInBackground();
    await _refreshSelectedChildState();
    if (!mounted) {
      return;
    }

    _updateBackgroundStartupEligibility();
    if (!_usageFlowEnabled || !_hasSelectedChild) {
      return;
    }

    if (_backgroundStartupCoordinator.isActivated) {
      _localNotificationService.syncSelectedChildNotificationsInBackground();
    }
    await _syncUsageFlow();
  }

  Future<void> _refreshSelectedChildState() async {
    final hasSelectedChild = await _fetchHasSelectedChild();
    if (!mounted) {
      return;
    }
    if (_hasSelectedChild != hasSelectedChild) {
      setState(() => _hasSelectedChild = hasSelectedChild);
    } else {
      _hasSelectedChild = hasSelectedChild;
    }
    _updateBackgroundStartupEligibility();
  }

  Future<bool> _fetchHasSelectedChild() async {
    final selectedChildId = await _selectedChildService.getSelectedChildId();
    final cleanSelectedChildId = selectedChildId?.trim() ?? '';
    return cleanSelectedChildId.isNotEmpty;
  }

  Future<void> _loadUsageRestState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_usageRestStatePrefsKey);
      if (raw != null && raw.trim().isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final data = decoded.map(
            (key, value) => MapEntry(key.toString(), value),
          );
          final restEndMs = _readInt(data['restEndsAtEpochMs']);
          if (restEndMs != null && restEndMs > 0) {
            _restEndsAt = DateTime.fromMillisecondsSinceEpoch(restEndMs);
          }
          final cycleStartMs = _readInt(data['usageCycleStartedAtEpochMs']);
          if (cycleStartMs != null && cycleStartMs > 0) {
            _usageCycleStartedAt = DateTime.fromMillisecondsSinceEpoch(
              cycleStartMs,
            );
          }
          _usageCycleDateKey = _readNonEmptyString(data['usageCycleDateKey']);
          _usageCycleCount = _readInt(data['usageCycleCount']) ?? 0;
          _restRewardPending = data['restRewardPending'] as bool? ?? false;
          _lastRewardDateKey = _readNonEmptyString(data['lastRewardDateKey']);
        }
      }
    } catch (_) {
      // Ignore local restore errors to keep startup resilient.
    }

    if (!mounted) {
      return;
    }

    final now = DateTime.now();
    final cycleChanged = _ensureUsageCycleForDate(now);
    if (cycleChanged) {
      await _saveUsageRestState();
    }
    await _syncNativeUsageRestMonitor(enabled: _hasSelectedChild);

    setState(() => _isUsageStateLoaded = true);
    if (_usageFlowEnabled) {
      unawaited(_syncUsageFlow());
    }
  }

  Future<void> _saveUsageRestState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _usageRestStatePrefsKey,
        jsonEncode(<String, dynamic>{
          'usageCycleStartedAtEpochMs':
              _usageCycleStartedAt?.millisecondsSinceEpoch,
          'usageCycleDateKey': _usageCycleDateKey,
          'usageCycleCount': _usageCycleCount,
          'restEndsAtEpochMs': _restEndsAt?.millisecondsSinceEpoch,
          'restRewardPending': _restRewardPending,
          'lastRewardDateKey': _lastRewardDateKey,
        }),
      );
    } catch (_) {
      // Ignore persistence failures to avoid blocking UX.
    }
  }

  Future<void> _syncUsageFlow() async {
    if (!_usageFlowEnabled ||
        !_isUsageStateLoaded ||
        _isUsageSyncInProgress ||
        !mounted) {
      return;
    }

    _isUsageSyncInProgress = true;
    try {
      final hasSelectedChild = await _fetchHasSelectedChild();
      if (!mounted) {
        return;
      }
      if (_hasSelectedChild != hasSelectedChild) {
        setState(() => _hasSelectedChild = hasSelectedChild);
      }
      if (!hasSelectedChild) {
        await _syncNativeUsageRestMonitor(enabled: false);
        if (_showRestRewardOverlay) {
          setState(() {
            _showRestRewardOverlay = false;
          });
        }
        return;
      }

      // Read native monitor config to sync state (handles native Decline/Approve)
      final nativeMonitorConfig = await _deviceUsageService
          .getUsageRestMonitorConfig();
      if (nativeMonitorConfig != null) {
        final nativeCycleCount = nativeMonitorConfig['cycleCount'] as int? ?? 0;
        final nativeCycleStartedAtMs =
            nativeMonitorConfig['cycleStartedAtEpochMs'] as int? ?? 0;

        var stateChanged = false;
        if (nativeCycleCount > _usageCycleCount) {
          _usageCycleCount = nativeCycleCount;
          stateChanged = true;
        }
        if (nativeCycleStartedAtMs >
            (_usageCycleStartedAt?.millisecondsSinceEpoch ?? 0)) {
          _usageCycleStartedAt = DateTime.fromMillisecondsSinceEpoch(
            nativeCycleStartedAtMs,
          );
          stateChanged = true;
        }
        if (stateChanged) {
          await _saveUsageRestState();
        }
      }

      final now = DateTime.now();
      final cycleChanged = _ensureUsageCycleForDate(now);
      if (cycleChanged) {
        await _saveUsageRestState();
      }

      // Only enable native monitor if child route is active OR app is backgrounded
      final isAppResumed =
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
      final shouldEnableNativeMonitor =
          _hasSelectedChild && (_isChildRouteActive || !isAppResumed);
      await _syncNativeUsageRestMonitor(enabled: shouldEnableNativeMonitor);

      await _deviceUsageService.stopUsageRestIfExpired();
      final nativeRestState = await _deviceUsageService.getUsageRestState();
      final nativeRestActive = nativeRestState?.active == true;
      final nativeRestEndsAt = nativeRestState?.endsAt;
      if (nativeRestActive && nativeRestEndsAt != null) {
        final discoveredNativeRest =
            _restEndsAt == null ||
            _restEndsAt!.millisecondsSinceEpoch !=
                nativeRestEndsAt.millisecondsSinceEpoch;
        _restEndsAt = nativeRestEndsAt;
        if (discoveredNativeRest && !_restRewardPending) {
          _usageCycleCount = (_usageCycleCount + 1).clamp(
            0,
            _maxUsageRestCyclesPerDay,
          );
          _restRewardPending = true;
        }
        await _saveUsageRestState();
        return;
      }

      if (_restRewardPending &&
          _restEndsAt != null &&
          !now.isBefore(_restEndsAt!)) {
        await _finishRestSession(now: now);
      }

      if (!_isChildRouteActive) {
        return;
      }

      if (_usageCycleCount >= _maxUsageRestCyclesPerDay) {
        return;
      }

      final hasUsageAccess = await _deviceUsageService.isUsageAccessGranted();
      if (!hasUsageAccess) {
        return;
      }

      final cycleStartedAt = _usageCycleStartedAt ?? now;
      final usageMillis = await _deviceUsageService.getActiveUsageMillisSince(
        cycleStartedAt,
      );
      if (usageMillis == null) {
        return;
      }

      if (usageMillis >= _effectiveUsageThreshold.inMilliseconds &&
          !_showRestRewardOverlay) {
        await _deviceUsageService.triggerUsageRestPrompt();
      }
    } finally {
      _isUsageSyncInProgress = false;
    }
  }

  void _updateBackgroundStartupEligibility() {
    _backgroundStartupCoordinator.updateEligibility(
      hasSelectedChild: _hasSelectedChild,
      isChildRouteActive: _isChildRouteActive,
    );
  }

  Future<void> _finishRestSession({required DateTime now}) async {
    var shouldShowReward = false;
    if (_restRewardPending) {
      await _awardRestRewardIfNeeded(now: now);
      _restRewardPending = false;
      _lastRewardDateKey = _dateKey(now);
      shouldShowReward = true;
    }

    _restEndsAt = null;
    _resetUsageCycle(now);
    await _saveUsageRestState();
    await _syncNativeUsageRestMonitor(enabled: _hasSelectedChild);

    if (!mounted) {
      return;
    }
    setState(() {
      if (shouldShowReward) {
        _showRestRewardOverlay = true;
      }
    });
  }

  Future<void> _awardRestRewardIfNeeded({required DateTime now}) async {
    final rewardDateKey = _dateKey(now);
    if (_lastRewardDateKey == rewardDateKey) {
      return;
    }
    try {
      await _childRewardService.awardSelectedChildCoins(
        amount: _restRewardCoins,
      );
    } catch (_) {
      // Keep UX flow non-blocking even if reward write fails.
    }
  }

  void _dismissRestRewardOverlay() {
    if (!mounted) {
      return;
    }
    setState(() => _showRestRewardOverlay = false);
  }

  String _dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  Future<void> _syncNativeUsageRestMonitor({required bool enabled}) async {
    final cycleStartedAt = _usageCycleStartedAt ?? DateTime.now();
    await _deviceUsageService.configureUsageRestMonitor(
      enabled: enabled,
      cycleStartedAt: cycleStartedAt,
      cycleDate: _usageCycleDateKey ?? _dateKey(cycleStartedAt),
      cycleCount: _usageCycleCount,
      threshold: _effectiveUsageThreshold,
      restDuration: _restDuration,
      maxCyclesPerDay: _maxUsageRestCyclesPerDay,
    );
  }

  bool _ensureUsageCycleForDate(DateTime now) {
    final todayKey = _dateKey(now);
    if (_usageCycleDateKey != todayKey || _usageCycleStartedAt == null) {
      _usageCycleDateKey = todayKey;
      _usageCycleStartedAt = now;
      _usageCycleCount = 0;
      return true;
    }
    return false;
  }

  void _resetUsageCycle(DateTime now) {
    _usageCycleDateKey = _dateKey(now);
    _usageCycleStartedAt = now;
  }

  String? _readNonEmptyString(Object? value) {
    if (value is! String) {
      return null;
    }
    final cleanValue = value.trim();
    return cleanValue.isEmpty ? null : cleanValue;
  }

  int? _readInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value.trim());
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final showChildOverlay =
        _isUsageStateLoaded && _isChildRouteActive && _hasSelectedChild;
    return MaterialApp.router(
      title: 'ريشة',
      theme: AppTheme.light(),
      routerConfig: appRouter,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        return OverlayPermissionStartupGate(
          isPermissionGranted:
              _deviceSleepLockService.isOverlayPermissionGranted,
          openPermissionSettings:
              _deviceSleepLockService.openOverlayPermissionSettings,
          child: UsageAccessPermissionStartupGate(
            isPermissionGranted: _deviceUsageService.isUsageAccessGranted,
            openPermissionSettings: _deviceUsageService.openUsageAccessSettings,
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Stack(
                children: [
                  child ?? const SizedBox.shrink(),
                  if (showChildOverlay && _showRestRewardOverlay)
                    Positioned.fill(
                      child: Material(
                        type: MaterialType.transparency,
                        child: _RestRewardOverlay(
                          onClose: _dismissRestRewardOverlay,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ignore: unused_element
class _RestCountdownOverlay extends StatelessWidget {
  const _RestCountdownOverlay({required this.countdownLabel});

  final String countdownLabel;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xBE0E0D0A),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _RestOverlayCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/risha/risha_sleep.png',
                  width: 180,
                  height: 180,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 10),
                const Text(
                  'ريشة يستريح',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF3D3025),
                    fontSize: 30,
                    decoration: TextDecoration.none,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'الوقت المتبقي لنصف ساعة الراحة',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF7E6A52),
                    fontSize: 16,
                    decoration: TextDecoration.none,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEDDB8),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    countdownLabel,
                    style: const TextStyle(
                      color: Color(0xFF3D3025),
                      fontSize: 33,
                      decoration: TextDecoration.none,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
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

class _RestRewardOverlay extends StatelessWidget {
  const _RestRewardOverlay({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xB80F0C09),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _RestOverlayCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/risha/risha_happy.png',
                  width: 170,
                  height: 170,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 12),
                const Text(
                  'ريشة عاد بنشاط اكثر لقد حصلت على 50 نقطة مكافئة على اعطاء ريشة قصداً من الراحة',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF3D3025),
                    fontSize: 20,
                    decoration: TextDecoration.none,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onClose,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2D8B52),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'رائع',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
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
}

class _RestOverlayCard extends StatelessWidget {
  const _RestOverlayCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 330,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8EFD9),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}
