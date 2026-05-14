import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:risha_v01/shared/config/feature_flags.dart';
import 'package:risha_v01/shared/services/child_reward_service.dart';
import 'package:risha_v01/shared/services/child_task_progress_service.dart';

class ChildHeroRewardScreen extends StatefulWidget {
  const ChildHeroRewardScreen({super.key, this.taskId});

  final String? taskId;

  @override
  State<ChildHeroRewardScreen> createState() => _ChildHeroRewardScreenState();
}

class _ChildHeroRewardScreenState extends State<ChildHeroRewardScreen> {
  final _taskProgressService = ChildTaskProgressService();
  final _childRewardService = ChildRewardService();

  StreamSubscription<ChildWalletState>? _walletSubscription;
  int _awardedCoins = 0;
  bool _isSavingReward = true;
  String? _rewardErrorMessage;
  bool _requestSent = false;
  bool _alreadyCompletedToday = false;
  bool _isApproved = false;
  bool _isRejected = false;

  @override
  void initState() {
    super.initState();
    _awardedCoins = ChildRewardService.taskRewardCoins;
    unawaited(_completeTaskIfNeeded());
  }

  Future<void> _completeTaskIfNeeded() async {
    final taskId = widget.taskId?.trim();
    if (taskId == null || taskId.isEmpty) {
      if (mounted) {
        setState(() => _isSavingReward = false);
      }
      return;
    }

    try {
      final progress = await _taskProgressService
          .getSelectedChildTaskProgress();
      if (FeatureFlags.bypassDailyTaskCompletionRestrictionsTemporarily) {
        // Allow repeated reward flow during testing.
      } else if (progress.isCompleted(taskId)) {
        if (!mounted) {
          return;
        }
        setState(() {
          _alreadyCompletedToday = true;
          _isSavingReward = false;
        });
        return;
      }

      final taskTitle = _resolveTaskTitle(taskId);
      final childRewardService = ChildRewardService();
      _awardedCoins = ChildRewardService.taskRewardCoins;

      // addPendingReward internally queues and flushes the email reliably
      final pendingReward = await childRewardService.addPendingReward(
        rewardType: 'task_completion',
        description: taskTitle,
        coins: _awardedCoins,
        taskId: taskId,
        awaitEmail: true,
      );

      if (!mounted) {
        return;
      }
      setState(() {
        _requestSent = true;
        _isSavingReward = false;
        _rewardErrorMessage = null;
      });

      _startApprovalListener(pendingReward.id);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSavingReward = false;
        _rewardErrorMessage = 'تعذر حفظ النقاط الآن';
      });
    }
  }

  String _resolveTaskTitle(String taskId) {
    switch (taskId) {
      case 'quran-reading':
        return 'أذكار الصباح والقراءة';
      case 'brush-time-morning':
      case 'brush-time':
        return 'تنظيف الأسنان صباحًا';
      case 'brush-time-night':
        return 'تنظيف الأسنان مساءً';
      case 'exercising':
        return 'النشاط الرياضي';
      case 'shape-matching':
        return 'تمرين التفكير';
      case 'sleep-story':
        return 'قصة النوم';
      default:
        if (taskId.startsWith('water-drink-slot-')) {
          return 'شرب الماء';
        }
        if (taskId.startsWith('exercising-slot-')) {
          return 'النشاط الرياضي';
        }
        return 'إنجاز مهمة يومية';
    }
  }

  void _startApprovalListener(String rewardId) {
    _walletSubscription?.cancel();
    _walletSubscription = _childRewardService.watchSelectedChildWallet().listen(
      (wallet) {
        if (!mounted) return;
        final reward = wallet.pendingRewards.firstWhere(
          (r) => r.id == rewardId,
          orElse: () => PendingReward(
            id: '',
            rewardType: '',
            description: '',
            coins: 0,
            requestedAt: DateTime.now(),
            status: PendingRewardStatus.expired,
          ),
        );

        if (reward.id.isEmpty) return;

        if (reward.status == PendingRewardStatus.approved) {
          setState(() {
            _isApproved = true;
            _isRejected = false;
          });
          // Acknowledge automatically if visible on this screen
          unawaited(_childRewardService.acknowledgeRewardResult(rewardId));
        } else if (reward.status == PendingRewardStatus.rejected) {
          setState(() {
            _isApproved = false;
            _isRejected = true;
          });
          unawaited(_childRewardService.acknowledgeRewardResult(rewardId));
        }
      },
      onError: (_) {
        // Silent error, falling back to manual refresh on home
      },
    );
  }

  @override
  void dispose() {
    _walletSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final awardedCoins = _awardedCoins;
    final rewardMessage =
        _rewardErrorMessage ??
        (_alreadyCompletedToday
            ? 'أنهيت هذه المهمة اليوم بالفعل'
            : _requestSent
            ? 'تم إرسال طلب مكافأة $awardedCoins نقاط إلى والدك. في حال ضعف الاتصال سيُرسل الطلب تلقائيًا عند توفر الإنترنت.'
            : 'تم إرسال طلب مكافأة $awardedCoins نقاط إلى والدك للموافقة عبر البريد الإلكتروني');

    return Scaffold(
      backgroundColor: const Color(0xFFF4EEDC),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const SizedBox(height: 74),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    textDirection: TextDirection.ltr,
                    children: const [
                      Icon(
                        Icons.emoji_events_rounded,
                        color: Color(0xFFC79A26),
                        size: 26,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'واو! أنت بطل',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 38),
                  const _HeroMascot(),
                  const SizedBox(height: 48),
                  const Text(
                    'استمر بالقيام بكل النشاطات\nلتحصل على المزيد من المرح\nوالنقاط',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      height: 1.18,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    '✨',
                    style: TextStyle(color: Color(0xFFF2C43C), fontSize: 18),
                  ),
                  const SizedBox(height: 38),
                  if (_isSavingReward)
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Color(0xFFC79A26),
                      ),
                    )
                  else if (_isApproved)
                    Column(
                      children: [
                        const Text(
                          'تمت الموافقة! 🎉',
                          style: TextStyle(
                            color: Color(0xFF2D8B52),
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'لقد حصلت على $_awardedCoins نقطة بنجاح',
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    )
                  else if (_isRejected)
                    const Text(
                      'تم رفض الطلب هذه المرة 😔\nحاول مجددًا !',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFC74C4C),
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  else
                    Text.rich(
                      TextSpan(
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                        children: [
                          TextSpan(text: '$rewardMessage '),
                          if (_rewardErrorMessage == null &&
                              !_alreadyCompletedToday)
                            const TextSpan(
                              text: '⏳',
                              style: TextStyle(
                                color: Color(0xFFFFA500),
                                fontSize: 15,
                              ),
                            ),
                        ],
                      ),
                    ),
                  const Spacer(),
                  _BackButton(
                    onTap: () => context.go('/child-home/daily-home'),
                  ),
                  const SizedBox(height: 64),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroMascot extends StatelessWidget {
  const _HeroMascot();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/risha/risha_happy.png',
      width: 132,
      height: 132,
      fit: BoxFit.contain,
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 50,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Color(0xFF2D8B52), Color(0xFF78B28E)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8A76C8).withValues(alpha: 0.16),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: onTap,
            child: const Center(
              child: Text(
                'العودة',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
