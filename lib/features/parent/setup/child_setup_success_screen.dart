import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:risha_v01/shared/services/session_progress_service.dart';

class ChildSetupSuccessScreen extends StatefulWidget {
  const ChildSetupSuccessScreen({super.key});

  @override
  State<ChildSetupSuccessScreen> createState() =>
      _ChildSetupSuccessScreenState();
}

class _ChildSetupSuccessScreenState extends State<ChildSetupSuccessScreen> {
  final _sessionProgressService = SessionProgressService();

  @override
  void initState() {
    super.initState();
    unawaited(
      _sessionProgressService.saveChildSetupRoute('/child-home/setup-success'),
    );
  }

  Future<void> _finishSetup() async {
    await _sessionProgressService.setChildSetupCompleted(true);
    await _sessionProgressService.clearChildSetupRoute();
    if (!mounted) {
      return;
    }
    context.go('/child-home/welcome-egg');
  }

  void _goBack() {
    final router = GoRouter.of(context);
    if (router.canPop()) {
      context.pop();
    } else {
      context.go('/child-home/setup-preparing');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F1E2),
      body: SafeArea(
        child: Stack(
          children: [
            Directionality(
              textDirection: TextDirection.ltr,
              child: Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  onPressed: _goBack,
                  icon: const Icon(Icons.arrow_back, color: Color(0xFF2A2722)),
                ),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Image.asset(
                      'assets/risha/risha_success.png',
                      width: 250,
                      height: 250,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'تم الإعداد بنجاح',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: const Color(0xFFD6A23C),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'يمكنكم الآن تسليم الجهاز لطفلك ليقابل الشخصية الافتراضية',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: const Color(0xFFB48C6A),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 26),
                    Align(
                      alignment: Alignment.center,
                      child: _DoneButton(onTap: _finishSetup),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DoneButton extends StatelessWidget {
  const _DoneButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: const LinearGradient(
            colors: [Color(0xFF1F8A3D), Color(0xFF5DA57F)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6A57A6).withValues(alpha: 0.18),
              blurRadius: 12,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(26),
            onTap: onTap,
            child: const Center(
              child: Text(
                'تسليم الجهاز',
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
