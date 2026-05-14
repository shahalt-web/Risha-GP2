import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:risha_v01/shared/services/auth_service.dart';
import 'package:risha_v01/shared/services/email_notification_service.dart';
import 'package:risha_v01/shared/services/local_notification_service.dart';
import 'package:risha_v01/shared/services/selected_child_service.dart';
import 'package:risha_v01/shared/services/session_progress_service.dart';
import 'package:risha_v01/shared/utils/digit_normalizer.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key, this.origin = 'manual'});

  final String origin;

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _authService = AuthService();
  final _emailNotificationService = EmailNotificationService();
  final _selectedChildService = SelectedChildService();
  final _localNotificationService = LocalNotificationService.instance;
  final _sessionProgressService = SessionProgressService();

  bool _isSubmitting = false;
  bool _isRequestingCode = false;
  bool _isCheckingVerification = true;

  String get _currentEmail =>
      _authService.currentUser?.email?.trim().isNotEmpty == true
      ? _authService.currentUser!.email!.trim()
      : 'البريد المسجل في الحساب';

  @override
  void initState() {
    super.initState();
    unawaited(_initializeScreen());
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _initializeScreen() async {
    final isVerified = await _emailNotificationService
        .isCurrentUserEmailVerified();
    if (!mounted) {
      return;
    }
    if (isVerified) {
      await _goToNextStep();
      return;
    }

    setState(() {
      _isCheckingVerification = false;
    });

    // Pre-warm the user snapshot cache so that the verification code request
    // doesn't have to wait for both Firestore read AND HTTP round-trip.
    try {
      await _emailNotificationService.syncCurrentUserProfile();
    } catch (_) {
      // Best-effort; the request will still build a snapshot if needed.
    }

    await _requestVerificationCode(initialLoad: true);
  }

  Future<void> _requestVerificationCode({bool initialLoad = false}) async {
    if (_isRequestingCode || _isSubmitting) {
      return;
    }

    setState(() => _isRequestingCode = true);
    try {
      final result = await _emailNotificationService.requestVerificationCode(
        reason: widget.origin,
      );
      if (!mounted) {
        return;
      }

      if (result.sent || !initialLoad) {
        _showInfo(result.message);
      }
    } on EmailNotificationFailure catch (e) {
      if (!mounted) {
        return;
      }
      if (initialLoad) {
        _showInfo('تعذر إرسال رمز التحقق تلقائيًا. اضغط "إرسال رمز جديد" للمحاولة.');
      } else {
        _showInfo(e.message);
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      if (initialLoad) {
        _showInfo('تعذر إرسال رمز التحقق تلقائيًا. اضغط "إرسال رمز جديد" للمحاولة.');
      } else {
        _showInfo('تعذر إرسال رمز جديد حاليًا. حاول مرة أخرى.');
      }
    } finally {
      if (mounted) {
        setState(() => _isRequestingCode = false);
      }
    }
  }

  Future<void> _submitVerification() async {
    if (_isSubmitting || _isRequestingCode) {
      return;
    }

    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await _emailNotificationService.verifyEmailCode(
        code: DigitNormalizer.normalize(_codeController.text),
      );
      if (!mounted) {
        return;
      }
      await _goToNextStep();
    } on EmailNotificationFailure catch (e) {
      if (!mounted) {
        return;
      }
      _showInfo(e.message);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showInfo('تعذر إكمال التحقق حاليًا. حاول مرة أخرى.');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _goToNextStep() async {
    final hasCompletedSetup = await _sessionProgressService
        .hasCompletedChildSetup();
    final selectedChildId = await _selectedChildService.getSelectedChildId();
    final hasSelectedChild =
        selectedChildId != null && selectedChildId.trim().isNotEmpty;

    if (!mounted) {
      return;
    }

    context.go(
      hasCompletedSetup && hasSelectedChild
          ? '/child-home/daily-home'
          : '/child-home/profiles',
    );
  }

  Future<void> _signOut() async {
    if (_isSubmitting || _isRequestingCode) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await _localNotificationService.clearManagedNotifications();
      await _selectedChildService.clearSelectedChildId();
      await _authService.signOut();
      if (!mounted) {
        return;
      }
      context.go('/auth/login');
    } on AuthFailure catch (e) {
      if (!mounted) {
        return;
      }
      _showInfo(e.message);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showInfo('تعذر تسجيل الخروج حاليًا. حاول مرة أخرى.');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  String? _validateCode(String? value) {
    final code = DigitNormalizer.normalize(value?.trim() ?? '');
    if (code.isEmpty) {
      return 'أدخل رمز التحقق.';
    }
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      return 'رمز التحقق يجب أن يتكون من 6 أرقام.';
    }
    return null;
  }

  void _showInfo(String message) {
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
                : 24.0;

            if (_isCheckingVerification) {
              return Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 20),
                      Text('جاري التحقق من حالة الحساب...'),
                    ],
                  ),
                ),
              );
            }

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: 24,
                  ),
                  child: Form(
                    key: _formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'تحقق من بريدك الإلكتروني',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: const Color(0xFFD6A23C),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'أرسلنا رمزًا مكونًا من 6 أرقام إلى:\n$_currentEmail',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: const Color(0xFFB48C6A),
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Divider(
                          color: Color(0xFF8E8A7F),
                          height: 1,
                          thickness: 1,
                        ),
                        const SizedBox(height: 32),
                        TextFormField(
                          controller: _codeController,
                          validator: _validateCode,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          maxLength: 6,
                          style: const TextStyle(
                            color: Color(0xFFB48C6A),
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 10,
                          ),
                          decoration: InputDecoration(
                            hintText: '000000',
                            counterText: '',
                            hintStyle: const TextStyle(
                              color: Color(0xFFC49B6B),
                              fontSize: 24,
                              letterSpacing: 10,
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF5F5F5),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 18,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(22),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(22),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(22),
                              borderSide: const BorderSide(
                                color: Color(0xFFD6A23C),
                                width: 1.2,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        _VerificationButton(
                          isLoading: _isSubmitting,
                          onTap: (_isSubmitting || _isRequestingCode)
                              ? null
                              : _submitVerification,
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: (_isSubmitting || _isRequestingCode)
                              ? null
                              : () => _requestVerificationCode(),
                          child: _isRequestingCode
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                  ),
                                )
                              : const Text(
                                  'إرسال رمز جديد',
                                  style: TextStyle(
                                    color: Color(0xFFD6A23C),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'لن نسمح بمتابعة استخدام الحساب قبل التحقق من البريد.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFFB48C6A),
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextButton(
                          onPressed: _signOut,
                          child: const Text(
                            'تسجيل الخروج',
                            style: TextStyle(
                              color: Color(0xFF8E8A7F),
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
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

class _VerificationButton extends StatelessWidget {
  const _VerificationButton({required this.onTap, required this.isLoading});

  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 255,
        height: 64,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            gradient: const LinearGradient(
              colors: [Color(0xFF1F8A3D), Color(0xFF77C19B)],
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
              borderRadius: BorderRadius.circular(32),
              onTap: onTap,
              child: Center(
                child: isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'تأكيد الرمز',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
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
