import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:risha_v01/shared/config/feature_flags.dart';
import 'package:risha_v01/shared/services/child_behavior_service.dart';
import 'package:risha_v01/shared/services/device_sleep_lock_service.dart';
import 'package:risha_v01/shared/services/local_notification_service.dart';
import 'package:risha_v01/shared/services/selected_child_service.dart';
import 'package:risha_v01/shared/services/session_progress_service.dart';

class SleepRoutineScreen extends StatefulWidget {
  const SleepRoutineScreen({super.key});

  @override
  State<SleepRoutineScreen> createState() => _SleepRoutineScreenState();
}

class _SleepRoutineScreenState extends State<SleepRoutineScreen>
    with WidgetsBindingObserver {
  TimeOfDay _sleepTime = const TimeOfDay(hour: 0, minute: 0);
  bool _notificationsEnabled = true;
  final _sessionProgressService = SessionProgressService();
  final _selectedChildService = SelectedChildService();
  final _childBehaviorService = ChildBehaviorService();
  final _deviceSleepLockService = DeviceSleepLockService();
  final _localNotificationService = LocalNotificationService.instance;
  Timer? _sleepHintTimer;

  String? _selectedChildId;
  bool _isLoadingConfig = true;
  bool _isSaving = false;
  bool _isSleepHintVisible = false;
  bool _isCheckingOverlayPermission = false;
  bool _overlayPermissionGranted = true;
  bool _awaitingOverlayPermissionReturn = false;
  bool _pendingCompletedSetupSave = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(
      _sessionProgressService.saveChildSetupRoute('/child-home/sleep-routine'),
    );
    unawaited(_loadSleepRoutine());
    unawaited(_refreshOverlayPermissionStatus());
  }

  Future<void> _loadSleepRoutine() async {
    try {
      final childId = await _selectedChildService.getSelectedChildId();
      if (!mounted) {
        return;
      }
      if (childId == null || childId.isEmpty) {
        _redirectToProfiles('يرجى اختيار الطفل أولاً.');
        return;
      }

      final config = await _childBehaviorService.getChildBehaviorConfig(
        childId: childId,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _selectedChildId = childId;
        _sleepTime = TimeOfDay(
          hour: config.sleepHour,
          minute: config.sleepMinute,
        );
        _notificationsEnabled = config.sleepNotificationsEnabled;
        _isLoadingConfig = false;
      });
    } on ChildBehaviorFailure catch (e) {
      if (!mounted) {
        return;
      }
      _showError(e.message);
      _redirectToProfiles();
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showError('تعذر تحميل إعدادات النوم حالياً.');
      _redirectToProfiles();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state != AppLifecycleState.resumed) {
      return;
    }
    unawaited(_handleAppResumed());
  }

  Future<void> _handleAppResumed() async {
    await _refreshOverlayPermissionStatus();
    if (!_awaitingOverlayPermissionReturn || !_overlayPermissionGranted) {
      return;
    }

    _awaitingOverlayPermissionReturn = false;
    await _completeSleepSaveFlow(setupCompleted: _pendingCompletedSetupSave);
    _pendingCompletedSetupSave = false;
  }

  Future<void> _completeSleepSaveFlow({required bool setupCompleted}) async {
    if (setupCompleted) {
      final childId = _selectedChildId;
      if (childId != null && childId.isNotEmpty) {
        await _childBehaviorService.syncDeviceSleepLockForChild(
          childId: childId,
        );
      } else {
        unawaited(_deviceSleepLockService.refreshSleepLock());
      }
    } else {
      unawaited(_deviceSleepLockService.refreshSleepLock());
    }

    if (!mounted) {
      return;
    }
    _goAfterSleepSave(setupCompleted: setupCompleted);
  }

  Future<void> _refreshOverlayPermissionStatus() async {
    if (_isCheckingOverlayPermission) {
      return;
    }

    _isCheckingOverlayPermission = true;
    final granted = await _deviceSleepLockService.isOverlayPermissionGranted();
    _isCheckingOverlayPermission = false;
    if (!mounted) {
      return;
    }
    setState(() {
      _overlayPermissionGranted = granted;
    });
  }

  Future<void> _pickSleepTime() async {
    if (_isSaving || _isLoadingConfig) {
      return;
    }
    final picked = await showTimePicker(
      context: context,
      initialTime: _sleepTime,
      initialEntryMode: TimePickerEntryMode.dial,
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (picked == null) {
      return;
    }

    setState(() => _sleepTime = picked);
  }

  void _toggleSleepHint() {
    if (_isSleepHintVisible) {
      _hideSleepHint();
      return;
    }
    _showSleepHint();
  }

  void _showSleepHint() {
    _sleepHintTimer?.cancel();
    setState(() => _isSleepHintVisible = true);
    _sleepHintTimer = Timer(const Duration(seconds: 15), () {
      if (!mounted) {
        return;
      }
      setState(() => _isSleepHintVisible = false);
    });
  }

  void _hideSleepHint() {
    _sleepHintTimer?.cancel();
    if (!mounted) {
      return;
    }
    setState(() => _isSleepHintVisible = false);
  }

  String get _formattedTime {
    final hour12 = _sleepTime.hour % 12 == 0 ? 12 : _sleepTime.hour % 12;
    final minute = _sleepTime.minute;
    final period = _sleepTime.hour >= 12 ? 'PM' : 'AM';
    return '${hour12.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
  }

  Future<void> _saveSleepAndContinue() async {
    if (_isSaving || _isLoadingConfig) {
      return;
    }
    final childId = _selectedChildId;
    if (childId == null || childId.isEmpty) {
      _redirectToProfiles('يرجى اختيار الطفل أولاً.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final setupCompleted = await _sessionProgressService
          .hasCompletedChildSetup();
      await _childBehaviorService.saveSleepRoutine(
        childId: childId,
        hour: _sleepTime.hour,
        minute: _sleepTime.minute,
        notificationsEnabled: _notificationsEnabled,
      );
      unawaited(_syncNotificationsIfSetupCompleted());
      if (FeatureFlags.disableSleepLockTemporarily) {
        if (!mounted) {
          return;
        }
        _goAfterSleepSave(setupCompleted: setupCompleted);
        return;
      }
      if (_notificationsEnabled) {
        await _refreshOverlayPermissionStatus();
      }
      if (!mounted) {
        return;
      }

      if (_notificationsEnabled && !_overlayPermissionGranted) {
        setState(() {
          _isSaving = false;
          _awaitingOverlayPermissionReturn = true;
          _pendingCompletedSetupSave = setupCompleted;
        });
        await _openSystemOverlayPermission();
        return;
      }

      await _completeSleepSaveFlow(setupCompleted: setupCompleted);
    } on ChildBehaviorFailure catch (e) {
      if (!mounted) {
        return;
      }
      _showError(e.message);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showError('تعذر حفظ إعدادات النوم حالياً.');
    } finally {
      if (mounted && !_awaitingOverlayPermissionReturn) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _syncNotificationsIfSetupCompleted() async {
    final isSetupCompleted = await _sessionProgressService
        .hasCompletedChildSetup();
    if (!isSetupCompleted) {
      return;
    }
    _localNotificationService.syncSelectedChildNotificationsInBackground();
  }

  Future<void> _openSystemOverlayPermission() async {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'سيتم فتح إعداد نظام أندرويد الخاص بإذن الظهور فوق التطبيقات الأخرى. فعّله ثم عد إلى التطبيق.',
          ),
          duration: Duration(seconds: 5),
        ),
      );
    await _deviceSleepLockService.openOverlayPermissionSettings();
  }

  void _goToNextStep() {
    final pinRoute = Uri(
      path: '/child-home/pin',
      queryParameters: const {
        'next': '/child-home/setup-preparing',
        'back': '/child-home/sleep-routine',
      },
    );
    context.go(pinRoute.toString());
  }

  void _goAfterSleepSave({required bool setupCompleted}) {
    if (setupCompleted) {
      context.go('/child-home/settings');
      return;
    }
    _goToNextStep();
  }

  void _redirectToProfiles([String? message]) {
    if (message != null) {
      _showError(message);
    }
    setState(() => _isLoadingConfig = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.go('/child-home/profiles');
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _goBack() {
    final router = GoRouter.of(context);
    if (router.canPop()) {
      context.pop();
    } else {
      context.go('/child-home/behaviors');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sleepHintTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F1E2),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth >= 720
                ? 72.0
                : constraints.maxWidth >= 480
                ? 40.0
                : 20.0;

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                        vertical: 16,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Directionality(
                            textDirection: TextDirection.ltr,
                            child: Row(
                              children: [
                                IconButton(
                                  onPressed: _goBack,
                                  icon: const Icon(Icons.arrow_back),
                                ),
                                const Spacer(),
                                IconButton(
                                  onPressed: _toggleSleepHint,
                                  tooltip: _isSleepHintVisible
                                      ? 'إخفاء التلميح'
                                      : 'إظهار التلميح',
                                  icon: Icon(
                                    _isSleepHintVisible
                                        ? Icons.lightbulb
                                        : Icons.lightbulb_outline,
                                    color: const Color(0xFFD6A23C),
                                    size: 22,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Center(
                            child: Image.asset(
                              'assets/risha/risha_sleep.png',
                              height: constraints.maxWidth >= 480 ? 170 : 200,
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'حدد وقت نوم الشخصية الافتراضية',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: const Color(0xFFD6A23C),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'وسيتمكن التطبيق من حجب استخدام الهاتف لطفلك\nعند وقت النوم المحدد بشكل تلقائي',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: const Color(0xFFB48C6A),
                              height: 1.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 24),
                          if (_isLoadingConfig)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 40),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          else ...[
                            _TimeDisplay(
                              timeLabel: _formattedTime,
                              onTap: _pickSleepTime,
                            ),
                            const SizedBox(height: 20),
                            _NotificationsCard(
                              enabled: _notificationsEnabled,
                              onChanged: (value) {
                                if (_isSaving) {
                                  return;
                                }
                                setState(() {
                                  _notificationsEnabled = value;
                                });
                              },
                            ),
                            if (_notificationsEnabled &&
                                !FeatureFlags.disableSleepLockTemporarily) ...[
                              const SizedBox(height: 14),
                              _OverlayPermissionCard(
                                granted: _overlayPermissionGranted,
                                isChecking: _isCheckingOverlayPermission,
                                onOpenSettings: _openSystemOverlayPermission,
                              ),
                            ],
                            const SizedBox(height: 28),
                            _ContinueButton(
                              isBusy: _isSaving,
                              onTap: _saveSleepAndContinue,
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (_isSleepHintVisible)
                      const PositionedDirectional(
                        top: 48,
                        end: 8,
                        child: _SleepHintPopupCard(),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/*
class _SleepHintCard extends StatelessWidget {
  const _SleepHintCard();

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      width: 250,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: const LinearGradient(
          colors: [Color(0xFF62BBA0), Color(0xFF8FD0B9)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6A57A6).withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: const Text(
        'حسب الدراسات النوم الموصى به يومياً:\n'
                'حسب الدراسات النوم الموصى به يومياً:\n'
                '• من عمر 6 إلى 12 سنة: 9-12 ساعة.\n'
                '• من عمر 13 إلى 18 سنة: 8-10 ساعات.',
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  height: 1.45,
                ),
              )
            : const SizedBox(
                key: ValueKey('sleep-hint-hidden'),
                height: 14,
                width: double.infinity,
              ),
      ),
    );
  }
}
*/

class _SleepHintPopupCard extends StatelessWidget {
  const _SleepHintPopupCard();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      elevation: 10,
      borderRadius: BorderRadius.circular(14),
      shadowColor: const Color(0x406A57A6),
      child: Container(
        width: 250,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            colors: [Color(0xFF62BBA0), Color(0xFF8FD0B9)],
          ),
        ),
        child: const Text(
          'حسب الدراسات النوم الموصى به يومياً:\n'
          '• من عمر 6 إلى 12 سنة: 9-12 ساعة.\n'
          '• من عمر 13 إلى 18 سنة: 8-10 ساعات.',
          textAlign: TextAlign.right,
          style: TextStyle(
            color: Colors.white,
            fontSize: 11,
            height: 1.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _TimeDisplay extends StatelessWidget {
  const _TimeDisplay({required this.timeLabel, required this.onTap});

  final String timeLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                timeLabel,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFD6A23C),
                  fontSize: 25,
                  letterSpacing: 2.2,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'اضغط على الوقت لتعديله',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFFBFA17F), fontSize: 12),
        ),
      ],
    );
  }
}

class _NotificationsCard extends StatelessWidget {
  const _NotificationsCard({required this.enabled, required this.onChanged});

  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: const LinearGradient(
          colors: [Color(0xFF4DA07D), Color(0xFF75BEA1)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6A57A6).withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          children: [
            Switch(
              value: enabled,
              onChanged: onChanged,
              activeThumbColor: const Color(0xFF4DA07D),
              activeTrackColor: Colors.white,
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: const Color(0x99FFFFFF),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'تفعيل قفل الهاتف وقت النوم',
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverlayPermissionCard extends StatelessWidget {
  const _OverlayPermissionCard({
    required this.granted,
    required this.isChecking,
    required this.onOpenSettings,
  });

  final bool granted;
  final bool isChecking;
  final Future<void> Function() onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final accentColor = granted
        ? const Color(0xFF2C9A63)
        : const Color(0xFFC97E2B);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentColor.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                granted
                    ? Icons.verified_user_rounded
                    : Icons.warning_amber_rounded,
                color: accentColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  granted
                      ? 'تم تفعيل صلاحية النظام الخاصة بحجب الهاتف.'
                      : 'هذه الميزة تحتاج صلاحية نظام خاصة اسمها: الظهور فوق التطبيقات الأخرى.',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'هذه ليست إذنًا عاديًا، لذلك لن تظهر ضمن صفحة "أذونات التطبيق" العامة داخل أندرويد.',
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Color(0xFF8B6F5C),
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: isChecking ? null : () => unawaited(onOpenSettings()),
              icon: const Icon(Icons.open_in_new_rounded),
              label: Text(
                granted ? 'فتح إعداد الصلاحية' : 'تفعيل صلاحية النظام',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContinueButton extends StatelessWidget {
  const _ContinueButton({required this.onTap, required this.isBusy});

  final VoidCallback onTap;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 230,
        height: 56,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              colors: isBusy
                  ? const [Color(0xFF9DBDAC), Color(0xFFB7CFBF)]
                  : const [Color(0xFF1F8A3D), Color(0xFF5DA57F)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6A57A6).withValues(alpha: 0.2),
                blurRadius: 12,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(28),
              onTap: isBusy ? null : onTap,
              child: Center(
                child: isBusy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.3,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'متابعة',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
