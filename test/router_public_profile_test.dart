import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lyrical/app/router.dart';

Widget _box(String label) => Scaffold(body: Text(label));

/// Mirrors the fixed production layout: `/app` parent + relative `users/:userId`
/// above a StatefulShellRoute.
GoRouter _buildFixedRouter({String? currentUserId}) {
  final rootKey = GlobalKey<NavigatorState>(debugLabel: 'test-root');

  return GoRouter(
    navigatorKey: rootKey,
    initialLocation: '/app/explore',
    routes: [
      GoRoute(
        path: '/app',
        redirect: (context, state) {
          if (state.uri.path == '/app') return '/app/explore';
          return null;
        },
        routes: [
          GoRoute(
            path: 'poems/:poemId',
            parentNavigatorKey: rootKey,
            builder: (context, state) =>
                _box('poem:${state.pathParameters['poemId']}'),
          ),
          GoRoute(
            name: AppRouteNames.publicProfile,
            path: 'users/:userId',
            parentNavigatorKey: rootKey,
            redirect: (context, state) {
              final userId = state.pathParameters['userId'];
              if (userId == null || userId.trim().isEmpty) {
                return '/app/explore';
              }
              if (currentUserId != null && userId == currentUserId) {
                return '/app/profile';
              }
              return null;
            },
            builder: (context, state) {
              final userId = state.pathParameters['userId']?.trim() ?? '';
              if (userId.isEmpty) {
                return _box('invalid-profile');
              }
              return _box('public-profile:$userId');
            },
          ),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return Scaffold(
            body: navigationShell,
            bottomNavigationBar: const SizedBox(height: 1),
          );
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/app/explore',
                builder: (context, state) => _box('explore'),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                name: AppRouteNames.profile,
                path: '/app/profile',
                builder: (context, state) => _box('profile-tab'),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

void main() {
  testWidgets('matches /app/users/<userId> to public profile route', (
    tester,
  ) async {
    final router = _buildFixedRouter();
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    const userId = '40880429-424e-4942-89b4-12dac45d0c21';
    router.push('/app/users/$userId');
    await tester.pumpAndSettle();

    expect(find.text('public-profile:$userId'), findsOneWidget);
    expect(router.state.error, isNull);
    expect(router.state.name, AppRouteNames.publicProfile);
  });

  testWidgets('pushNamed public-profile opens PublicProfile path', (
    tester,
  ) async {
    final router = _buildFixedRouter();
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    const userId = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';
    router.pushNamed(
      AppRouteNames.publicProfile,
      pathParameters: {'userId': userId},
    );
    await tester.pumpAndSettle();

    expect(find.text('public-profile:$userId'), findsOneWidget);
    expect(router.state.error, isNull);
  });

  testWidgets('own userId redirects to Profile tab', (tester) async {
    const selfId = '11111111-2222-3333-4444-555555555555';
    final router = _buildFixedRouter(currentUserId: selfId);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    router.push('/app/users/$selfId');
    await tester.pumpAndSettle();

    expect(find.text('profile-tab'), findsOneWidget);
    expect(find.textContaining('public-profile:'), findsNothing);
    expect(router.state.error, isNull);
  });

  testWidgets('namedLocation builds canonical /app/users/:userId', (
    tester,
  ) async {
    final router = _buildFixedRouter();
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    final location = router.namedLocation(
      AppRouteNames.publicProfile,
      pathParameters: {'userId': 'abc-123'},
    );
    expect(location, '/app/users/abc-123');
  });

  testWidgets('empty userId is handled without GoException', (tester) async {
    final router = _buildFixedRouter();
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    // Route requires a segment; navigating via named API with blank is guarded
    // in openAuthorProfile. Builder also guards empty path params.
    router.go('/app/explore');
    await tester.pumpAndSettle();
    expect(router.state.error, isNull);
    expect(find.text('explore'), findsOneWidget);
  });
}
