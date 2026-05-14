import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:risha_v01/shared/services/child_reward_service.dart';

class ParentPendingRewardsScreen extends StatefulWidget {
  const ParentPendingRewardsScreen({super.key});

  @override
  State<ParentPendingRewardsScreen> createState() =>
      _ParentPendingRewardsScreenState();
}

class _ParentPendingRewardsScreenState
    extends State<ParentPendingRewardsScreen> {
  final _childRewardService = ChildRewardService();

  ChildWalletState? _walletState;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPendingRewards());
  }

  Future<void> _loadPendingRewards() async {
    try {
      final walletState = await _childRewardService.getSelectedChildWallet();
      if (mounted) {
        setState(() {
          _walletState = walletState;
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'تعذر تحميل المكافآت المعلقة';
        });
      }
    }
  }

  Future<void> _approveReward(String rewardId) async {
    try {
      await _childRewardService.approvePendingReward(rewardId);
      await _loadPendingRewards(); // Reload to show updated state
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر الموافقة على المكافأة')),
        );
      }
    }
  }

  Future<void> _rejectReward(String rewardId) async {
    try {
      await _childRewardService.rejectPendingReward(rewardId);
      await _loadPendingRewards(); // Reload to show updated state
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تعذر رفض المكافأة')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4EEDC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4EEDC),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.go('/parent-home'),
        ),
        title: const Text(
          'المكافآت المعلقة',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFC79A26)),
              )
            : _errorMessage != null
            ? Center(
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 16),
                ),
              )
            : _buildRewardsList(),
      ),
    );
  }

  Widget _buildRewardsList() {
    final pendingRewards =
        _walletState?.pendingRewards
            .where((reward) => reward.status == PendingRewardStatus.pending)
            .toList() ??
        [];

    if (pendingRewards.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: Color(0xFFC79A26),
            ),
            SizedBox(height: 16),
            Text(
              'لا توجد مكافآت معلقة',
              style: TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: pendingRewards.length,
      itemBuilder: (context, index) {
        final reward = pendingRewards[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.star, color: Color(0xFFF2C43C), size: 24),
                    const SizedBox(width: 8),
                    Text(
                      '${reward.coins} نقاط',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  reward.description,
                  style: const TextStyle(color: Colors.black87, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  'تاريخ الطلب: ${_formatDate(reward.requestedAt)}',
                  style: const TextStyle(color: Colors.black54, fontSize: 14),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _approveReward(reward.id),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2D8B52),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('موافقة'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _rejectReward(reward.id),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFC79A26)),
                          foregroundColor: const Color(0xFFC79A26),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('رفض'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
