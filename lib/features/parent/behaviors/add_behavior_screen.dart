import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:risha_v01/shared/services/child_behavior_service.dart';
import 'package:risha_v01/shared/services/local_notification_service.dart';
import 'package:risha_v01/shared/services/selected_child_service.dart';
import 'package:risha_v01/shared/services/session_progress_service.dart';

class AddBehaviorScreen extends StatefulWidget {
  const AddBehaviorScreen({super.key});

  @override
  State<AddBehaviorScreen> createState() => _AddBehaviorScreenState();
}

class _AddBehaviorScreenState extends State<AddBehaviorScreen> {
  int repeatCount = 1;
  final Set<String> selectedPeriods = {'عند الاستيقاظ'};
  final TextEditingController _behaviorNameController = TextEditingController();
  final _sessionProgressService = SessionProgressService();
  final _selectedChildService = SelectedChildService();
  final _childBehaviorService = ChildBehaviorService();
  final _localNotificationService = LocalNotificationService.instance;
  List<TimeOfDay> _reminderTimes = <TimeOfDay>[
    const TimeOfDay(hour: 8, minute: 0),
  ];

  String? _selectedChildId;
  bool _isLoadingChild = true;
  bool _isSaving = false;

  static const List<String> _periodOptions = <String>[
    'عند الاستيقاظ',
    'خلال اليوم',
    'قبل النوم',
  ];

  @override
  void initState() {
    super.initState();
    unawaited(
      _sessionProgressService.saveChildSetupRoute('/child-home/add-behavior'),
    );
    unawaited(_loadSelectedChild());
  }

  @override
  void dispose() {
    _behaviorNameController.dispose();
    super.dispose();
  }

  Future<void> _loadSelectedChild() async {
    try {
      final childId = await _selectedChildService.getSelectedChildId();
      if (!mounted) {
        return;
      }
      if (childId == null || childId.isEmpty) {
        _redirectToProfiles('يرجى اختيار الطفل أولاً.');
        return;
      }
      setState(() {
        _selectedChildId = childId;
        _isLoadingChild = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showError('تعذر تحميل بيانات الطفل حالياً.');
      _redirectToProfiles();
    }
  }

  void _backToBehaviorSelection() {
    final router = GoRouter.of(context);
    if (router.canPop()) {
      context.pop();
    } else {
      context.go('/child-home/behaviors');
    }
  }

  void _increaseRepeat() {
    if (_isSaving || _isLoadingChild) {
      return;
    }
    setState(() {
      if (repeatCount < 10) {
        repeatCount++;
        _syncReminderTimesWithRepeat();
      }
    });
  }

  void _decreaseRepeat() {
    if (_isSaving || _isLoadingChild) {
      return;
    }
    setState(() {
      if (repeatCount > 1) {
        repeatCount--;
        _syncReminderTimesWithRepeat();
      }
    });
  }

  void _togglePeriod(String period) {
    if (_isSaving || _isLoadingChild) {
      return;
    }
    if (selectedPeriods.contains(period) && selectedPeriods.length == 1) {
      _showError('اختر وقتاً واحداً على الأقل للسلوك.');
      return;
    }
    setState(() {
      if (selectedPeriods.contains(period)) {
        selectedPeriods.remove(period);
      } else {
        selectedPeriods.add(period);
      }
    });
  }

  TimeOfDay _defaultReminderTimeForIndex(int index) {
    final totalMinutes = ((8 * 60) + (index * 60)) % (24 * 60);
    return TimeOfDay(hour: totalMinutes ~/ 60, minute: totalMinutes % 60);
  }

  void _syncReminderTimesWithRepeat() {
    if (_reminderTimes.length == repeatCount) {
      return;
    }
    if (_reminderTimes.length < repeatCount) {
      for (var i = _reminderTimes.length; i < repeatCount; i++) {
        _reminderTimes.add(_defaultReminderTimeForIndex(i));
      }
      return;
    }
    _reminderTimes = _reminderTimes.take(repeatCount).toList();
  }

  Future<void> _pickReminderTime(int index) async {
    if (_isSaving || _isLoadingChild) {
      return;
    }
    if (index < 0 || index >= repeatCount) {
      return;
    }

    final initialTime = index < _reminderTimes.length
        ? _reminderTimes[index]
        : _defaultReminderTimeForIndex(index);

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
      _syncReminderTimesWithRepeat();
      _reminderTimes[index] = picked;
    });
  }

  int _toMinutes(TimeOfDay time) => (time.hour * 60) + time.minute;

  String _formatTime(TimeOfDay time) {
    final hour12 = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '${hour12.toString().padLeft(2, '0')} : $minute $period';
  }

