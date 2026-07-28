import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lyrical/app/splash_screen.dart';
import 'package:lyrical/core/widgets/main_shell.dart';
import 'package:lyrical/features/auth/presentation/login_screen.dart';
import 'package:lyrical/features/auth/presentation/register_screen.dart';
import 'package:lyrical/features/auth/presentation/verify_email_screen.dart';
import 'package:lyrical/features/auth/providers/auth_providers.dart';
import 'package:lyrical/features/explore/presentation/explore_screen.dart';
import 'package:lyrical/features/profile/presentation/profile_screen.dart';
import 'package:lyrical/features/publish/presentation/publish_screen.dart';
import 'package:lyrical/features/search/presentation/search_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);

final goRouterProvider = Provider<GoRouter>((ref) {
  final refresh = AuthRefreshListenable(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final authAsync = ref.read(authStateProvider);
      final location = state.matchedLocation;

      final isSplash = location == '/splash';
      final isLogin = location == '/login';
      final isRegister = location == '/register';
      final isVerifyEmail = location == '/verify-email';
      final isApp = location == '/app' || location.startsWith('/app/');

      return authAsync.when(
        loading: () => isSplash ? null : '/splash',
        error: (_, _) {
          if (isLogin || isRegister || isVerifyEmail) return null;
          return '/login';
        },
        data: (status) {
          switch (status) {
            case AppAuthStatus.loading:
              return isSplash ? null : '/splash';
            case AppAuthStatus.unauthenticated:
              if (isLogin || isRegister || isVerifyEmail) return null;
              if (isSplash) return '/login';
              if (isApp) return '/login';
              return '/login';
            case AppAuthStatus.authenticated:
              if (isSplash || isLogin || isRegister) {
                return '/app/explore';
              }
              if (location == '/app') return '/app/explore';
              return null;
          }
        },
      );
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/verify-email',
        builder: (context, state) {
          final email = state.uri.queryParameters['email'];
          return VerifyEmailScreen(email: email);
        },
      ),
      GoRoute(path: '/app', redirect: (context, state) => '/app/explore'),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/app/explore',
                builder: (context, state) => const ExploreScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/app/publish',
                builder: (context, state) => const PublishScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/app/search',
                builder: (context, state) => const SearchScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/app/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
