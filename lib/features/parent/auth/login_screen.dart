import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import 'package:risha_v01/shared/services/auth_service.dart';
import 'package:risha_v01/shared/services/email_notification_service.dart';
import 'package:risha_v01/shared/services/selected_child_service.dart';
import 'package:risha_v01/shared/services/session_progress_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _maxFailedAttempts = 5;
  static const _temporaryLockDuration = Duration(seconds: 30);

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  final _emailNotificationService = EmailNotificationService();
  final _selectedChildService = SelectedChildService();
  final _sessionProgressService = SessionProgressService();

  bool _isSubmitting = false;
  int _failedAttempts = 0;
  DateTime? _lockUntil;

  bool get _isLocked =>
      _lockUntil != null && DateTime.now().isBefore(_lockUntil!);

  int get _lockRemainingSeconds {
    if (_lockUntil == null) {
      return 0;
    }
    final remaining = _lockUntil!.difference(DateTime.now()).inSeconds;
    return remaining <= 0 ? 0 : remaining;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitLogin() async {
    if (_isSubmitting) {
      return;
    }

    if (_isLocked) {
      _showError(
        'تم إيقاف المحاولات مؤقتاً. حاول بعد $_lockRemainingSeconds ثانية.',
      );
      return;
    }

    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await _authService.signInWithEmail(
        email: _emailController.text,
        password: _passwordController.text,
      );

      _failedAttempts = 0;
      _lockUntil = null;
      await _sessionProgressService.clearChildSetupRoute();
      unawaited(_emailNotificationService.syncCurrentUserProfile());
      _emailNotificationService.flushDurableOutboxInBackground();
      final isEmailVerified =
          await _emailNotificationService.isCurrentUserEmailVerified();

      if (!mounted) {
        return;
      }

      if (!isEmailVerified) {
        context.go('/auth/verify-email?origin=login');
        return;
      }

      unawaited(_emailNotificationService.queueLoginEmail());

      final hasCompletedSetup =
          await _sessionProgressService.hasCompletedChildSetup();
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
    } on AuthFailure catch (e) {
      if (_isCredentialFailure(e.code)) {
        _registerFailedAttempt();
      }
      if (!mounted) {
        return;
      }
      _showError(e.message);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showError('حدث خطأ غير متوقع. حاول مرة أخرى.');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  bool _isCredentialFailure(String? code) {
    return code == 'invalid-credential' ||
        code == 'wrong-password' ||
        code == 'user-not-found';
  }

  void _registerFailedAttempt() {
    _failedAttempts += 1;
    if (_failedAttempts < _maxFailedAttempts) {
      return;
    }

    _failedAttempts = 0;
    _lockUntil = DateTime.now().add(_temporaryLockDuration);
    setState(() {});
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String? _validateEmail(String? value) {
    final text = value ?? '';
    if (text.trim().isEmpty) {
      return 'الرجاء إدخال البريد الإلكتروني.';
    }
    if (text.contains(RegExp(r'\s'))) {
      return 'البريد الإلكتروني لا يجب أن يحتوي على مسافات.';
    }

    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(text)) {
      return 'الرجاء إدخال بريد إلكتروني صحيح.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final text = value ?? '';
    if (text.trim().isEmpty) {
      return 'الرجاء إدخال كلمة المرور.';
    }
    return null;
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
            final spacerHeight = constraints.maxHeight >= 900 ? 220.0 : 120.0;

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
                          'مرحباً بعودتك',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: const Color(0xFFD6A23C),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'تسجيل الدخول',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: const Color(0xFFD6A23C),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Divider(
                          color: Color(0xFF8E8A7F),
                          height: 1,
                          thickness: 1,
                        ),
                        const SizedBox(height: 10),
                        const Divider(
                          color: Color(0xFFEFE7D8),
                          height: 1,
                          thickness: 1,
                        ),
                        const SizedBox(height: 40),
                        _LoginField(
                          controller: _emailController,
                          hintText: 'أدخل البريد الإلكتروني للشخص المسؤول',
                          icon: FontAwesomeIcons.envelope,
                          keyboardType: TextInputType.emailAddress,
                          validator: _validateEmail,
                        ),
                        const SizedBox(height: 16),
                        _LoginField(
                          controller: _passwordController,
                          hintText: 'أدخل كلمة المرور',
                          icon: FontAwesomeIcons.lock,
                          obscureText: true,
                          validator: _validatePassword,
                        ),
                        const SizedBox(height: 14),
                        Align(
                          alignment: Alignment.centerRight,
                          child: GestureDetector(
                            onTap: _isSubmitting
                                ? null
                                : () => context.go('/auth/forgot-password'),
                            child: Text(
                              'نسيت كلمة المرور؟',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: const Color(0xFFB48C6A),
                              ),
                            ),
                          ),
                        ),
                        if (_isLocked) ...[
                          const SizedBox(height: 8),
                          Text(
                            'تم قفل المحاولات مؤقتاً لمدة قصيرة لحماية الحساب.',
                            textAlign: TextAlign.right,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: const Color(0xFFB48C6A),
                            ),
                          ),
                        ],
                        SizedBox(height: spacerHeight),
                        _LoginButton(
                          isLoading: _isSubmitting,
                          onTap: (_isSubmitting || _isLocked)
                              ? null
                              : _submitLogin,
                        ),
                        const SizedBox(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'ليس لديك حساب؟ ',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: const Color(0xFFB48C6A),
                              ),
                            ),
                            GestureDetector(
                              onTap: _isSubmitting
                                  ? null
                                  : () => context.go('/parent-setup'),
                              child: Text(
                                'انضم إلينا اليوم',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: const Color(0xFFD6A23C),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
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

class _LoginField extends StatelessWidget {
  const _LoginField({
    required this.controller,
    required this.hintText,
    required this.icon,
    required this.validator,
    this.obscureText = false,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final String? Function(String?) validator;
  final bool obscureText;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      obscureText: obscureText,
      textAlign: TextAlign.right,
      style: const TextStyle(color: Color(0xFFB48C6A), fontSize: 18),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Color(0xFFC49B6B), fontSize: 16),
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
          borderSide: const BorderSide(color: Color(0xFFD6A23C), width: 1.2),
        ),
        prefixIcon: Container(
          width: 70,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            border: Border(
              left: BorderSide(color: Color(0xFFE8C864), width: 1.2),
            ),
          ),
          child: Icon(icon, color: const Color(0xFFD6A23C), size: 26),
        ),
        prefixIconConstraints: const BoxConstraints(
          minHeight: 56,
          minWidth: 70,
        ),
      ),
    );
  }
}

class _LoginButton extends StatelessWidget {
  const _LoginButton({required this.onTap, required this.isLoading});

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
                        'تسجيل الدخول',
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
