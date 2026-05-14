import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:risha_v01/shared/services/email_notification_service.dart';
import 'package:risha_v01/shared/utils/digit_normalizer.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({
    super.key,
    this.initialEmail,
    this.initialCode,
  });

  final String? initialEmail;
  final String? initialCode;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _emailNotificationService = EmailNotificationService();

  bool _isSubmitting = false;
  bool _resetCompleted = false;

  bool get _hasVerifiedContext =>
      _emailController.text.trim().isNotEmpty &&
      _codeController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    final initialEmail = widget.initialEmail?.trim();
    final initialCode = widget.initialCode?.trim();
    if (initialEmail != null && initialEmail.isNotEmpty) {
      _emailController.text = initialEmail;
    }
    if (initialCode != null && initialCode.isNotEmpty) {
      _codeController.text = initialCode;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submitReset() async {
    if (_isSubmitting) {
      return;
    }

    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final message = await _emailNotificationService.completePasswordReset(
        email: _emailController.text,
        code: DigitNormalizer.normalize(_codeController.text),
        newPassword: _passwordController.text,
      );

      if (!mounted) {
        return;
      }

      setState(() => _resetCompleted = true);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
      context.go('/auth/login');
    } on EmailNotificationFailure catch (e) {
      if (!mounted) {
        return;
      }
      _showMessage(e.message);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showMessage('تعذر إكمال إعادة التعيين حاليًا. حاول مرة أخرى.');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showMessage(String message) {
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

  String? _validateCode(String? value) {
    final code = DigitNormalizer.normalize(value?.trim() ?? '');
    if (code.isEmpty) {
      return 'أدخل رمز إعادة التعيين.';
    }
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      return 'رمز إعادة التعيين يجب أن يتكون من 6 أرقام.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final text = value ?? '';
    if (text.trim().isEmpty) {
      return 'الرجاء إدخال كلمة المرور الجديدة.';
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
      return 'الرجاء تأكيد كلمة المرور الجديدة.';
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
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: Row(
                            children: [
                              IconButton(
                                onPressed: _isSubmitting
                                    ? null
                                    : () {
                                        final router = GoRouter.of(context);
                                        if (router.canPop()) {
                                          context.pop();
                                        } else {
                                          context.go('/auth/login');
                                        }
                                      },
                                icon: const Icon(Icons.arrow_back),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'تحديث كلمة المرور',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(
                                        color: const Color(0xFFD6A23C),
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ),
                              const SizedBox(width: 48),
                            ],
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
                        Text(
                          _hasVerifiedContext
                              ? 'تم التحقق من رمز إعادة التعيين. أدخل الآن كلمة المرور الجديدة للبريد:\n${_emailController.text.trim()}'
                              : 'أدخل البريد الإلكتروني ورمز إعادة التعيين ثم حدّد كلمة المرور الجديدة.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: const Color(0xFFB48C6A),
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (!_hasVerifiedContext) ...[
                          _ResetField(
                            controller: _emailController,
                            hintText: 'أدخل البريد الإلكتروني',
                            validator: _validateEmail,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 16),
                          _ResetField(
                            controller: _codeController,
                            hintText: 'أدخل رمز إعادة التعيين من 6 أرقام',
                            validator: _validateCode,
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 16),
                        ],
                        _ResetField(
                          controller: _passwordController,
                          hintText: 'أدخل كلمة المرور الجديدة',
                          validator: _validatePassword,
                          obscureText: true,
                        ),
                        const SizedBox(height: 16),
                        _ResetField(
                          controller: _confirmPasswordController,
                          hintText: 'تأكيد كلمة المرور الجديدة',
                          validator: _validateConfirmPassword,
                          obscureText: true,
                        ),
                        const SizedBox(height: 18),
                        if (_resetCompleted)
                          Text(
                            'اكتملت إعادة التعيين. يمكنك تسجيل الدخول الآن.',
                            textAlign: TextAlign.right,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF1F8A3D),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        const SizedBox(height: 32),
                        _ResetPasswordButton(
                          isLoading: _isSubmitting,
                          onTap: _isSubmitting ? null : _submitReset,
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: _isSubmitting
                              ? null
                              : () {
                                  final email = _emailController.text.trim();
                                  final encodedEmail = Uri.encodeQueryComponent(
                                    email,
                                  );
                                  context.go(
                                    email.isEmpty
                                        ? '/auth/reset-password-code'
                                        : '/auth/reset-password-code?email=$encodedEmail',
                                  );
                                },
                          child: const Text(
                            'التحقق من الرمز أولًا',
                            style: TextStyle(
                              color: Color(0xFFD6A23C),
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
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

class _ResetField extends StatelessWidget {
  const _ResetField({
    required this.controller,
    required this.hintText,
    required this.validator,
    this.obscureText = false,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String hintText;
  final String? Function(String?) validator;
  final bool obscureText;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      obscureText: obscureText,
      keyboardType: keyboardType,
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
      ),
    );
  }
}

class _ResetPasswordButton extends StatelessWidget {
  const _ResetPasswordButton({required this.isLoading, required this.onTap});

  final bool isLoading;
  final VoidCallback? onTap;

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
                        'تحديث كلمة المرور',
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
