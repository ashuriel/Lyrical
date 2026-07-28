import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lyrical/app/app.dart';
import 'package:lyrical/core/constants/app_strings.dart';
import 'package:lyrical/features/auth/providers/auth_providers.dart';

void main() {
  testWidgets('unauthenticated flow shows splash then login', (tester) async {
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

    // First frame may still be splash while router settles.
    expect(find.text(AppStrings.appTitle), findsWidgets);

    await tester.pumpAndSettle();

    expect(find.text(AppStrings.loginButton), findsOneWidget);
    expect(find.text(AppStrings.goToRegister), findsOneWidget);
  });
}
