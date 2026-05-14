import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:risha_v01/shared/widgets/primary_button.dart';

class OnboardingLayout extends StatelessWidget {
  const OnboardingLayout({
    super.key,
    required this.imageAsset,
    required this.title,
    required this.description,
    required this.primaryLabel,
    required this.onPrimary,
    required this.step,
    required this.totalSteps,
    this.secondaryLabel,
    this.onSecondary,
    this.showProgress = true,
  });

  final String imageAsset;
  final String title;
  final String description;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final int step;
  final int totalSteps;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth >= 720
                ? 64.0
                : constraints.maxWidth >= 480
                    ? 32.0
                    : 24.0;
            final imageHeight =
                (constraints.maxHeight * 0.32).clamp(200.0, 300.0).toDouble();

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: 24,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: math.max(0, constraints.maxHeight - 48),
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (showProgress) ...[
                            OnboardingProgress(step: step, total: totalSteps),
                            const SizedBox(height: 24),
                          ],
                          Image.asset(
                            imageAsset,
                            height: imageHeight,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(height: 24),
                          Text(
                            title,
                            textAlign: TextAlign.right,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            description,
                            textAlign: TextAlign.right,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              height: 1.6,
                            ),
                          ),
                          const Spacer(),
                          PrimaryButton(
                            label: primaryLabel,
                            onPressed: onPrimary,
                          ),
                          if (secondaryLabel != null && onSecondary != null) ...[
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: onSecondary,
                              child: Text(secondaryLabel!),
                            ),
                          ],
                        ],
                      ),
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

class OnboardingProgress extends StatelessWidget {
  const OnboardingProgress({
    super.key,
    required this.step,
    required this.total,
  });

  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (index) {
        final isActive = index + 1 == step;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 8,
          width: isActive ? 28 : 8,
          decoration: BoxDecoration(
            color: isActive
                ? colorScheme.primary
                : colorScheme.primary.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }
}
