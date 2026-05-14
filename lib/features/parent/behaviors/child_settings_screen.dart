import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:risha_v01/shared/services/auth_service.dart';
import 'package:risha_v01/shared/services/child_behavior_service.dart';
import 'package:risha_v01/shared/services/child_service.dart';
import 'package:risha_v01/shared/services/child_task_progress_service.dart';
import 'package:risha_v01/shared/services/local_notification_service.dart';
import 'package:risha_v01/shared/services/pin_service.dart';
import 'package:risha_v01/shared/services/selected_child_service.dart';

class ChildSettingsScreen extends StatefulWidget {
  const ChildSettingsScreen({super.key});

  @override
  State<ChildSettingsScreen> createState() => _ChildSettingsScreenState();
}

class _ChildSettingsScreenState extends State<ChildSettingsScreen> {
  final _selectedChildService = SelectedChildService();
  final _childBehaviorService = ChildBehaviorService();
  final _childService = ChildService();
  final _childTaskProgressService = ChildTaskProgressService();
  final _pinService = PinService();
  final _authService = AuthService();
  final _localNotificationService = LocalNotificationService.instance;

  bool _isLoading = true;
  String? _errorMessage;
  _ChildSettingsViewModel? _viewModel;
  bool _isForceReloginInProgress = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadSettings());
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final childId = await _selectedChildService.getSelectedChildId();
      if (!mounted) {
        return;
      }
      if (childId == null || childId.isEmpty) {
        throw const ChildBehaviorFailure('يرجى اختيار الطفل أولاً.');
      }

      final behaviorConfigFuture = _childBehaviorService.getChildBehaviorConfig(
        childId: childId,
      );
      final weeklyProgressFuture = () async {
        try {
          return await _childTaskProgressService
              .getSelectedChildWeeklyProgress();
        } on ChildTaskProgressFailure {
          return const ChildWeeklyTaskProgress(
            days: <ChildDailyTaskProgress>[],
          );
        }
      }();
      final childProfileFuture = () async {
        try {
          return await _childService.getChildById(childId: childId);
        } on ChildFailure {
          return ChildProfile(id: childId, name: 'Child');
        }
      }();

      final behaviorConfig = await behaviorConfigFuture;
      final weeklyProgress = await weeklyProgressFuture;
      final childProfile = await childProfileFuture;
      if (!mounted) {
        return;
      }

      setState(() {
        _viewModel = _buildViewModel(
          childId: childId,
          childName: childProfile.name,
          config: behaviorConfig,
          weeklyProgress: weeklyProgress,
        );
        _isLoading = false;
      });
    } on ChildBehaviorFailure catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } on ChildFailure catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'تعذر تحميل إعدادات الطفل حالياً.';
        _isLoading = false;
      });
    }
  }

  _ChildSettingsViewModel _buildViewModel({
    required String childId,
    required String childName,
    required ChildBehaviorConfig config,
    required ChildWeeklyTaskProgress weeklyProgress,
  }) {
    final enabledBehaviorIds = config.selectedBehaviorIds.toSet();
    final practices = <_PracticeItemData>[
      _PracticeItemData(
        title: 'أذكار الصباح',
        isEnabled: enabledBehaviorIds.contains('morning_athkar'),
      ),
      _PracticeItemData(
        title: 'شرب الماء',
        subtitle: 'عدد الأكواب اليومية: ${config.waterCupsCount}',
        hasLink: true,
        isEnabled: enabledBehaviorIds.contains('drink_water'),
      ),
      _PracticeItemData(
        title: 'تنظيف الأسنان',
        subtitle: 'بعد الاستيقاظ، قبل النوم',
        isEnabled: enabledBehaviorIds.contains('brush_teeth'),
      ),
      _PracticeItemData(
        title: 'نشاط رياضي',
        subtitle: 'عدد الجلسات اليومية: ${config.sportSessionsCount}',
        hasLink: true,
        isEnabled: enabledBehaviorIds.contains('sport_activity'),
      ),
      _PracticeItemData(
        title: 'حل لغز',
        subtitle: 'لغز تسلسلي مرتين خلال اليوم',
        isEnabled: enabledBehaviorIds.contains('solve_puzzle'),
      ),
      _PracticeItemData(
        title: 'قراءة قصة',
        subtitle: 'قبل النوم',
        isEnabled: enabledBehaviorIds.contains('read_story'),
      ),
      ...config.customBehaviors.map(
        (behavior) => _PracticeItemData(
          title: behavior.title,
          subtitle: behavior.periods.isEmpty
              ? 'عدد التكرارات: ${behavior.repeatCount}'
              : 'عدد التكرارات: ${behavior.repeatCount} - ${behavior.periods.join('، ')}',
          isEnabled: enabledBehaviorIds.contains(behavior.id),
        ),
      ),
    ];

    final weeklyBars = _buildWeeklyBars(weeklyProgress);
    return _ChildSettingsViewModel(
      childId: childId,
      childName: childName,
      sleepTimeLabel: _formatSleepTime(config.sleepHour, config.sleepMinute),
      sleepPeriodLabel: _formatSleepPeriod(config.sleepHour),
      sleepNotificationsEnabled: config.sleepNotificationsEnabled,
      practices: practices,
      hasWeeklyProgressData: weeklyProgress.hasRecordedData,
      weeklyBars: weeklyBars,
    );
  }

  List<_BarData> _buildWeeklyBars(ChildWeeklyTaskProgress weeklyProgress) {
    if (weeklyProgress.days.isEmpty) {
      return List<_BarData>.generate(7, (index) {
        final date = DateTime.now().subtract(Duration(days: 6 - index));
        return _BarData(
          label: _weekdayLabel(date.weekday),
          green: 0,
          red: 0,
          neutral: 1,
        );
      });
    }

    return weeklyProgress.days
        .map((day) {
          if (day.totalTaskCount <= 0) {
            return _BarData(
              label: _weekdayLabelForDateKey(day.dateKey),
              green: 0,
              red: 0,
              neutral: 1,
            );
          }

          final green = day.completedTaskCount / day.totalTaskCount;
          final red = day.remainingTaskCount / day.totalTaskCount;
          return _BarData(
            label: _weekdayLabelForDateKey(day.dateKey),
            green: green,
            red: red,
          );
        })
        .toList(growable: false);
  }

  String _weekdayLabelForDateKey(String dateKey) {
    final date = DateTime.tryParse(dateKey);
    if (date == null) {
      return '';
    }
    return _weekdayLabel(date.weekday);
  }

  String _weekdayLabel(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'الإثنين';
      case DateTime.tuesday:
        return 'الثلاثاء';
      case DateTime.wednesday:
        return 'الأربعاء';
      case DateTime.thursday:
        return 'الخميس';
      case DateTime.friday:
        return 'الجمعة';
      case DateTime.saturday:
        return 'السبت';
      case DateTime.sunday:
        return 'الأحد';
      default:
        return '';
    }
  }

  String _formatSleepTime(int hour, int minute) {
    final hour12 = hour % 12 == 0 ? 12 : hour % 12;
    return '${hour12.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  String _formatSleepPeriod(int hour) {
    return hour >= 12 ? 'مساءً' : 'صباحاً';
  }

  void _goBack() {
    final router = GoRouter.of(context);
    if (router.canPop()) {
      context.pop();
    } else {
      context.go('/child-home/daily-home');
    }
  }

  void _openPinGateFor({
    required String nextRoute,
    String backRoute = '/child-home/settings',
  }) {
    unawaited(
      _openPinGateForGuarded(nextRoute: nextRoute, backRoute: backRoute),
    );
  }

  Future<void> _openPinGateForGuarded({
    required String nextRoute,
    required String backRoute,
  }) async {
    if (_isForceReloginInProgress) {
      return;
    }

    final childId = (await _selectedChildService.getSelectedChildId())?.trim();
    final hasSavedPin = await _pinService.hasSavedPin(
      childId: childId,
      allowParentFallback: true,
    );
    if (!mounted) {
      return;
    }

    if (!hasSavedPin) {
      await _forceReloginForMissingPin();
      return;
    }

    final pinRoute = Uri(
      path: '/child-home/pin',
      queryParameters: <String, String>{
        'next': nextRoute,
        'back': backRoute,
        'verify': '1',
        'track': '0',
      },
    );
    context.go(pinRoute.toString());
  }

  Future<void> _forceReloginForMissingPin() async {
    if (_isForceReloginInProgress) {
      return;
    }
    _isForceReloginInProgress = true;

    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'لا يوجد رمز PIN محفوظ لأي طفل. سيتم تحويلك إلى تسجيل الدخول.',
            ),
          ),
        );
      context.go('/auth/login');
    }

    unawaited(_runSilentSignOutCleanup());
  }

  Future<void> _runSilentSignOutCleanup() async {
    try {
      await _localNotificationService.clearManagedNotifications();
    } catch (_) {
      // Non-blocking.
    }
    try {
      await _selectedChildService.clearSelectedChildId();
    } catch (_) {
      // Non-blocking.
    }
    try {
      await _authService.signOut();
    } catch (_) {
      // Non-blocking.
    } finally {
      _isForceReloginInProgress = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F1E2),
      body: SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
              ? _ErrorView(
                  message: _errorMessage!,
                  onRetry: _loadSettings,
                  onBack: _goBack,
                )
              : _SettingsContent(
                  viewModel: _viewModel!,
                  onBack: _goBack,
                  onRefresh: _loadSettings,
                  onEditSleepTap: () =>
                      _openPinGateFor(nextRoute: '/child-home/sleep-routine'),
                  onSwitchChildTap: () =>
                      _openPinGateFor(nextRoute: '/child-home/profiles'),
                ),
        ),
      ),
    );
  }
}

