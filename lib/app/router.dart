import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lyrical/app/splash_screen.dart';
import 'package:lyrical/core/widgets/main_shell.dart';
import 'package:lyrical/features/explore/presentation/explore_screen.dart';
import 'package:lyrical/features/profile/presentation/profile_screen.dart';
import 'package:lyrical/features/publish/presentation/publish_screen.dart';
import 'package:lyrical/features/search/presentation/search_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);

/// Application router. Auth redirects will be added in a later phase.
final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/splash',
  routes: [
    GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return MainShell(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/explore',
              builder: (context, state) => const ExploreScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/publish',
              builder: (context, state) => const PublishScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/search',
              builder: (context, state) => const SearchScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);
