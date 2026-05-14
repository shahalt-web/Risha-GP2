import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:risha_v01/shared/services/child_behavior_service.dart';
import 'package:risha_v01/shared/services/local_notification_service.dart';
import 'package:risha_v01/shared/services/selected_child_service.dart';
import 'package:risha_v01/shared/services/session_progress_service.dart';

class BehaviorSelectionScreen extends StatefulWidget {
  const BehaviorSelectionScreen({super.key});

  @override
  State<BehaviorSelectionScreen> createState() =>
      _BehaviorSelectionScreenState();
}

class _BehaviorSelectionScreenState extends State<BehaviorSelectionScreen> {
  final _sessionProgressService = SessionProgressService();
  final _selectedChildService = SelectedChildService();
  final _childBehaviorService = ChildBehaviorService();
  final _localNotificationService = LocalNotificationService.instance;

  final Set<String> _selectedBehaviorIds = <String>{'morning_athkar'};
  final List<_BehaviorItemData> _baseItems = <_BehaviorItemData>[];
  final List<_BehaviorItemData> _customItems = <_BehaviorItemData>[];

  String? _selectedChildId;
  bool _isLoading = true;
  bool _isSaving = false;
  Timer? _persistSelectionDebounce;

  List<_BehaviorItemData> get _items => <_BehaviorItemData>[
    ..._baseItems,
    ..._customItems,
  ];

  @override
  void initState() {
    super.initState();
    unawaited(_sessionProgressService.setChildSetupCompleted(false));
    unawaited(
      _sessionProgressService.saveChildSetupRoute('/child-home/behaviors'),
    );
    unawaited(_loadBehaviorConfig());
  }

