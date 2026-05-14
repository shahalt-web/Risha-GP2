import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class OnboardingExplainScreen extends StatelessWidget {
  const OnboardingExplainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFFDF3E6),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth >= 720
                ? 72.0
                : constraints.maxWidth >= 480
                ? 40.0
                : 28.0;
            final imageHeight = (constraints.maxHeight * 0.42)
                .clamp(240.0, 360.0)
                .toDouble();

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: 24,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/risha/risha_group.png',
                        height: imageHeight,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'في ريشة، يعتني طفلك بشخصية افتراضية من\n'
                        'خلال أنشطة يومية\n'
                        'ويحصل على عملات وتشجيع عند إتمامها\n'
                        'كل ذلك ضمن بيئة آمنة ومتوازنة رقمياً',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: const Color(0xFFB48C6A),
                          height: 1.7,
                        ),
                      ),
                      const SizedBox(height: 32),
                      _OnboardingActionButton(
                        onPressed: () => context.go('/onboarding/important'),
                      ),
                      const SizedBox(height: 24),
                    ],
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

class _OnboardingActionButton extends StatelessWidget {
  const _OnboardingActionButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 220,
        height: 52,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              colors: [Color(0xFF1F8A3D), Color(0xFF2F9B49)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1F8A3D).withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(28),
              onTap: onPressed,
              child: Center(
                child: Image.asset(
                  'assets/risha/risha.png',
                  width: 22,
                  height: 22,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
