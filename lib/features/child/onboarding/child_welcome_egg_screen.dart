import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';

class ChildWelcomeEggScreen extends StatefulWidget {
  const ChildWelcomeEggScreen({super.key});

  @override
  State<ChildWelcomeEggScreen> createState() => _ChildWelcomeEggScreenState();
}

class _ChildWelcomeEggScreenState extends State<ChildWelcomeEggScreen> {
  final AudioPlayer _eggSoundPlayer = AudioPlayer();
  Timer? _soundStartTimer;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _soundStartTimer = Timer(const Duration(seconds: 1), () {
      unawaited(_playEggSoundThenGoNext());
    });
  }

  @override
  void dispose() {
    _soundStartTimer?.cancel();
    _eggSoundPlayer.dispose();
    super.dispose();
  }

  Future<void> _playEggSoundThenGoNext() async {
    if (!mounted || _hasNavigated) {
      return;
    }
    try {
      await _eggSoundPlayer.setAsset('assets/sounds/EggBreaks.m4a');
      await _eggSoundPlayer.play();
    } catch (_) {
      // Keep onboarding flow working even if sound playback fails.
    }
    _goNext();
  }

  void _goNext() {
    if (!mounted || _hasNavigated) {
      return;
    }
    _hasNavigated = true;
    _soundStartTimer?.cancel();
    unawaited(_eggSoundPlayer.stop());
    context.go('/child-home/welcome-greeting');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F1E2),
      body: SafeArea(
        child: GestureDetector(
          onTap: _goNext,
          behavior: HitTestBehavior.opaque,
          child: Center(
            child: Image.asset(
              'assets/risha/risha_egg.png',
              width: 200,
              height: 200,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}
