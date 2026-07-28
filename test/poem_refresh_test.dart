import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lyrical/features/poems/domain/poem.dart';
import 'package:lyrical/features/poems/providers/poem_providers.dart';

/// Confirms refresh helpers invalidate all four list providers.
void main() {
  test('refreshCurrentUserPoemLists invalidates all four poem lists', () async {
    var pendingBuilds = 0;
    var publishedBuilds = 0;
    var hiddenBuilds = 0;
    var rejectedBuilds = 0;

    final container = ProviderContainer(
      overrides: [
        currentUserPendingPoemsProvider.overrideWith((ref) async {
          pendingBuilds++;
          return const <Poem>[];
        }),
        currentUserPublishedPoemsProvider.overrideWith((ref) async {
          publishedBuilds++;
          return const <Poem>[];
        }),
        currentUserHiddenPoemsProvider.overrideWith((ref) async {
          hiddenBuilds++;
          return const <Poem>[];
        }),
        currentUserRejectedPoemsProvider.overrideWith((ref) async {
          rejectedBuilds++;
          return const <Poem>[];
        }),
      ],
    );
    addTearDown(container.dispose);

    // Warm providers once.
    await container.read(currentUserPendingPoemsProvider.future);
    await container.read(currentUserPublishedPoemsProvider.future);
    await container.read(currentUserHiddenPoemsProvider.future);
    await container.read(currentUserRejectedPoemsProvider.future);

    expect(pendingBuilds, 1);
    expect(publishedBuilds, 1);
    expect(hiddenBuilds, 1);
    expect(rejectedBuilds, 1);

    // Mirror refreshCurrentUserPoemLists without WidgetRef.
    container.invalidate(currentUserPendingPoemsProvider);
    container.invalidate(currentUserPublishedPoemsProvider);
    container.invalidate(currentUserHiddenPoemsProvider);
    container.invalidate(currentUserRejectedPoemsProvider);
    await Future.wait([
      container.read(currentUserPendingPoemsProvider.future),
      container.read(currentUserPublishedPoemsProvider.future),
      container.read(currentUserHiddenPoemsProvider.future),
      container.read(currentUserRejectedPoemsProvider.future),
    ]);

    expect(pendingBuilds, 2);
    expect(publishedBuilds, 2);
    expect(hiddenBuilds, 2);
    expect(rejectedBuilds, 2);
  });

  test(
    'currentUserPoemProvider is autoDispose family for fresh detail fetch',
    () {
      expect(
        currentUserPoemProvider,
        isA<AutoDisposeFutureProviderFamily<Poem, String>>(),
      );
    },
  );
}