  Future<void> _saveBehavior() async {
    if (_isSaving || _isLoadingChild) {
      return;
    }
    final childId = _selectedChildId;
    if (childId == null || childId.isEmpty) {
      _redirectToProfiles('يرجى اختيار الطفل أولاً.');
      return;
    }

    final title = _behaviorNameController.text.trim();
    if (title.isEmpty) {
      _showError('يرجى إدخال اسم السلوك.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      _syncReminderTimesWithRepeat();
      await _childBehaviorService.addCustomBehavior(
        childId: childId,
        title: title,
        repeatCount: repeatCount,
        periods: selectedPeriods.toList(),
        reminderTimesMinutes: _reminderTimes
            .take(repeatCount)
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
      _showError('تعذر إضافة السلوك حالياً.');
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
    setState(() => _isLoadingChild = false);
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
                : 10.0;

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: SingleChildScrollView(
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
                              onPressed: _backToBehaviorSelection,
                              icon: const Icon(Icons.arrow_back),
                            ),
                            Expanded(
                              child: Text(
                                'إضافة سلوك جديد',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  color: const Color(0xFFD6A23C),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 48),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Divider(
                        color: Color(0xFF8E8A7F),
                        thickness: 1,
                        height: 1,
                      ),
                      const SizedBox(height: 10),
                      if (_isLoadingChild)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 70),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else ...[
                        _BehaviorNameField(
                          controller: _behaviorNameController,
                          enabled: !_isSaving,
                        ),
                        const SizedBox(height: 10),
                        _PeriodsCard(
                          selectedPeriods: selectedPeriods,
                          periodOptions: _periodOptions,
                          onPeriodTap: _togglePeriod,
                          enabled: !_isSaving,
                        ),
                        const SizedBox(height: 18),
                        const Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'عدد التكرارات',
                            style: TextStyle(
                              color: Color(0xFFB48C6A),
                              fontSize: 22,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _RepeatCounterCard(
                          value: repeatCount,
                          onIncrease: _increaseRepeat,
                          onDecrease: _decreaseRepeat,
                        ),
                        const SizedBox(height: 12),
                        _RemindersCard(
                          repeatCount: repeatCount,
                          reminderTimes: _reminderTimes,
                          onReminderTap: _pickReminderTime,
                          formatTime: _formatTime,
                          enabled: !_isSaving,
                        ),
                        const SizedBox(height: 24),
                        _SaveButton(onTap: _saveBehavior, isBusy: _isSaving),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BehaviorNameField extends StatelessWidget {
  const _BehaviorNameField({required this.controller, required this.enabled});

  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      textAlign: TextAlign.right,
      style: const TextStyle(color: Color(0xFFB48C6A), fontSize: 20),
      decoration: InputDecoration(
        hintText: 'اسم السلوك',
        hintStyle: const TextStyle(
          color: Color(0xFFB48C6A),
          fontSize: 20,
          fontWeight: FontWeight.w500,
        ),
        filled: true,
        fillColor: const Color(0xFFE8DFC8),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Color(0xFFD6A23C), width: 1.2),
        ),
      ),
    );
  }
}

class _PeriodsCard extends StatelessWidget {
  const _PeriodsCard({
    required this.selectedPeriods,
    required this.periodOptions,
    required this.onPeriodTap,
    required this.enabled,
  });

  final Set<String> selectedPeriods;
  final List<String> periodOptions;
  final ValueChanged<String> onPeriodTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE8DFC8),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(color: Color(0xFFBFA17F), thickness: 1, height: 1),
          const SizedBox(height: 18),
          const Text(
            'في أي وقت يجب أن تحدث',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFFB48C6A),
              fontSize: 22,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              for (final option in periodOptions)
                _PeriodChip(
                  label: option,
                  selected: selectedPeriods.contains(option),
                  onTap: () => onPeriodTap(option),
                  enabled: enabled,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PeriodChip extends StatelessWidget {
  const _PeriodChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.enabled,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: selected ? const Color(0xFFD8D3C6) : const Color(0xFFECE4D2),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: enabled ? const Color(0xFFB48C6A) : const Color(0xFFBFA17F),
            fontSize: 17,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _RepeatCounterCard extends StatelessWidget {
  const _RepeatCounterCard({
    required this.value,
    required this.onIncrease,
    required this.onDecrease,
  });

  final int value;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: const Color(0xFFE8DFC8),
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _CounterAction(symbol: '+', onTap: onIncrease),
          Text(
            '$value',
            style: const TextStyle(
              color: Color(0xFFB48C6A),
              fontSize: 28,
              fontWeight: FontWeight.w500,
            ),
          ),
          _CounterAction(symbol: '-', onTap: onDecrease),
        ],
      ),
    );
  }
}

class _CounterAction extends StatelessWidget {
  const _CounterAction({required this.symbol, required this.onTap});

  final String symbol;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: Text(
            symbol,
            style: const TextStyle(
              color: Color(0xFFEDE9DE),
              fontSize: 30,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _RemindersCard extends StatelessWidget {
  const _RemindersCard({
    required this.repeatCount,
    required this.reminderTimes,
    required this.onReminderTap,
    required this.formatTime,
    required this.enabled,
  });

  final int repeatCount;
  final List<TimeOfDay> reminderTimes;
  final ValueChanged<int> onReminderTap;
  final String Function(TimeOfDay) formatTime;
  final bool enabled;

  TimeOfDay _timeForIndex(int index) {
    if (index < reminderTimes.length) {
      return reminderTimes[index];
    }
    final totalMinutes = ((8 * 60) + (index * 60)) % (24 * 60);
    return TimeOfDay(hour: totalMinutes ~/ 60, minute: totalMinutes % 60);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE8DFC8),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Align(
            alignment: Alignment.centerRight,
            child: Text(
              'التذكيرات',
              style: TextStyle(
                color: Color(0xFFB48C6A),
                fontSize: 23,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Divider(color: Color(0xFFBFA17F), thickness: 1, height: 1),
          const SizedBox(height: 12),
          for (var i = 0; i < repeatCount; i++) ...[
            Directionality(
              textDirection: TextDirection.ltr,
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: enabled ? () => onReminderTap(i) : null,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          formatTime(_timeForIndex(i)),
                          textAlign: TextAlign.left,
                          style: TextStyle(
                            color: enabled
                                ? const Color(0xFFD6A23C)
                                : const Color(0xFFBFA17F),
                            fontSize: 22,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Text(
                    'التكرار ${i + 1}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: Color(0xFFB48C6A),
                      fontSize: 19,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (i < repeatCount - 1) const SizedBox(height: 8),
          ],
        ],
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
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'حفظ التغييرات',
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
