import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import 'package:risha_v01/shared/services/email_notification_service.dart';
import 'package:risha_v01/shared/utils/digit_normalizer.dart';

class PasswordResetVerificationScreen extends StatefulWidget {
  const PasswordResetVerificationScreen({super.key, this.initialEmail});

  final String? initialEmail;

  @override
  State<PasswordResetVerificationScreen> createState() =>
      _PasswordResetVerificationScreenState();
}

class _PasswordResetVerificationScreenState
    extends State<PasswordResetVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _emailNotificationService = EmailNotificationService();

  bool _isSubmitting = false;
  bool _isRequestingCode = false;

  @override
  void initState() {
    super.initState();
    final initialEmail = widget.initialEmail?.trim();
    if (initialEmail != null && initialEmail.isNotEmpty) {
      _emailController.text = initialEmail;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
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
      final email = _normalizedEmail;
      final code = DigitNormalizer.normalize(_codeController.text.trim());
      final message = await _emailNotificationService.verifyPasswordResetCode(
        email: email,
        code: code,
      );
      if (!mounted) {
        return;
      }

      _showMessage(message);
      context.go(
        '/auth/reset-password?email=${Uri.encodeQueryComponent(email)}&code=${Uri.encodeQueryComponent(code)}',
      );
    } on EmailNotificationFailure catch (e) {
      if (!mounted) {
        return;
      }
      _showMessage(e.message);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showMessage('تعذر التحقق من الرمز حاليًا. حاول مرة أخرى.');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _requestNewCode() async {
    if (_isSubmitting || _isRequestingCode) {
      return;
    }

    final emailError = _validateEmail(_emailController.text);
    if (emailError != null) {
      _showMessage(emailError);
      return;
    }

    setState(() => _isRequestingCode = true);
    try {
      final result = await _emailNotificationService.requestPasswordResetCode(
        email: _normalizedEmail,
      );
      if (!mounted) {
        return;
      }
      _showMessage(result.message);
    } on EmailNotificationFailure catch (e) {
      if (!mounted) {
        return;
      }
      _showMessage(e.message);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showMessage('تعذر إرسال رمز جديد حاليًا. حاول مرة أخرى.');
    } finally {
      if (mounted) {
        setState(() => _isRequestingCode = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String get _normalizedEmail => _emailController.text.trim().toLowerCase();

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasEmail = _normalizedEmail.isNotEmpty;

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
                                onPressed: (_isSubmitting || _isRequestingCode)
                                    ? null
                                    : () {
                                        final router = GoRouter.of(context);
                                        if (router.canPop()) {
                                          context.pop();
                                        } else {
                                          context.go('/auth/forgot-password');
                                        }
                                      },
                                icon: const Icon(Icons.arrow_back),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'تحقق من رمز إعادة التعيين',
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
                        const SizedBox(height: 22),
                        Text(
                          hasEmail
                              ? 'أدخل الرمز المكوّن من 6 أرقام الذي أرسلناه إلى:\n$_normalizedEmail'
                              : 'أدخل البريد الإلكتروني ثم اكتب رمز إعادة التعيين المكوّن من 6 أرقام.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: const Color(0xFFB48C6A),
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _EmailField(
                          controller: _emailController,
                          validator: _validateEmail,
                        ),
                        const SizedBox(height: 16),
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
                              : _requestNewCode,
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
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: (_isSubmitting || _isRequestingCode)
                              ? null
                              : () => context.go('/auth/forgot-password'),
                          child: const Text(
                            'العودة إلى شاشة البريد',
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

class _EmailField extends StatelessWidget {
  const _EmailField({required this.controller, required this.validator});

  final TextEditingController controller;
  final String? Function(String?) validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: TextInputType.emailAddress,
      textAlign: TextAlign.right,
      style: const TextStyle(color: Color(0xFFB48C6A), fontSize: 18),
      decoration: InputDecoration(
        hintText: 'أدخل البريد الإلكتروني للشخص المسؤول',
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
          child: const Icon(
            FontAwesomeIcons.envelope,
            color: Color(0xFFD6A23C),
            size: 26,
          ),
        ),
        prefixIconConstraints: const BoxConstraints(
          minHeight: 56,
          minWidth: 70,
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
