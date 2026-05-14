import 'package:go_router/go_router.dart';

import 'package:risha_v01/features/child/home/child_brush_time_screen.dart';
import 'package:risha_v01/features/child/home/child_custom_behavior_screen.dart';
import 'package:risha_v01/features/child/home/child_daily_home_screen.dart';
import 'package:risha_v01/features/child/home/child_exercising_screen.dart';
import 'package:risha_v01/features/child/home/child_hero_reward_screen.dart';
import 'package:risha_v01/features/child/home/child_market_screen.dart';
import 'package:risha_v01/features/child/home/child_quran_reading_screen.dart';
import 'package:risha_v01/features/child/home/child_shape_matching_screen.dart';
import 'package:risha_v01/features/child/home/child_sleep_story_screen.dart';
import 'package:risha_v01/features/child/home/child_water_drink_screen.dart';
import 'package:risha_v01/features/child/onboarding/child_welcome_egg_screen.dart';
import 'package:risha_v01/features/child/onboarding/child_welcome_greeting_screen.dart';
import 'package:risha_v01/features/parent/behaviors/child_settings_screen.dart';

final List<GoRoute> childRoutes = [
  GoRoute(
    path: '/child-home/brush-time',
    builder: (context, state) =>
        ChildBrushTimeScreen(taskId: state.uri.queryParameters['task']),
  ),
  GoRoute(
    path: '/child-home/exercising',
    builder: (context, state) =>
        ChildExercisingScreen(taskId: state.uri.queryParameters['task']),
  ),
  GoRoute(
    path: '/child-home/hero-reward',
    builder: (context, state) =>
        ChildHeroRewardScreen(taskId: state.uri.queryParameters['task']),
  ),
  GoRoute(
    path: '/child-home/market',
    builder: (context, state) => const ChildMarketScreen(),
  ),
  GoRoute(
    path: '/child-home/quran-reading',
    builder: (context, state) => const ChildQuranReadingScreen(),
  ),
  GoRoute(
    path: '/child-home/shape-matching',
    builder: (context, state) => const ChildShapeMatchingScreen(),
  ),
  GoRoute(
    path: '/child-home/sleep-story',
    builder: (context, state) => const ChildSleepStoryScreen(),
  ),
  GoRoute(
    path: '/child-home/water-drink',
    builder: (context, state) =>
        ChildWaterDrinkScreen(taskId: state.uri.queryParameters['task']),
  ),
  GoRoute(
    path: '/child-home/custom-behavior',
    builder: (context, state) => ChildCustomBehaviorScreen(
      taskId: state.uri.queryParameters['task'],
      behaviorTitle: state.uri.queryParameters['title'],
    ),
  ),
  GoRoute(
    path: '/child-home/daily-home',
    builder: (context, state) => const ChildDailyHomeScreen(),
  ),
  GoRoute(
    path: '/child-home/settings',
    builder: (context, state) => const ChildSettingsScreen(),
  ),
  GoRoute(
    path: '/child-home/welcome-egg',
    builder: (context, state) => const ChildWelcomeEggScreen(),
  ),
  GoRoute(
    path: '/child-home/welcome-greeting',
    builder: (context, state) => const ChildWelcomeGreetingScreen(),
  ),
];
