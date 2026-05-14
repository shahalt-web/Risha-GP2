import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:risha_v01/shared/services/auth_service.dart';
import 'package:risha_v01/shared/services/local_notification_service.dart';
import 'package:risha_v01/shared/services/pin_service.dart';
import 'package:risha_v01/shared/services/selected_child_service.dart';
import 'package:risha_v01/shared/services/session_progress_service.dart';

class ChildSetupPinScreen extends StatefulWidget {
  const ChildSetupPinScreen({
    super.key,
    this.onSuccessRoute = '/child-home/setup-preparing',
    this.onBackRoute = '/child-home/sleep-routine',
    this.verifyOnly = false,
    this.trackSetupProgress = true,
  });

  final String onSuccessRoute;
  final String onBackRoute;
  final bool verifyOnly;
  final bool trackSetupProgress;

  @override
  State<ChildSetupPinScreen> createState() => _ChildSetupPinScreenState();
}

class _ChildSetupPinScreenState extends State<ChildSetupPinScreen> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;
  final _sessionProgressService = SessionProgressService();
  final _pinService = PinService();
  final _authService = AuthService();
  final _selectedChildService = SelectedChildService();
  final _localNotificationService = LocalNotificationService.instance;

  bool _isSubmitting = false;
  bool _isInitializing = true;
  bool _verifyMode = false;
  bool _isForceReloginInProgress = false;
  String? _selectedChildId;

  bool get _isPinComplete =>
      _controllers.every((controller) => controller.text.trim().isNotEmpty);

  String get _enteredPin => _controllers.map((c) => c.text.trim()).join();

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(4, (_) => TextEditingController());
    _focusNodes = List.generate(4, (_) => FocusNode());
    if (widget.trackSetupProgress) {
      unawaited(_sessionProgressService.saveChildSetupRoute('/child-home/pin'));
    }
    unawaited(_initPinMode());
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

  Future<void> _initPinMode() async {
    final selectedChildId = (await _selectedChildService.getSelectedChildId())
        ?.trim();
    final hasSavedPin = await _pinService.hasSavedPin(
      childId: selectedChildId,
      allowParentFallback: widget.verifyOnly,
    );
    if (!mounted) {
      return;
    }

    if (widget.verifyOnly && !hasSavedPin) {
      await _forceReloginForMissingPin();
      return;
    }

    setState(() {
      _selectedChildId = selectedChildId;
      _verifyMode = widget.verifyOnly || hasSavedPin;
      _isInitializing = false;
    });
  }

  void _onPinChanged(int index, String value) {
    if (value.isNotEmpty && index < _focusNodes.length - 1) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    setState(() {});
  }

  Future<void> _submit() async {
    if (_isSubmitting || !_isPinComplete || _isInitializing) {
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      if (_verifyMode) {
        final isValid = await _pinService.verifyPin(
          _enteredPin,
          childId: _selectedChildId,
          allowParentFallback: widget.verifyOnly,
        );
        if (!isValid) {
          if (!mounted) {
            return;
          }
          _showError('رمز PIN غير صحيح.');
          await Future<void>.delayed(const Duration(milliseconds: 250));
          if (!mounted) {
            return;
          }
          context.go(widget.onBackRoute);
          return;
        }
      } else {
        await _pinService.savePin(_enteredPin, childId: _selectedChildId);
      }

      if (!mounted) {
        return;
      }
      context.go(widget.onSuccessRoute);
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

  void _goBack() {
    final router = GoRouter.of(context);
    if (router.canPop()) {
      context.pop();
    } else {
      context.go(widget.onBackRoute);
    }
  }

  Future<void> _forceReloginForMissingPin() async {
    if (_isForceReloginInProgress) {
      return;
    }
    _isForceReloginInProgress = true;

    if (mounted) {
      _showError(
        'لا يوجد رمز PIN محفوظ لأي طفل. سيتم تحويلك إلى تسجيل الدخول.',
      );
      context.go('/auth/login');
    }

    unawaited(_runSilentSignOutCleanup());
  }

  Future<void> _runSilentSignOutCleanup() async {
    try {
      await _localNotificationService.clearManagedNotifications();
    } catch (_) {
      // Non-blocking.
    }
    try {
      await _selectedChildService.clearSelectedChildId();
    } catch (_) {
      // Non-blocking.
    }
    try {
      await _authService.signOut();
    } catch (_) {
      // Non-blocking.
    } finally {
      _isForceReloginInProgress = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _verifyMode ? 'ادخل سنة ميلادك' : 'تعيين رمز PIN';
    final subtitle = _verifyMode
        ? 'لحماية الإعدادات، أدخل رمز PIN المكون من 4 أرقام للمتابعة'
        : 'يرجى كتابة سنة ميلاد الشخص المعتمد لإدارة\nالحساب ليكون رمز أمان';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F1E2),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 20),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 26,
                ),
                child: Column(
                  children: [
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: _goBack,
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Color(0xFF2A2722),
                            ),
                          ),
                          const Spacer(),
                          const SizedBox(width: 48),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Image.asset(
                      'assets/risha/risha_key.png',
                      width: 170,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFD6A23C),
                        fontSize: 21,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFB48C6A),
                        fontSize: 17,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (_isInitializing)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 18),
                        child: CircularProgressIndicator(),
                      )
                    else
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
                    const SizedBox(height: 28),
                    _ContinueButton(
                      enabled:
                          _isPinComplete && !_isSubmitting && !_isInitializing,
                      onTap: _submit,
                      isBusy: _isSubmitting,
                    ),
                    const SizedBox(height: 10),
                  ],
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
      width: 44,
      height: 52,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        style: const TextStyle(
          fontSize: 22,
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
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: Color(0xFF9ECBAF), width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: Color(0xFF4DA07D), width: 1.2),
          ),
        ),
        onChanged: onChanged,
      ),
    );
  }
}

class _ContinueButton extends StatelessWidget {
  const _ContinueButton({
    required this.enabled,
    required this.onTap,
    required this.isBusy,
  });

  final bool enabled;
  final VoidCallback onTap;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 168,
      height: 46,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(23),
          gradient: LinearGradient(
            colors: enabled
                ? const [Color(0xFF1F8A3D), Color(0xFF5DA57F)]
                : const [Color(0xFF9DBDAC), Color(0xFFB7CFBF)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6A57A6).withValues(alpha: 0.18),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(23),
            onTap: enabled ? onTap : null,
            child: Center(
              child: isBusy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'متابعة',
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
