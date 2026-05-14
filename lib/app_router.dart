import 'package:go_router/go_router.dart';

import 'package:risha_v01/navigation/child_routes.dart';
import 'package:risha_v01/navigation/parent_routes.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/start',
  routes: [
    GoRoute(
      path: '/',
      redirect: (context, state) => '/start',
    ),
    ...parentRoutes,
    ...childRoutes,
  ],
);