  @override
  void dispose() {
    _persistSelectionDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadBehaviorConfig() async {
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

      final customItems = config.customBehaviors
          .map(
            (custom) => _BehaviorItemData(
              id: custom.id,
              title: custom.title,
              subtitle: _customBehaviorSubtitle(custom),
            ),
          )
          .toList();
      final baseItems = _buildBaseItems(config);

      setState(() {
        _selectedChildId = childId;
        _baseItems
          ..clear()
          ..addAll(baseItems);
        _customItems
          ..clear()
          ..addAll(customItems);
        _selectedBehaviorIds
          ..clear()
          ..addAll(config.selectedBehaviorIds);
        _isLoading = false;
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
      _showError('تعذر تحميل إعدادات السلوكيات حالياً.');
      _redirectToProfiles();
    }
  }

  List<_BehaviorItemData> _buildBaseItems(ChildBehaviorConfig config) {
    return <_BehaviorItemData>[
      const _BehaviorItemData(id: 'morning_athkar', title: 'أذكار الصباح'),
      _BehaviorItemData(
        id: 'drink_water',
        title: 'شرب الماء',
        subtitle: 'عدد الأكواب اليومية: ${config.waterCupsCount}',
        showSettingsIcon: true,
        isWaterBehavior: true,
      ),
      const _BehaviorItemData(
        id: 'brush_teeth',
        title: 'تنظيف الأسنان',
        subtitle: 'بعد الاستيقاظ، قبل النوم',
      ),
      _BehaviorItemData(
        id: 'sport_activity',
        title: 'نشاط رياضي',
        subtitle:
            'عدد الجلسات اليومية: ${config.sportSessionsCount}'
            '${config.sportLightActivityEnabled ? ' - الوضع الخفيف مفعل' : ''}',
        showSettingsIcon: true,
        isSportBehavior: true,
      ),
      const _BehaviorItemData(
        id: 'solve_puzzle',
        title: 'حل لغز',
        subtitle: 'لغز تسلسلي مرتين خلال اليوم',
      ),
      const _BehaviorItemData(
        id: 'read_story',
        title: 'قراءة قصة',
        subtitle: 'قبل النوم',
      ),
    ];
  }

  String _customBehaviorSubtitle(CustomBehaviorConfig custom) {
    if (custom.periods.isEmpty) {
      return 'عدد التكرارات: ${custom.repeatCount}';
    }
    return 'عدد التكرارات: ${custom.repeatCount} - ${custom.periods.join('، ')}';
  }

  void _toggleItem(String behaviorId) {
    if (_isLoading || _isSaving) {
      return;
    }

    if (_selectedBehaviorIds.contains(behaviorId) &&
        _selectedBehaviorIds.length == 1) {
      _showError('يجب اختيار سلوك واحد على الأقل.');
      return;
    }

    setState(() {
      if (_selectedBehaviorIds.contains(behaviorId)) {
        _selectedBehaviorIds.remove(behaviorId);
      } else {
        _selectedBehaviorIds.add(behaviorId);
      }
    });

    _schedulePersistSelection();
  }

  void _schedulePersistSelection() {
    _persistSelectionDebounce?.cancel();
    _persistSelectionDebounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_persistSelection());
    });
  }

  Future<void> _persistSelection() async {
    final childId = _selectedChildId;
    if (childId == null || childId.isEmpty) {
      return;
    }

    try {
      await _childBehaviorService.saveSelectedBehaviorIds(
        childId: childId,
        behaviorIds: _selectedBehaviorIds.toList(),
      );
      unawaited(_syncNotificationsIfSetupCompleted());
    } on ChildBehaviorFailure catch (e) {
      if (!mounted) {
        return;
      }
      _showError(e.message);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showError('تعذر حفظ السلوكيات حالياً.');
    }
  }

  Future<void> _navigateWithSave(String route) async {
    if (_isSaving || _isLoading) {
      return;
    }
    final childId = _selectedChildId;
    if (childId == null || childId.isEmpty) {
      _redirectToProfiles('يرجى اختيار الطفل أولاً.');
      return;
    }
    if (route == '/child-home/sleep-routine' && _selectedBehaviorIds.isEmpty) {
      _showError('يجب اختيار سلوك واحد على الأقل قبل المتابعة.');
      return;
    }

    _persistSelectionDebounce?.cancel();
    setState(() => _isSaving = true);
    try {
      await _childBehaviorService.saveSelectedBehaviorIds(
        childId: childId,
        behaviorIds: _selectedBehaviorIds.toList(),
      );
      if (!mounted) {
        return;
      }
      context.go(route);
      unawaited(
        Future<void>.delayed(const Duration(milliseconds: 250), () async {
          await _syncNotificationsIfSetupCompleted();
        }),
      );
    } on ChildBehaviorFailure catch (e) {
      if (!mounted) {
        return;
      }
      _showError(e.message);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showError('تعذر حفظ السلوكيات حالياً.');
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
    setState(() => _isLoading = false);
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
                ? 56.0
                : constraints.maxWidth >= 480
                ? 32.0
                : 8.0;

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'ابدأ باختيار السلوكيات المناسبة لطفلك',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: const Color(0xFFD6A23C),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'ثم عدّل إعداداتها بحسب الوقت والتكرار الذي\nيناسب طفلك',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: const Color(0xFFB48C6A),
                          fontWeight: FontWeight.w500,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '*جميع العادات قابلة للتعديل لاحقاً من الإعدادات',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFFBFA17F),
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (_isLoading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 70),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              for (var i = 0; i < _items.length; i++) ...[
                                _BehaviorCard(
                                  data: _items[i],
                                  selected: _selectedBehaviorIds.contains(
                                    _items[i].id,
                                  ),
                                  onTap: () => _toggleItem(_items[i].id),
                                  onSettingsTap: _items[i].isWaterBehavior
                                      ? () => _navigateWithSave(
                                          '/child-home/water-routine',
                                        )
                                      : _items[i].isSportBehavior
                                      ? () => _navigateWithSave(
                                          '/child-home/sport-routine',
                                        )
                                      : null,
                                ),
                                if (i < _items.length - 1)
                                  const SizedBox(height: 12),
                              ],
                              const SizedBox(height: 14),
                              _AddBehaviorButton(
                                onTap: () => _navigateWithSave(
                                  '/child-home/add-behavior',
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 34),
                      _ContinueButton(
                        isBusy: _isSaving || _isLoading,
                        onTap: () =>
                            _navigateWithSave('/child-home/sleep-routine'),
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

class _BehaviorCard extends StatelessWidget {
  const _BehaviorCard({
    required this.data,
    required this.selected,
    required this.onTap,
    this.onSettingsTap,
  });

  final _BehaviorItemData data;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onSettingsTap;

  @override
  Widget build(BuildContext context) {
    final showSettingsButton = data.showSettingsIcon;
    final cardTap = showSettingsButton && onSettingsTap != null
        ? onSettingsTap
        : onTap;

    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(minHeight: 84),
        decoration: BoxDecoration(
          color: const Color(0xFFE8DFC8),
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: cardTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        data.title,
                        textAlign: TextAlign.right,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFB7864E),
                          fontSize: 17,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (data.subtitle != null &&
                          data.subtitle!.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          data.subtitle!,
                          textAlign: TextAlign.right,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFBFA17F),
                            fontSize: 10,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            if (showSettingsButton) ...[
              const SizedBox(width: 10),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: onSettingsTap,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      Icons.settings,
                      color: onSettingsTap != null
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.55),
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(width: 10),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: _SelectionCircle(selected: selected),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectionCircle extends StatelessWidget {
  const _SelectionCircle({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.4),
      ),
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: selected ? 16 : 8,
          height: selected ? 16 : 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? Colors.white : Colors.transparent,
          ),
        ),
      ),
    );
  }
}

class _AddBehaviorButton extends StatelessWidget {
  const _AddBehaviorButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          height: 70,
          decoration: BoxDecoration(
            color: const Color(0xFFE8DFC8),
            borderRadius: BorderRadius.circular(18),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add, color: Colors.white, size: 28),
              SizedBox(width: 10),
              Text(
                'إضافة سلوك جديد',
                style: TextStyle(
                  color: Color(0xFFB7864E),
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
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
        width: 210,
        height: 56,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              colors: isBusy
                  ? const [Color(0xFF9DBDAC), Color(0xFFB7CFBF)]
                  : const [Color(0xFF1F8A3D), Color(0xFF4E9A72)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6A57A6).withValues(alpha: 0.2),
                blurRadius: 14,
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

class _BehaviorItemData {
  const _BehaviorItemData({
    required this.id,
    required this.title,
    this.subtitle,
    this.showSettingsIcon = false,
    this.isWaterBehavior = false,
    this.isSportBehavior = false,
  });

  final String id;
  final String title;
  final String? subtitle;
  final bool showSettingsIcon;
  final bool isWaterBehavior;
  final bool isSportBehavior;
}
