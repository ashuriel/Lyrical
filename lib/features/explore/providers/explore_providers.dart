import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lyrical/features/auth/providers/auth_providers.dart';
import 'package:lyrical/features/explore/data/public_poem_repository.dart';
import 'package:lyrical/features/explore/domain/public_poem.dart';
import 'package:lyrical/features/poems/domain/poem.dart';
import 'package:lyrical/features/poems/domain/poem_status.dart';
import 'package:lyrical/features/poems/providers/poem_providers.dart';
import 'package:lyrical/features/profile/providers/profile_providers.dart';

final publicPoemRepositoryProvider = Provider<PublicPoemRepository>((ref) {
  return PublicPoemRepository(ref.watch(supabaseClientProvider));
});

final poemOfTheDayProvider = FutureProvider.autoDispose<PublicPoem?>((
  ref,
) async {
  return ref.watch(publicPoemRepositoryProvider).fetchPoemOfTheDay();
});

final discoveryPoemsProvider = FutureProvider.autoDispose<List<PublicPoem>>((
  ref,
) async {
  return ref.watch(publicPoemRepositoryProvider).fetchDiscoveryPoems();
});

final monthlySelectionProvider = FutureProvider.autoDispose<PublicPoem?>((
  ref,
) async {
  return ref.watch(publicPoemRepositoryProvider).fetchMonthlySelection();
});

@immutable
class RecentPoemsState {
  const RecentPoemsState({
    required this.items,
    required this.hasMore,
    this.isLoadingMore = false,
  });

  final List<PublicPoem> items;
  final bool hasMore;
  final bool isLoadingMore;

  RecentPoemsState copyWith({
    List<PublicPoem>? items,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return RecentPoemsState(
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

class RecentPoemsNotifier extends AutoDisposeAsyncNotifier<RecentPoemsState> {
  static const int pageSize = PublicPoemRepository.defaultRecentPageSize;

  @override
  Future<RecentPoemsState> build() async {
    final items = await ref
        .read(publicPoemRepositoryProvider)
        .fetchRecentPoems(limit: pageSize, offset: 0);
    return RecentPoemsState(items: items, hasMore: items.length >= pageSize);
  }

  Future<void> loadMore() async {
    final current = state.asData?.value;
    if (current == null || current.isLoadingMore || !current.hasMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));

    try {
      final next = await ref
          .read(publicPoemRepositoryProvider)
          .fetchRecentPoems(limit: pageSize, offset: current.items.length);

      final seen = current.items.map((p) => p.id).toSet();
      final merged = [...current.items, ...next.where((p) => seen.add(p.id))];

      state = AsyncData(
        RecentPoemsState(
          items: merged,
          hasMore: next.length >= pageSize,
          isLoadingMore: false,
        ),
      );
    } catch (_) {
      state = AsyncData(current.copyWith(isLoadingMore: false));
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final items = await ref
          .read(publicPoemRepositoryProvider)
          .fetchRecentPoems(limit: pageSize, offset: 0);
      return RecentPoemsState(items: items, hasMore: items.length >= pageSize);
    });
  }
}

final recentPoemsProvider =
    AutoDisposeAsyncNotifierProvider<RecentPoemsNotifier, RecentPoemsState>(
      RecentPoemsNotifier.new,
    );

/// Combined detail model for public viewers and poem authors.
@immutable
class PoemDetailView {
  const PoemDetailView({
    required this.id,
    required this.title,
    required this.content,
    required this.authorId,
    required this.authorAnonymousName,
    required this.poetryTypeName,
    required this.isOwner,
    required this.status,
    required this.isHidden,
    required this.createdAt,
    this.authorAvatarUrl,
    this.publishedAt,
  });

  final String id;
  final String title;
  final String content;
  final String authorId;
  final String authorAnonymousName;
  final String? authorAvatarUrl;
  final String poetryTypeName;
  final bool isOwner;
  final PoemStatus status;
  final bool isHidden;
  final DateTime createdAt;
  final DateTime? publishedAt;

  factory PoemDetailView.fromPublic(PublicPoem poem, {required bool isOwner}) {
    return PoemDetailView(
      id: poem.id,
      title: poem.title,
      content: poem.content,
      authorId: poem.authorId,
      authorAnonymousName: poem.authorAnonymousName,
      authorAvatarUrl: poem.authorAvatarUrl,
      poetryTypeName: poem.poetryTypeName,
      isOwner: isOwner,
      status: PoemStatus.approved,
      isHidden: false,
      createdAt: poem.createdAt,
      publishedAt: poem.publishedAt,
    );
  }

  factory PoemDetailView.fromOwned({
    required Poem poem,
    required String authorAnonymousName,
    String? authorAvatarUrl,
  }) {
    return PoemDetailView(
      id: poem.id,
      title: poem.title,
      content: poem.content,
      authorId: poem.authorId,
      authorAnonymousName: authorAnonymousName,
      authorAvatarUrl: authorAvatarUrl,
      poetryTypeName: poem.poetryTypeName,
      isOwner: true,
      status: poem.status,
      isHidden: poem.isHidden,
      createdAt: poem.createdAt,
      publishedAt: poem.publishedAt,
    );
  }
}

/// Loads poem detail: prefer owned row when the viewer is the author, else public.
final poemDetailProvider = FutureProvider.autoDispose
    .family<PoemDetailView, String>((ref, poemId) async {
      final userId = ref.watch(supabaseClientProvider).auth.currentUser?.id;
      final poemRepo = ref.watch(poemRepositoryProvider);
      final publicRepo = ref.watch(publicPoemRepositoryProvider);

      if (userId != null) {
        try {
          final owned = await poemRepo.fetchCurrentUserPoemById(poemId);
          final profile = await ref.watch(currentProfileProvider.future);
          return PoemDetailView.fromOwned(
            poem: owned,
            authorAnonymousName: profile.anonymousName,
            authorAvatarUrl: profile.avatarUrl,
          );
        } catch (_) {
          // Fall through to public visibility.
        }
      }

      final publicPoem = await publicRepo.fetchPublicPoemById(poemId);
      return PoemDetailView.fromPublic(
        publicPoem,
        isOwner: userId != null && publicPoem.authorId == userId,
      );
    });

Future<void> refreshExplorerProviders(WidgetRef ref) async {
  ref.invalidate(poemOfTheDayProvider);
  ref.invalidate(discoveryPoemsProvider);
  ref.invalidate(monthlySelectionProvider);
  await ref.read(recentPoemsProvider.notifier).refresh();
  await Future.wait([
    ref.read(poemOfTheDayProvider.future),
    ref.read(discoveryPoemsProvider.future),
    ref.read(monthlySelectionProvider.future),
  ]);
}

/// Same Explorer invalidation for Riverpod [Ref] (e.g. after moderation).
Future<void> invalidateExplorerAfterPublication(Ref ref) async {
  ref.invalidate(poemOfTheDayProvider);
  ref.invalidate(discoveryPoemsProvider);
  ref.invalidate(monthlySelectionProvider);
  try {
    await ref.read(recentPoemsProvider.notifier).refresh();
  } catch (_) {
    // Best-effort.
  }
}
