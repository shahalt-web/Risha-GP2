import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import 'package:risha_v01/shared/services/email_notification_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _emailNotificationService = EmailNotificationService();

  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submitResetCode() async {
    if (_isSubmitting) {
      return;
    }

    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final result = await _emailNotificationService.requestPasswordResetCode(
        email: _emailController.text,
      );
      if (!mounted) {
        return;
      }

      _showMessage(result.message);
      _goToCodeScreen();
    } on EmailNotificationFailure catch (e) {
      if (!mounted) {
        return;
      }
      _showMessage(e.message);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showMessage('تعذر إرسال رمز إعادة التعيين حاليًا. حاول مرة أخرى.');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _goToCodeScreen() {
    final email = _emailController.text.trim();
    final encodedEmail = Uri.encodeQueryComponent(email);
    context.go(
      email.isEmpty
          ? '/auth/reset-password-code'
          : '/auth/reset-password-code?email=$encodedEmail',
    );
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
            final spacerHeight = constraints.maxHeight >= 900 ? 300.0 : 180.0;

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
                                  'استعادة كلمة المرور',
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
                        const SizedBox(height: 54),
                        Text(
                          'أدخل بريدك الإلكتروني لإرسال رمز إعادة تعيين مكوّن من 6 أرقام',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: const Color(0xFFB48C6A),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 26),
                        _EmailField(
                          controller: _emailController,
                          validator: _validateEmail,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'بعد إدخال الرمز داخل التطبيق ستنتقل مباشرة إلى شاشة كلمة المرور الجديدة.',
                          textAlign: TextAlign.right,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: const Color(0xFFB48C6A),
                          ),
                        ),
                        SizedBox(height: spacerHeight),
                        _ResetCodeButton(
                          isLoading: _isSubmitting,
                          onTap: _isSubmitting ? null : _submitResetCode,
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _isSubmitting ? null : _goToCodeScreen,
                          child: const Text(
                            'لديك رمز بالفعل؟ أدخل الرمز',
                            style: TextStyle(
                              color: Color(0xFFD6A23C),
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
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

class _ResetCodeButton extends StatelessWidget {
  const _ResetCodeButton({required this.isLoading, required this.onTap});

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
            border: Border.all(color: const Color(0xFF0079FF), width: 2),
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
                        'إرسال الرمز',
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
