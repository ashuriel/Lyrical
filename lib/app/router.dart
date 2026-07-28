import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lyrical/app/router_refresh.dart';
import 'package:lyrical/app/splash_screen.dart';
import 'package:lyrical/core/widgets/main_shell.dart';
import 'package:lyrical/features/auth/presentation/login_screen.dart';
import 'package:lyrical/features/auth/presentation/register_screen.dart';
import 'package:lyrical/features/auth/presentation/verify_email_screen.dart';
import 'package:lyrical/features/auth/providers/auth_providers.dart';
import 'package:lyrical/features/explore/presentation/explore_screen.dart';
import 'package:lyrical/features/poems/presentation/my_poems_screen.dart';
import 'package:lyrical/features/poems/presentation/poem_detail_screen.dart';
import 'package:lyrical/features/profile/presentation/edit_profile_screen.dart';
import 'package:lyrical/features/profile/presentation/entry_screen.dart';
import 'package:lyrical/features/profile/presentation/profile_screen.dart';
import 'package:lyrical/features/profile/presentation/welcome_screen.dart';
import 'package:lyrical/features/profile/providers/profile_providers.dart';
import 'package:lyrical/features/publish/presentation/publish_screen.dart';
import 'package:lyrical/features/search/presentation/search_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);

final goRouterProvider = Provider<GoRouter>((ref) {
  final refresh = RouterRefreshListenable(ref);
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
      final isEntry = location == '/entry';
      final isWelcome = location == '/welcome';
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
              return '/login';
            case AppAuthStatus.authenticated:
              if (isSplash || isLogin || isRegister) {
                return '/entry';
              }
              if (isVerifyEmail) {
                return '/entry';
              }

              // Entry owns loading/error UI. Stay until profile resolves.
              if (isEntry) {
                final profileAsync = ref.read(currentProfileProvider);
                if (profileAsync.isLoading || profileAsync.hasError) {
                  return null;
                }
                final profile = profileAsync.asData?.value;
                if (profile == null) return null;
                return profile.hasCompletedOnboarding
                    ? '/app/explore'
                    : '/welcome';
              }

              final profileAsync = ref.read(currentProfileProvider);
              if (profileAsync.isLoading) {
                return '/entry';
              }
              if (profileAsync.hasError) {
                return '/entry';
              }

              final profile = profileAsync.asData?.value;
              if (profile == null) {
                return '/entry';
              }

              if (!profile.hasCompletedOnboarding) {
                if (isWelcome) return null;
                return '/welcome';
              }

              if (isWelcome) return '/app/explore';
              if (location == '/app') return '/app/explore';
              if (isApp) return null;
              return '/app/explore';
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
      GoRoute(path: '/entry', builder: (context, state) => const EntryScreen()),
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(path: '/app', redirect: (context, state) => '/app/explore'),
      GoRoute(
        path: '/app/poems/:poemId',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final poemId = state.pathParameters['poemId']!;
          return PoemDetailScreen(poemId: poemId);
        },
      ),
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
                routes: [
                  GoRoute(
                    path: 'edit',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => const EditProfileScreen(),
                  ),
                  GoRoute(
                    path: 'my-poems',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) {
                      final tab =
                          int.tryParse(
                            state.uri.queryParameters['tab'] ?? '',
                          ) ??
                          0;
                      return MyPoemsScreen(initialTabIndex: tab);
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