class _SettingsContent extends StatelessWidget {
  const _SettingsContent({
    required this.viewModel,
    required this.onBack,
    required this.onRefresh,
    required this.onEditSleepTap,
    required this.onSwitchChildTap,
  });

  final _ChildSettingsViewModel viewModel;
  final VoidCallback onBack;
  final Future<void> Function() onRefresh;
  final VoidCallback onEditSleepTap;
  final VoidCallback onSwitchChildTap;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SettingsHeader(onBack: onBack),
            const SizedBox(height: 16),
            _SleepConfigCard(
              viewModel: viewModel,
              onEditSleepTap: onEditSleepTap,
            ),
            const SizedBox(height: 12),
            _DailyPracticesCard(viewModel: viewModel),
            const SizedBox(height: 12),
            _WeeklyProgressCard(viewModel: viewModel),
            const SizedBox(height: 12),
            _SwitchChildCard(
              childName: viewModel.childName,
              onSwitchChildTap: onSwitchChildTap,
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      textDirection: TextDirection.ltr,
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(
            Icons.arrow_forward,
            color: Color(0xFF2E2A26),
            size: 22,
          ),
        ),
        const Expanded(
          child: Text(
            'الإعدادات',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF1F1C18),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 48),
      ],
    );
  }
}

class _SleepConfigCard extends StatelessWidget {
  const _SleepConfigCard({
    required this.viewModel,
    required this.onEditSleepTap,
  });

