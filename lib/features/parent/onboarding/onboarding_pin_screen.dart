import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:risha_v01/shared/services/pin_service.dart';

class OnboardingPinScreen extends StatefulWidget {
  const OnboardingPinScreen({super.key});

  @override
  State<OnboardingPinScreen> createState() => _OnboardingPinScreenState();
}

class _OnboardingPinScreenState extends State<OnboardingPinScreen> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;
  final _pinService = PinService();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(4, (_) => TextEditingController());
    _focusNodes = List.generate(4, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  bool get _isPinComplete =>
      _controllers.every((controller) => controller.text.trim().isNotEmpty);
  String get _enteredPin => _controllers.map((c) => c.text.trim()).join();

  void _onPinChanged(int index, String value) {
    if (value.isNotEmpty && index < _focusNodes.length - 1) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }

    setState(() {});
  }

  Future<void> _submit() async {
    if (!_isPinComplete || _isSubmitting) {
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      await _pinService.savePin(_enteredPin);
      if (!mounted) {
        return;
      }
      context.go('/parent-setup');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
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
                constraints: const BoxConstraints(maxWidth: 520),
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: 14,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 28,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: IconButton(
                              onPressed: () {
                                final router = GoRouter.of(context);
                                if (router.canPop()) {
                                  context.pop();
                                } else {
                                  context.go('/onboarding/important');
                                }
                              },
                              icon: const Icon(Icons.arrow_back),
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                        Text(
                          'تعيين رمز PIN',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: const Color(0xFFD6A23C),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 22),
                        Text(
                          'للحفاظ على أمان الإعدادات\n'
                          'يرجى كتابة سنه ميلاد الشخص المعتمد لإدارة\n'
                          'الحساب ليكون رمز امان',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: const Color(0xFFB48C6A),
                            height: 1.45,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              4,
                              (index) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                child: _PinInputBox(
                                  controller: _controllers[index],
                                  focusNode: _focusNodes[index],
                                  onChanged: (value) =>
                                      _onPinChanged(index, value),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        _ContinueButton(
                          enabled: _isPinComplete && !_isSubmitting,
                          onTap: _submit,
                        ),
                        const SizedBox(height: 56),
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

class _PinInputBox extends StatelessWidget {
  const _PinInputBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 64,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        style: const TextStyle(
          fontSize: 24,
          color: Color(0xFFB48C6A),
          fontWeight: FontWeight.w600,
        ),
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(1),
        ],
        decoration: InputDecoration(
          contentPadding: EdgeInsets.zero,
          filled: true,
          fillColor: const Color(0xFFF7F1E2),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: Color(0xFF9ECBAF), width: 1.0),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: Color(0xFF4DA07D), width: 1.3),
          ),
        ),
        onChanged: onChanged,
      ),
    );
  }
}

class _ContinueButton extends StatelessWidget {
  const _ContinueButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final buttonGradient = enabled
        ? const [Color(0xFF1F8A3D), Color(0xFF5DA57F)]
        : const [Color(0xFF8FB19F), Color(0xFFAFCBBC)];

    return Center(
      child: SizedBox(
        width: 220,
        height: 52,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: LinearGradient(colors: buttonGradient),
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
              onTap: enabled ? onTap : null,
              child: const Center(
                child: Text(
                  'متابعة',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 34 / 2,
                    fontWeight: FontWeight.w600,
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
