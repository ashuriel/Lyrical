import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lyrical/app/app.dart';
import 'package:lyrical/core/constants/app_strings.dart';
import 'package:lyrical/core/errors/app_exception.dart';
import 'package:lyrical/features/auth/providers/auth_providers.dart';
import 'package:lyrical/features/profile/domain/profile.dart';
import 'package:lyrical/features/profile/providers/profile_providers.dart';

Profile _profile({required bool onboarded, String name = 'Serena Luna'}) {
  return Profile(
    id: 'user-1',
    anonymousName: name,
    hasCompletedOnboarding: onboarded,
  );
}

void main() {
  testWidgets('unauthenticated user sees login, not welcome', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(
            (ref) => Stream.value(AppAuthStatus.unauthenticated),
          ),
        ],
        child: const LyricalApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text(AppStrings.loginButton), findsOneWidget);
    expect(find.text(AppStrings.welcomeHeading), findsNothing);
  });

  testWidgets('authenticated incomplete onboarding goes to welcome', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(
            (ref) => Stream.value(AppAuthStatus.authenticated),
          ),
          currentProfileProvider.overrideWith(
            (ref) async => _profile(onboarded: false, name: 'Noble Roble'),
          ),
        ],
        child: const LyricalApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text(AppStrings.welcomeHeading), findsOneWidget);
    expect(find.text('Noble Roble'), findsOneWidget);
    expect(find.text(AppStrings.welcomeEnterButton), findsOneWidget);
  });

  testWidgets('authenticated completed onboarding goes to app', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(
            (ref) => Stream.value(AppAuthStatus.authenticated),
          ),
          currentProfileProvider.overrideWith(
            (ref) async => _profile(onboarded: true),
          ),
        ],
        child: const LyricalApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text(AppStrings.exploreTitle), findsWidgets);
    expect(find.text(AppStrings.welcomeHeading), findsNothing);
  });

  testWidgets('missing profile shows retry instead of crashing', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(
            (ref) => Stream.value(AppAuthStatus.authenticated),
          ),
          currentProfileProvider.overrideWith(
            (ref) async => throw const AppException(
              'No se encontró tu perfil. Cierra sesión e inténtalo de nuevo.',
            ),
          ),
        ],
        child: const LyricalApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text(AppStrings.retryButton), findsOneWidget);
    expect(find.text(AppStrings.signOutButton), findsOneWidget);
    expect(find.textContaining('No se encontró tu perfil'), findsOneWidget);
  });

  test('Profile.fromJson maps snake_case without email', () {
    final profile = Profile.fromJson({
      'id': 'abc',
      'anonymous_name': 'Clara Aurora',
      'gender': 'female',
      'bio': null,
      'avatar_url': null,
      'has_completed_onboarding': false,
      'email': 'should-be-ignored@example.com',
    });

    expect(profile.id, 'abc');
    expect(profile.anonymousName, 'Clara Aurora');
    expect(profile.hasCompletedOnboarding, isFalse);
  });
}
