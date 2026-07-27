import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lyrical/app/app.dart';
import 'package:lyrical/core/constants/app_strings.dart';

void main() {
  testWidgets('shows splash with Spanish app title', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: LyricalApp()));

    expect(find.text(AppStrings.appTitle), findsOneWidget);
    expect(find.text(AppStrings.splashTagline), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.exploreTitle), findsWidgets);
  });
}
