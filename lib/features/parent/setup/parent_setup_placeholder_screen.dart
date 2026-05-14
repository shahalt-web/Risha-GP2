import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import 'package:risha_v01/shared/services/auth_service.dart';
import 'package:risha_v01/shared/services/email_notification_service.dart';
import 'package:risha_v01/shared/services/session_progress_service.dart';

class ParentSetupScreen extends StatefulWidget {
  const ParentSetupScreen({super.key});

  @override
  State<ParentSetupScreen> createState() => _ParentSetupScreenState();
}

class _ParentSetupScreenState extends State<ParentSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();
  final _emailNotificationService = EmailNotificationService();
  final _sessionProgressService = SessionProgressService();

  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submitCreateAccount() async {
    if (_isSubmitting) {
      return;
    }

    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await _authService.signUpWithEmail(
        email: _emailController.text,
        password: _passwordController.text,
      );
      await _sessionProgressService.clearChildSetupRoute();
      unawaited(_emailNotificationService.syncCurrentUserProfile());

      if (!mounted) {
        return;
      }
      context.go('/auth/verify-email?origin=signup');
    } on AuthFailure catch (e) {
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
    if (text.contains(RegExp(r'\s'))) {
      return 'كلمة المرور لا يجب أن تحتوي على مسافات.';
    }
    if (text.length < 6) {
      return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل.';
    }
    if (!RegExp(r'[A-Za-z\u0600-\u06FF]').hasMatch(text)) {
      return 'كلمة المرور يجب أن تحتوي على حرف واحد على الأقل.';
    }
    if (!RegExp(r'\d').hasMatch(text)) {
      return 'كلمة المرور يجب أن تحتوي على رقم واحد على الأقل.';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    final text = value ?? '';
    if (text.trim().isEmpty) {
      return 'الرجاء تأكيد كلمة المرور.';
    }
    if (text != _passwordController.text) {
      return 'كلمتا المرور غير متطابقتين.';
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
                          'أنشئ حساب  ليبدأ  طفلك رحلته في التعلم',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(
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
                        _SetupField(
                          controller: _emailController,
                          validator: _validateEmail,
                          hintText: 'أدخل البريد الإلكتروني للشخص المسؤول',
                          icon: FontAwesomeIcons.envelope,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 16),
                        _SetupField(
                          controller: _passwordController,
                          validator: _validatePassword,
                          hintText: 'أدخل كلمة المرور',
                          icon: FontAwesomeIcons.lock,
                          obscureText: true,
                        ),
                        const SizedBox(height: 16),
                        _SetupField(
                          controller: _confirmPasswordController,
                          validator: _validateConfirmPassword,
                          hintText: 'تأكيد كلمة المرور',
                          icon: FontAwesomeIcons.lock,
                          obscureText: true,
                        ),
                        const SizedBox(height: 34),
                        _CreateAccountButton(
                          onTap: _isSubmitting ? null : _submitCreateAccount,
                          isLoading: _isSubmitting,
                        ),
                        const SizedBox(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'لديك حساب بالفعل؟ ',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: const Color(0xFFB48C6A),
                              ),
                            ),
                            GestureDetector(
                              onTap: _isSubmitting
                                  ? null
                                  : () => context.go('/auth/login'),
                              child: Text(
                                'تسجيل الدخول',
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

class _SetupField extends StatelessWidget {
  const _SetupField({
    required this.controller,
    required this.validator,
    required this.hintText,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String? Function(String?) validator;
  final String hintText;
  final IconData icon;
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

class _CreateAccountButton extends StatelessWidget {
  const _CreateAccountButton({required this.onTap, required this.isLoading});

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
                        'إنشاء حساب',
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
