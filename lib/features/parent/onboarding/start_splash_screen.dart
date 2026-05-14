import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:risha_v01/shared/services/auth_service.dart';
import 'package:risha_v01/shared/services/email_notification_service.dart';
import 'package:risha_v01/shared/services/selected_child_service.dart';
import 'package:risha_v01/shared/services/session_progress_service.dart';

class StartSplashScreen extends StatefulWidget {
  const StartSplashScreen({super.key});

  @override
  State<StartSplashScreen> createState() => _StartSplashScreenState();
}

class _StartSplashScreenState extends State<StartSplashScreen> {
  static const Duration _minimumSplashDuration = Duration(milliseconds: 700);
  static const Duration _startupVerificationTimeout = Duration(seconds: 3);

  final _authService = AuthService();
  final _emailNotificationService = EmailNotificationService();
  final _selectedChildService = SelectedChildService();
  final _sessionProgressService = SessionProgressService();

  double _startupProgress = 0.0;
  String _startupStatus = 'جاري تحميل التطبيق...';

  @override
  void initState() {
    super.initState();
    unawaited(_resolveInitialRoute());
  }

  Future<void> _resolveInitialRoute() async {
    try {
      await Future<void>.delayed(_minimumSplashDuration);
      if (!mounted) {
        return;
      }
      setState(() {
        _startupProgress = 0.15;
        _startupStatus = 'التحقق من حالة الحساب...';
      });

      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        setState(() {
          _startupProgress = 1.0;
          _startupStatus = 'جاري فتح التطبيق...';
        });
        context.go('/onboarding/welcome');
        return;
      }

      setState(() {
        _startupProgress = 0.35;
        _startupStatus = 'مزامنة بيانات المستخدم...';
      });
      unawaited(_emailNotificationService.syncCurrentUserProfile());

      setState(() {
        _startupProgress = 0.55;
        _startupStatus = 'التحقق من البريد الإلكتروني...';
      });
      final isEmailVerified = await _emailNotificationService
          .isCurrentUserEmailVerified()
          .timeout(
            _startupVerificationTimeout,
            onTimeout: () => currentUser.emailVerified,
          );
      if (!mounted) {
        return;
      }
      if (!isEmailVerified) {
        setState(() {
          _startupProgress = 1.0;
          _startupStatus = 'جاري فتح صفحة التحقق...';
        });
        context.go('/auth/verify-email?origin=start');
        return;
      }

      setState(() {
        _startupProgress = 0.75;
        _startupStatus = 'جاري تحميل إعدادات الحساب...';
      });
      final hasCompletedSetup =
          await _sessionProgressService.hasCompletedChildSetup();
      final selectedChildId = await _selectedChildService.getSelectedChildId();
      final hasSelectedChild =
          selectedChildId != null && selectedChildId.trim().isNotEmpty;

      if (!mounted) {
        return;
      }
      setState(() {
        _startupProgress = 1.0;
        _startupStatus = 'جاري فتح التطبيق...';
      });
      context.go(
        hasCompletedSetup && hasSelectedChild
            ? '/child-home/daily-home'
            : '/child-home/profiles',
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _startupProgress = 1.0;
        _startupStatus = 'التهيئة فشلت، جاري المحاولة...';
      });
      var fallbackRoute = '/onboarding/welcome';
      final currentUser = _authService.currentUser;
      if (currentUser != null) {
        fallbackRoute = currentUser.emailVerified
            ? '/child-home/profiles'
            : '/auth/verify-email?origin=start';
      }
      if (!mounted) {
        return;
      }
      context.go(fallbackRoute);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFA4652B),
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Image.asset(
                'assets/risha/risha_start.png',
                width: 125,
                fit: BoxFit.contain,
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 100,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _startupStatus,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: LinearProgressIndicator(
                      value: _startupProgress,
                      minHeight: 8,
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFFFFCC5C),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 26,
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: _SplashFooter(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SplashFooter extends StatelessWidget {
  const _SplashFooter();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: RichText(
        text: const TextSpan(
          style: TextStyle(
            color: Colors.black,
            fontSize: 12,
            fontWeight: FontWeight.w400,
          ),
          children: [
            TextSpan(text: 'Designed with '),
            TextSpan(
              text: '❤',
              style: TextStyle(color: Color(0xFFD43B35)),
            ),
            TextSpan(text: ' at PSAU'),
          ],
        ),
      ),
    );
  }
}
