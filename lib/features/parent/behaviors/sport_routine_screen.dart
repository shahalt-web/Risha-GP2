import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:risha_v01/shared/services/child_behavior_service.dart';
import 'package:risha_v01/shared/services/local_notification_service.dart';
import 'package:risha_v01/shared/services/selected_child_service.dart';
import 'package:risha_v01/shared/services/session_progress_service.dart';

class SportRoutineScreen extends StatefulWidget {
  const SportRoutineScreen({super.key});

  @override
  State<SportRoutineScreen> createState() => _SportRoutineScreenState();
}

class _SportRoutineScreenState extends State<SportRoutineScreen> {
  int sessionsCount = 1;
  bool lightActivityEnabled = true;
  List<TimeOfDay> _sessionTimes = <TimeOfDay>[
    const TimeOfDay(hour: 8, minute: 0),
  ];

  final _sessionProgressService = SessionProgressService();
  final _selectedChildService = SelectedChildService();
  final _childBehaviorService = ChildBehaviorService();
  final _localNotificationService = LocalNotificationService.instance;

  String? _selectedChildId;
  bool _isLoadingConfig = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    unawaited(
      _sessionProgressService.saveChildSetupRoute('/child-home/sport-routine'),
    );
    unawaited(_loadSportRoutine());
  }

  Future<void> _loadSportRoutine() async {
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
        sessionsCount = config.sportSessionsCount;
        lightActivityEnabled = config.sportLightActivityEnabled;
        _sessionTimes = _sessionTimesFromMinutes(
          config.sportSessionTimesMinutes,
          sessionsCount,
        );
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
      _showError('تعذر تحميل إعدادات النشاط الرياضي حالياً.');
      _redirectToProfiles();
    }
  }

  List<TimeOfDay> _sessionTimesFromMinutes(List<int> rawTimes, int count) {
    final cleanCount = count.clamp(1, 6).toInt();
    final result = <TimeOfDay>[];

    for (var i = 0; i < cleanCount; i++) {
      if (i < rawTimes.length) {
        final minutes = rawTimes[i].clamp(0, 1439).toInt();
        result.add(TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60));
      } else {
        result.add(_defaultSessionTimeForIndex(i));
      }
    }
    return result;
  }

  TimeOfDay _defaultSessionTimeForIndex(int index) {
    final totalMinutes = ((8 * 60) + (index * 60)) % (24 * 60);
    return TimeOfDay(hour: totalMinutes ~/ 60, minute: totalMinutes % 60);
  }

  void _syncSessionTimesWithCount() {
    if (_sessionTimes.length == sessionsCount) {
      return;
    }
    if (_sessionTimes.length < sessionsCount) {
      for (var i = _sessionTimes.length; i < sessionsCount; i++) {
        _sessionTimes.add(_defaultSessionTimeForIndex(i));
      }
      return;
    }
    _sessionTimes = _sessionTimes.take(sessionsCount).toList();
  }

  void _increment() {
    if (_isLoadingConfig || _isSaving || sessionsCount >= 6) {
      return;
    }
    setState(() {
      sessionsCount++;
      _syncSessionTimesWithCount();
    });
  }

  void _decrement() {
    if (_isLoadingConfig || _isSaving || sessionsCount <= 1) {
      return;
    }
    setState(() {
      sessionsCount--;
      _syncSessionTimesWithCount();
    });
  }

  Future<void> _pickSessionTime(int index) async {
    if (_isLoadingConfig || _isSaving) {
      return;
    }
    if (index < 0 || index >= sessionsCount) {
      return;
    }

    final initialTime = index < _sessionTimes.length
        ? _sessionTimes[index]
        : _defaultSessionTimeForIndex(index);

    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      initialEntryMode: TimePickerEntryMode.dial,
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _syncSessionTimesWithCount();
      _sessionTimes[index] = picked;
    });
  }

  int _toMinutes(TimeOfDay time) => (time.hour * 60) + time.minute;

  String _formatTime(TimeOfDay time) {
    final hour12 = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '${hour12.toString().padLeft(2, '0')} : $minute $period';
  }

  Future<void> _saveSportRoutine() async {
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
      _syncSessionTimesWithCount();
      await _childBehaviorService.saveSportRoutine(
        childId: childId,
        sessionsCount: sessionsCount,
        lightActivityEnabled: lightActivityEnabled,
        sessionTimesMinutes: _sessionTimes
            .take(sessionsCount)
            .map(_toMinutes)
            .toList(),
      );
      unawaited(_syncNotificationsIfSetupCompleted());
      if (!mounted) {
        return;
      }
      context.go('/child-home/behaviors');
    } on ChildBehaviorFailure catch (e) {
      if (!mounted) {
        return;
      }
      _showError(e.message);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showError('تعذر حفظ إعدادات النشاط الرياضي حالياً.');
    } finally {
      if (mounted) {
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F1E2),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F1E2),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: const Text(
          'تخصيص روتين النشاط الرياضي',
          style: TextStyle(
            color: Color(0xFFD6A23C),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _goBack,
            icon: const Icon(Icons.arrow_forward, color: Color(0xFF2A2722)),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(color: Color(0xFF8E8A7F), thickness: 1, height: 1),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_isLoadingConfig)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 70),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              _CardShell(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'حدد عدد مرات النشاط اليومي',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: Color(0xFFB7864E),
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'اختر وقت كل جلسة من قسم التذكيرات',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: Color(0xFFBFA17F),
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Divider(
                      color: Color(0xFFBFA17F),
                      thickness: 1,
                      height: 1,
                    ),
                    const SizedBox(height: 8),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Row(
                        children: [
                          _CounterButton(symbol: '-', onTap: _decrement),
                          Expanded(
                            child: Text(
                              '$sessionsCount',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFFB7864E),
                                fontSize: 28,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          _CounterButton(symbol: '+', onTap: _increment),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _LightActivityCard(
                enabled: lightActivityEnabled,
                onChanged: (value) =>
                    setState(() => lightActivityEnabled = value),
              ),
              if (lightActivityEnabled)
                const Padding(
                  padding: EdgeInsets.only(top: 8, bottom: 4),
                  child: Text(
                    'الوضع الخفيف مفعل',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: Color(0xFF4DA07D),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              _CardShell(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'التذكيرات',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: Color(0xFFB7864E),
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Divider(
                      color: Color(0xFFBFA17F),
                      thickness: 1,
                      height: 1,
                    ),
                    const SizedBox(height: 12),
                    for (var i = 0; i < sessionsCount; i++) ...[
                      _ReminderRow(
                        sessionLabel: 'الجلسة ${i + 1}',
                        timeLabel: _formatTime(
                          i < _sessionTimes.length
                              ? _sessionTimes[i]
                              : _defaultSessionTimeForIndex(i),
                        ),
                        onTap: () => _pickSessionTime(i),
                        enabled: !_isSaving,
                      ),
                      if (i < sessionsCount - 1) const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 90),
              Center(
                child: _SaveButton(isBusy: _isSaving, onTap: _saveSportRoutine),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE8DFC8),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: child,
    );
  }
}

class _CounterButton extends StatelessWidget {
  const _CounterButton({required this.symbol, required this.onTap});

  final String symbol;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 54,
        height: 42,
        child: Center(
          child: Text(
            symbol,
            style: const TextStyle(
              color: Color(0xFFF2EFE8),
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _ReminderRow extends StatelessWidget {
  const _ReminderRow({
    required this.sessionLabel,
    required this.timeLabel,
    required this.onTap,
    required this.enabled,
  });

  final String sessionLabel;
  final String timeLabel;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: enabled ? onTap : null,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  timeLabel,
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    color: enabled
                        ? const Color(0xFFD6A23C)
                        : const Color(0xFFBFA17F),
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
            ),
          ),
          Text(
            sessionLabel,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Color(0xFFB7864E),
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _LightActivityCard extends StatelessWidget {
  const _LightActivityCard({required this.enabled, required this.onChanged});

  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: const LinearGradient(
          colors: [Color(0xFF4DA07D), Color(0xFF75BEA1)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6A57A6).withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          children: [
            Transform.scale(
              scale: 0.78,
              child: Switch(
                value: enabled,
                onChanged: onChanged,
                activeThumbColor: const Color(0xFF4DA07D),
                activeTrackColor: Colors.white,
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: const Color(0x99FFFFFF),
              ),
            ),
            const SizedBox(width: 4),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'تفعيل النشاط الخفيف',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'يعمل كمحفز للنشاط اليومي للطفل في أيام التعب أو المرض',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: Color(0xE8FFFFFF),
                      fontSize: 8,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.onTap, required this.isBusy});

  final VoidCallback onTap;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      height: 44,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: isBusy
                ? const [Color(0xFF9DBDAC), Color(0xFFB7CFBF)]
                : const [Color(0xFF1F8A3D), Color(0xFF5DA57F)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6A57A6).withValues(alpha: 0.18),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: isBusy ? null : onTap,
            child: Center(
              child: isBusy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.3,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'حفظ التغييرات',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
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
