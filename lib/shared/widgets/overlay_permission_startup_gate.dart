import 'dart:async';

import 'package:flutter/material.dart';

typedef OverlayPermissionCheck = Future<bool> Function();
typedef OverlayPermissionSettingsOpener = Future<void> Function();

class OverlayPermissionStartupGate extends StatefulWidget {
  const OverlayPermissionStartupGate({
    super.key,
    required this.child,
    required this.isPermissionGranted,
    required this.openPermissionSettings,
  });

  final Widget child;
  final OverlayPermissionCheck isPermissionGranted;
  final OverlayPermissionSettingsOpener openPermissionSettings;

  @override
  State<OverlayPermissionStartupGate> createState() =>
      _OverlayPermissionStartupGateState();
}

class _OverlayPermissionStartupGateState
    extends State<OverlayPermissionStartupGate>
    with WidgetsBindingObserver {
  bool _dialogVisible = false;
  bool _checkingPermission = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_refreshPermissionPrompt());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshPermissionPrompt());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _refreshPermissionPrompt() async {
    if (_checkingPermission || !mounted) {
      return;
    }

    _checkingPermission = true;
    try {
      final granted = await widget.isPermissionGranted();
      if (!mounted) {
        return;
      }

      if (granted) {
        if (_dialogVisible) {
          setState(() {
            _dialogVisible = false;
          });
        }
        return;
      }

      if (!_dialogVisible) {
        setState(() {
          _dialogVisible = true;
        });
      }
    } finally {
      _checkingPermission = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_dialogVisible) {
      return widget.child;
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Stack(
        children: [
          widget.child,
          Positioned.fill(
            child: Material(
              type: MaterialType.transparency,
              child: ColoredBox(
                color: Colors.black54,
                child: Center(
                  child: OverlayPermissionPromptDialog(
                    onAllowPressed: () {
                      unawaited(widget.openPermissionSettings());
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class OverlayPermissionPromptDialog extends StatelessWidget {
  const OverlayPermissionPromptDialog({
    super.key,
    required this.onAllowPressed,
  });

  final VoidCallback onAllowPressed;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        key: const Key('overlay_permission_prompt'),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        backgroundColor: Colors.transparent,
        child: Container(
          width: 340,
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF5E4),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/risha/risha_normal.png',
                key: const Key('overlay_permission_risha_image'),
                width: 170,
                height: 170,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 14),
              const Text(
                'يرجى السماح لتطبيق ريشه بالظهور فوق التطبيقات حتى تعمل ميزه التوازن الرقمي بشكل صحيح',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF3D3025),
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  height: 1.45,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  key: const Key('overlay_permission_allow_button'),
                  onPressed: onAllowPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D8B52),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'السماح الآن',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
