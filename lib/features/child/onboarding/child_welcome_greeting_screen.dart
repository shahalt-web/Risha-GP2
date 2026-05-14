import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';

class ChildWelcomeGreetingScreen extends StatefulWidget {
  const ChildWelcomeGreetingScreen({super.key});

  @override
  State<ChildWelcomeGreetingScreen> createState() =>
      _ChildWelcomeGreetingScreenState();
}

class _ChildWelcomeGreetingScreenState extends State<ChildWelcomeGreetingScreen> {
  final AudioPlayer _welcomeSoundPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    unawaited(_playWelcomeSound());
  }

  Future<void> _playWelcomeSound() async {
    try {
      await _welcomeSoundPlayer.setAsset('assets/sounds/welcome.m4a');
      await _welcomeSoundPlayer.play();
    } catch (_) {
      // Keep onboarding flow working even if sound playback fails.
    }
  }

  @override
  void dispose() {
    _welcomeSoundPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const _SkyAndDesertBackground(),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      const SizedBox(height: 42),
                      Image.asset(
                        'assets/risha/risha_happy.png',
                        width: 210,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'مرحبًا',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFFD6A23C),
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'أنا صديقك الجديد ريشة',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFFD6A23C),
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 56),
                      const Text(
                        'جاهز نبدأ مغامرتنا معًا؟',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFFB48C6A),
                          fontSize: 17,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      _StartButton(
                        onTap: () => context.go('/child-home/daily-home'),
                      ),
                      const SizedBox(height: 26),
                    ],
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

class _StartButton extends StatelessWidget {
  const _StartButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 182,
      height: 58,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(29),
          gradient: const LinearGradient(
            colors: [Color(0xFF1F8A3D), Color(0xFF5DA57F)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6A57A6).withValues(alpha: 0.18),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(29),
            onTap: onTap,
            child: const Center(
              child: Text(
                'لنبدأ',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
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

class _SkyAndDesertBackground extends StatelessWidget {
  const _SkyAndDesertBackground();

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Image.asset(
        'assets/wallpapers/welcome_wallpaper.png',
        fit: BoxFit.cover,
      ),
    );
  }
}
