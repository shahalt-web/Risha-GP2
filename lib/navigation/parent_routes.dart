import 'package:go_router/go_router.dart';

import 'package:risha_v01/features/parent/auth/email_verification_screen.dart';
import 'package:risha_v01/features/parent/auth/forgot_password_screen.dart';
import 'package:risha_v01/features/parent/auth/login_screen.dart';
import 'package:risha_v01/features/parent/auth/password_reset_verification_screen.dart';
import 'package:risha_v01/features/parent/auth/reset_password_screen.dart';
import 'package:risha_v01/features/parent/behaviors/add_behavior_screen.dart';
import 'package:risha_v01/features/parent/behaviors/behavior_selection_screen.dart';
import 'package:risha_v01/features/parent/behaviors/sleep_routine_screen.dart';
import 'package:risha_v01/features/parent/behaviors/sport_routine_screen.dart';
import 'package:risha_v01/features/parent/behaviors/water_routine_screen.dart';
import 'package:risha_v01/features/parent/child_profiles/add_child_screen.dart';
import 'package:risha_v01/features/parent/child_profiles/child_profile_selection_screen.dart';
import 'package:risha_v01/features/parent/child_profiles/edit_child_screen.dart';
import 'package:risha_v01/features/parent/onboarding/onboarding_explain_screen.dart';
import 'package:risha_v01/features/parent/onboarding/onboarding_important_screen.dart';
import 'package:risha_v01/features/parent/onboarding/onboarding_pin_screen.dart';
import 'package:risha_v01/features/parent/onboarding/onboarding_welcome_screen.dart';
import 'package:risha_v01/features/parent/onboarding/start_splash_screen.dart';
import 'package:risha_v01/features/parent/rewards/parent_pending_rewards_screen.dart';
import 'package:risha_v01/features/parent/setup/child_setup_pin_screen.dart';
import 'package:risha_v01/features/parent/setup/child_setup_preparing_screen.dart';
import 'package:risha_v01/features/parent/setup/child_setup_success_screen.dart';
import 'package:risha_v01/features/parent/setup/parent_setup_placeholder_screen.dart';
import 'package:risha_v01/shared/services/child_service.dart';

String _resolvePinRoute(String? route, {required String fallback}) {
  if (route == null || route.isEmpty || !route.startsWith('/')) {
    return fallback;
  }
  return route;
}

final List<GoRoute> parentRoutes = [
  GoRoute(
    path: '/start',
    builder: (context, state) => const StartSplashScreen(),
  ),
  GoRoute(
    path: '/onboarding/welcome',
    builder: (context, state) => const OnboardingWelcomeScreen(),
  ),
  GoRoute(
    path: '/onboarding/explain',
    builder: (context, state) => const OnboardingExplainScreen(),
  ),
  GoRoute(
    path: '/onboarding/important',
    builder: (context, state) => const OnboardingImportantScreen(),
  ),
  GoRoute(
    path: '/onboarding/pin',
    builder: (context, state) => const OnboardingPinScreen(),
  ),
  GoRoute(
    path: '/onboarding/preparing',
    redirect: (context, state) => '/parent-setup',
  ),
  GoRoute(
    path: '/parent-setup',
    builder: (context, state) => const ParentSetupScreen(),
  ),
  GoRoute(
    path: '/auth/login',
    builder: (context, state) => const LoginScreen(),
  ),
  GoRoute(
    path: '/auth/forgot-password',
    builder: (context, state) => const ForgotPasswordScreen(),
  ),
  GoRoute(
    path: '/auth/reset-password-code',
    builder: (context, state) => PasswordResetVerificationScreen(
      initialEmail: state.uri.queryParameters['email'],
    ),
  ),
  GoRoute(
    path: '/auth/reset-password',
    builder: (context, state) => ResetPasswordScreen(
      initialEmail: state.uri.queryParameters['email'],
      initialCode: state.uri.queryParameters['code'],
    ),
  ),
  GoRoute(
    path: '/auth/verify-email',
    builder: (context, state) => EmailVerificationScreen(
      origin: state.uri.queryParameters['origin'] ?? 'manual',
    ),
  ),
  GoRoute(
    path: '/child-home/behaviors',
    builder: (context, state) => const BehaviorSelectionScreen(),
  ),
  GoRoute(
    path: '/child-home/profiles',
    builder: (context, state) => const ChildProfileSelectionScreen(),
  ),
  GoRoute(
    path: '/child-home/add-child',
    builder: (context, state) => const AddChildScreen(),
  ),
  GoRoute(
    path: '/child-home/edit-child/:childId',
    builder: (context, state) {
      final childId = state.pathParameters['childId'] ?? '';
      final initialChild = state.extra is ChildProfile
          ? state.extra as ChildProfile
          : null;
      return EditChildScreen(childId: childId, initialChild: initialChild);
    },
  ),
  GoRoute(
    path: '/child-home/add-behavior',
    builder: (context, state) => const AddBehaviorScreen(),
  ),
  GoRoute(
    path: '/child-home/water-routine',
    builder: (context, state) => const WaterRoutineScreen(),
  ),
  GoRoute(
    path: '/child-home/sport-routine',
    builder: (context, state) => const SportRoutineScreen(),
  ),
  GoRoute(
    path: '/child-home/sleep-routine',
    builder: (context, state) => const SleepRoutineScreen(),
  ),
  GoRoute(
    path: '/child-home/pin',
    builder: (context, state) {
      final verifyOnly = state.uri.queryParameters['verify'] == '1';
      final trackSetupProgress = state.uri.queryParameters['track'] != '0';
      return ChildSetupPinScreen(
        onSuccessRoute: _resolvePinRoute(
          state.uri.queryParameters['next'],
          fallback: '/child-home/setup-preparing',
        ),
        onBackRoute: _resolvePinRoute(
          state.uri.queryParameters['back'],
          fallback: '/child-home/sleep-routine',
        ),
        verifyOnly: verifyOnly,
        trackSetupProgress: trackSetupProgress,
      );
    },
  ),
  GoRoute(
    path: '/child-home/setup-preparing',
    builder: (context, state) => const ChildSetupPreparingScreen(),
  ),
  GoRoute(
    path: '/child-home/setup-success',
    builder: (context, state) => const ChildSetupSuccessScreen(),
  ),
  GoRoute(
    path: '/parent-home/pending-rewards',
    builder: (context, state) => const ParentPendingRewardsScreen(),
  ),
];
