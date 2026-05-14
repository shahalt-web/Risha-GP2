import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:risha_v01/shared/services/child_behavior_service.dart';
import 'package:risha_v01/shared/services/local_notification_service.dart';
import 'package:risha_v01/shared/services/selected_child_service.dart';
import 'package:risha_v01/shared/services/session_progress_service.dart';

class WaterRoutineScreen extends StatefulWidget {
  const WaterRoutineScreen({super.key});

  @override
  State<WaterRoutineScreen> createState() => _WaterRoutineScreenState();
}

class _WaterRoutineScreenState extends State<WaterRoutineScreen> {
  int cupsCount = 2;
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
      _sessionProgressService.saveChildSetupRoute('/child-home/water-routine'),
    );
    unawaited(_loadWaterRoutine());
  }

  Future<void> _loadWaterRoutine() async {
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
        cupsCount = config.waterCupsCount;
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
      _showError('تعذر تحميل إعدادات شرب الماء حالياً.');
      _redirectToProfiles();
    }
  }

  void _increment() {
    if (_isLoadingConfig || _isSaving) {
      return;
    }
    setState(() {
      if (cupsCount < 12) {
        cupsCount++;
      }
    });
  }

  void _decrement() {
    if (_isLoadingConfig || _isSaving) {
      return;
    }
    setState(() {
      if (cupsCount > 1) {
        cupsCount--;
      }
    });
  }

  Future<void> _saveWaterRoutine() async {
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
      await _childBehaviorService.saveWaterRoutine(
        childId: childId,
        cupsCount: cupsCount,
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
      _showError('تعذر حفظ إعدادات شرب الماء حالياً.');
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
                              onPressed: () {
                                final router = GoRouter.of(context);
                                if (router.canPop()) {
                                  context.pop();
                                } else {
                                  context.go('/child-home/behaviors');
                                }
                              },
                              icon: const Icon(Icons.arrow_back),
                            ),
                            Expanded(
                              child: Text(
                                'تخصيص روتين شرب الماء',
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
                      const SizedBox(height: 22),
                      Text(
                        'حدد عدد الأكواب اليومية لطفلك',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: const Color(0xFFB48C6A),
                          fontSize: 34 / 2,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (_isLoadingConfig)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else ...[
                        _CounterCard(
                          value: cupsCount,
                          onIncrement: _increment,
                          onDecrement: _decrement,
                        ),
                        const SizedBox(height: 14),
                        const _AutoReminderCard(),
                      ],
                      const SizedBox(height: 22),
                      const _HintCard(),
                      const SizedBox(height: 20),
                      _SaveButton(
                        isBusy: _isSaving || _isLoadingConfig,
                        onTap: _saveWaterRoutine,
                      ),
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

class _CounterCard extends StatelessWidget {
  const _CounterCard({
    required this.value,
    required this.onIncrement,
    required this.onDecrement,
  });

  final int value;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 136,
      decoration: BoxDecoration(
        color: const Color(0xFFE8DFC8),
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _CounterAction(symbol: '+', onTap: onIncrement),
          Text(
            '$value',
            style: const TextStyle(
              color: Color(0xFFB48C6A),
              fontSize: 64 / 2,
              fontWeight: FontWeight.w500,
            ),
          ),
          _CounterAction(symbol: '−', onTap: onDecrement),
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
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: SizedBox(
        width: 54,
        height: 54,
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

class _AutoReminderCard extends StatelessWidget {
  const _AutoReminderCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE8DFC8),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      child: const Text(
        'سيتم تذكير الطفل تلقائياً بكوب ماء واحد كل ساعة إلى ساعتين تقريباً، مع توزيع عدد الأكواب بالتساوي خلال اليوم حتى يكتمل العدد.',
        textAlign: TextAlign.right,
        style: TextStyle(
          color: Color(0xFFB48C6A),
          fontSize: 15,
          fontWeight: FontWeight.w600,
          height: 1.5,
        ),
      ),
    );
  }
}

class _HintCard extends StatelessWidget {
  const _HintCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFD8D3C6),
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.lightbulb_outline,
            color: Color(0xFFBFA17F),
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'حسب الدراسات يمكنك الاستناد إلى:\n'
              'من عمر 4 إلى 8 سنوات: حوالي 5 أكواب يومياً\n'
              'من عمر 9 إلى 13 سنة: حوالي 6-8 أكواب يومياً\n'
              'إذا كان طفلك نشيطاً في اللعب أو الصيف يمكن رفعها قليلاً.',
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Color(0xFFB48C6A),
                fontSize: 18 / 2,
                height: 1.55,
              ),
            ),
          ),
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
                          fontSize: 36 / 2,
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