  final _ChildSettingsViewModel viewModel;
  final VoidCallback onEditSleepTap;

  @override
  Widget build(BuildContext context) {
    return _SettingsCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'إعداد وقت نوم الطفل',
            textAlign: TextAlign.right,
            style: TextStyle(
              color: Color(0xFFB7864E),
              fontSize: 17,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFE3DAC7),
              borderRadius: BorderRadius.circular(22),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              textDirection: TextDirection.ltr,
              children: [
                GestureDetector(
                  onTap: onEditSleepTap,
                  child: Container(
                    height: 24,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4BC8C),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'تعديل',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      textDirection: TextDirection.rtl,
                      spacing: 4,
                      children: [
                        const Text(
                          'وقت النوم',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFFB39A77),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: Text(
                            viewModel.sleepTimeLabel,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFFB39A77),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          viewModel.sleepPeriodLabel,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFB39A77),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Icon(
                  viewModel.sleepNotificationsEnabled
                      ? Icons.bed_rounded
                      : Icons.bedtime_off_rounded,
                  size: 18,
                  color: Colors.white,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyPracticesCard extends StatelessWidget {
  const _DailyPracticesCard({required this.viewModel});

  final _ChildSettingsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return _SettingsCard(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'ممارسات يومية',
            textAlign: TextAlign.right,
            style: TextStyle(
              color: Color(0xFFB7864E),
              fontSize: 17,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          if (viewModel.practices.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'لا توجد سلوكيات مفعلة حالياً.',
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: Color(0xFFBFA17F),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          else
            for (var i = 0; i < viewModel.practices.length; i++) ...[
              _PracticeRow(item: viewModel.practices[i]),
              if (i < viewModel.practices.length - 1) const SizedBox(height: 6),
            ],
        ],
      ),
    );
  }
}

class _PracticeRow extends StatelessWidget {
  const _PracticeRow({required this.item});

  final _PracticeItemData item;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 42),
      decoration: BoxDecoration(
        color: const Color(0xFFE3DAC7),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        textDirection: TextDirection.ltr,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: item.isEnabled ? Colors.white : Colors.transparent,
              border: Border.all(color: Colors.white, width: 1.4),
            ),
            child: item.isEnabled
                ? const Icon(
                    Icons.check_rounded,
                    size: 11,
                    color: Color(0xFFB7864E),
                  )
                : null,
          ),
          if (item.hasLink) ...[
            const SizedBox(width: 6),
            const Icon(Icons.link_rounded, size: 12, color: Colors.white),
          ],
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              textDirection: TextDirection.rtl,
              children: [
                Text(
                  item.title,
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFB7864E),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (item.subtitle != null && item.subtitle!.trim().isNotEmpty)
                  Text(
                    item.subtitle!,
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFBEA989),
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyProgressCard extends StatelessWidget {
  const _WeeklyProgressCard({required this.viewModel});

  final _ChildSettingsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return _SettingsCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        children: [
          Row(
            textDirection: TextDirection.ltr,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 76,
                height: 76,
                child: Image.asset(
                  'assets/risha/risha_happy.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.show_chart_rounded,
                          size: 16,
                          color: Color(0xFFB7864E),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'التقدم الأسبوعي',
                          textAlign: TextAlign.left,
                          style: TextStyle(
                            color: Color(0xFFB7864E),
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      viewModel.hasWeeklyProgressData
                          ? 'يعرض الإنجاز الحقيقي لآخر 7 أيام'
                          : 'سيبدأ التتبع بعد فتح جدول الطفل وإنجاز المهام',
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        color: Color(0xFFBEA989),
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 220,
            child: Row(
              textDirection: TextDirection.ltr,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final bar in viewModel.weeklyBars) _ProgressBar(bar: bar),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            textDirection: TextDirection.ltr,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: viewModel.weeklyBars
                .map(
                  (bar) => Expanded(
                    child: Text(
                      bar.label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFC4AF8E),
                        fontSize: 8,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.bar});

  final _BarData bar;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      height: 210,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: bar.neutral > 0
            ? Container(color: const Color(0xFFE3DAC7))
            : bar.green <= 0
            ? Container(color: const Color(0xFFFF1F1F))
            : bar.red <= 0
            ? Container(color: const Color(0xFF23F436))
            : Column(
                children: [
                  Expanded(
                    flex: (bar.red * 100).round(),
                    child: Container(color: const Color(0xFFFF1F1F)),
                  ),
                  Expanded(
                    flex: (bar.green * 100).round(),
                    child: Container(color: const Color(0xFF23F436)),
                  ),
                ],
              ),
      ),
    );
  }
}

class _SwitchChildCard extends StatelessWidget {
  const _SwitchChildCard({
    required this.childName,
    required this.onSwitchChildTap,
  });

  final String childName;
  final VoidCallback onSwitchChildTap;

  @override
  Widget build(BuildContext context) {
    return _SettingsCard(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: const Color(0xFFE3DAC7),
          borderRadius: BorderRadius.circular(23),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          textDirection: TextDirection.ltr,
          children: [
            GestureDetector(
              onTap: onSwitchChildTap,
              child: Container(
                height: 26,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4BC8C),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Center(
                  child: Text(
                    'تبديل',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Text(
                'تبديل حساب الطفل: $childName',
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: const TextStyle(
                  color: Color(0xFFB39A77),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.message,
    required this.onRetry,
    required this.onBack,
  });

  final String message;
  final Future<void> Function() onRetry;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFB48C6A), size: 40),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFB48C6A),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              alignment: WrapAlignment.center,
              children: [
                _ActionButton(
                  label: 'إعادة المحاولة',
                  onTap: () => unawaited(onRetry()),
                ),
                _ActionButton(label: 'رجوع', onTap: onBack, isSecondary: true),
              ],
            ),
          ],
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

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.child,
    this.padding = const EdgeInsets.all(12),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF3EFE6),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: padding,
      child: child,
    );
  }
}

class _ChildSettingsViewModel {
  const _ChildSettingsViewModel({
    required this.childId,
    required this.childName,
    required this.sleepTimeLabel,
    required this.sleepPeriodLabel,
    required this.sleepNotificationsEnabled,
    required this.practices,
    required this.hasWeeklyProgressData,
    required this.weeklyBars,
  });

  final String childId;
  final String childName;
  final String sleepTimeLabel;
  final String sleepPeriodLabel;
  final bool sleepNotificationsEnabled;
  final List<_PracticeItemData> practices;
  final bool hasWeeklyProgressData;
  final List<_BarData> weeklyBars;
}

class _PracticeItemData {
  const _PracticeItemData({
    required this.title,
    this.subtitle,
    this.hasLink = false,
    this.isEnabled = false,
  });

  final String title;
  final String? subtitle;
  final bool hasLink;
  final bool isEnabled;
}

class _BarData {
  const _BarData({
    required this.label,
    required this.green,
    required this.red,
    this.neutral = 0,
  });

  final String label;
  final double green;
  final double red;
  final double neutral;
}
